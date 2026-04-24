#!/usr/bin/env bash
# xcind-assigned-lib.bash — Assigned-port hook and lifecycle helpers
#
# Provides xcind-assigned-hook (GENERATE), which reserves stable host port
# bindings for entries of XCIND_PROXY_EXPORTS whose metadata declares
# `type=assigned`, and emits compose.assigned.yaml with matching "ports:"
# entries. Proxied entries are handled by xcind-proxy-hook.
#
# Assignments are persisted in a flat TSV state file under the XDG state
# directory, nested under proxy/ since the proxy component owns the
# infrastructure. Concurrent access is serialized with flock(1) when
# available. Port availability is checked via ss(8) (preferred),
# netstat(8), or a bash /dev/tcp probe as a last-resort fallback.
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default; apps only need to add `;type=assigned` metadata to entries in
# XCIND_PROXY_EXPORTS to use it.

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

# Maximum number of contiguous ports probed when allocating a new host port.
XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS=100

# TSV header written to new state files for human readability. Column names
# follow the Scind vocabulary: workspace, application, service (the exported
# service name, which doubles as the compose service unless the entry uses
# `name=compose_service` syntax).
XCIND_ASSIGNED_PORTS_HEADER=$'# port\tworkspace\tapplication\tservice\tcontainer_port\tapp_path\tassigned_at'

# --------------------------------------------------------------------------
# State file initialization
# --------------------------------------------------------------------------

# Ensure the state directory and file exist. Writes the TSV header to a
# newly created file. Safe to call unlocked — only creates missing files.
__xcind-assigned-ensure-state-file() {
  mkdir -p "$XCIND_ASSIGNED_DIR"
  if [[ ! -f $XCIND_ASSIGNED_PORTS_FILE ]]; then
    printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
  fi
}

# --------------------------------------------------------------------------
# Shared TSV read/rewrite helpers
# --------------------------------------------------------------------------
#
# These two helpers factor out the shared read-loop boilerplate used by every
# function that touches the assigned-ports state file. They exist so that
# future schema changes touch the header constant, one `read -r` call, and
# one `printf` format string — not 5–7 copies of the same loop.
#
# Both helpers:
#   - silently do nothing when the state file does not exist
#   - skip blank lines and comment (#…) lines
#   - bind six positional fields (L_port L_app L_xport L_cport L_path L_ts)
#     before invoking the caller-supplied predicate/callback
#   - pass any trailing arguments through to the callback after those fields
#
# __xcind-assigned-iter is read-only. __xcind-assigned-rewrite rewrites the
# file via a temp file + mv; callers must hold the assigned-ports lock.

# Split a tab-separated line into seven named fields, preserving empty
# fields. Bash's `read -r` with `IFS=$'\t'` collapses runs of consecutive
# tabs because tab is an IFS-whitespace character, which would silently
# drop the `workspace` column whenever it is empty. Manual prefix-strip
# splitting sidesteps that and keeps empties intact.
#
# Consumes one line argument; sets the seven L_* variables in the caller's
# scope. The caller must declare them `local` so they don't leak.
__xcind-assigned-split-row() {
  local line="$1"
  L_port="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_workspace="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_application="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_service="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_cport="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_path="${line%%$'\t'*}"
  line="${line#*$'\t'}"
  L_ts="$line"
}

# Iterate data rows of the assigned-ports state file, invoking $callback
# with the seven TSV fields followed by any extra arguments passed to iter.
#
# Callback signature:
#   L_port L_workspace L_application L_service L_cport L_path L_ts "$@"
#
# Iteration stops as soon as the callback returns a non-zero status, and
# that status is propagated back to the caller. Callers that want "found"
# semantics can exploit this: make the callback set a module-level variable
# and `return 1` on a hit — iter will return 1 and the caller knows it
# short-circuited. Normal completion (no hit) returns 0.
#
# The state file not existing is treated as "empty": iter returns 0 and
# the callback is never invoked.
__xcind-assigned-iter() {
  local callback="$1"
  shift
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 0
  local L_port L_workspace L_application L_service L_cport L_path L_ts
  local __row
  while IFS= read -r __row; do
    [[ -z $__row ]] && continue
    [[ ${__row:0:1} == "#" ]] && continue
    __xcind-assigned-split-row "$__row"
    "$callback" "$L_port" "$L_workspace" "$L_application" "$L_service" \
      "$L_cport" "$L_path" "$L_ts" "$@" || return $?
  done <"$XCIND_ASSIGNED_PORTS_FILE"
  return 0
}

# Rewrite the assigned-ports state file in place, keeping only rows for
# which $predicate returns 0. The predicate receives the seven TSV fields
# followed by any extra arguments passed to rewrite.
#
# Callers MUST already hold the assigned-ports lock
# (__xcind-with-assigned-lock). The helper ensures the state file exists,
# writes a fresh header + surviving rows into a sibling .tmp file, then
# atomically mv(1)s it over the original.
__xcind-assigned-rewrite() {
  local predicate="$1"
  shift
  __xcind-assigned-ensure-state-file

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local L_port L_workspace L_application L_service L_cport L_path L_ts
  local __row
  while IFS= read -r __row; do
    [[ -z $__row ]] && continue
    [[ ${__row:0:1} == "#" ]] && continue
    __xcind-assigned-split-row "$__row"
    if "$predicate" "$L_port" "$L_workspace" "$L_application" "$L_service" \
      "$L_cport" "$L_path" "$L_ts" "$@"; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$L_port" "$L_workspace" "$L_application" "$L_service" \
        "$L_cport" "$L_path" "$L_ts" >>"$tmp"
    fi
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
}

# --------------------------------------------------------------------------
# Critical section helper
# --------------------------------------------------------------------------

# Run the given command holding an exclusive lock on the ports lock file.
# When flock(1) is unavailable (e.g., stock macOS) the command still runs,
# unlocked — single-writer workflows continue to function but concurrent
# writers may race.
__xcind-with-assigned-lock() {
  __xcind-assigned-ensure-state-file
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      "$@"
    ) 200>"$XCIND_ASSIGNED_PORTS_LOCK"
  else
    "$@"
  fi
}

# --------------------------------------------------------------------------
# Port availability probe
# --------------------------------------------------------------------------
#
# Two-layer design:
#
#   1. A batch "listener snapshot" cache populated via a single ss(8) or
#      netstat(8) invocation. While the cache is primed, single-port queries
#      are resolved with a pure-bash substring check — no per-port subshell,
#      no per-port pipeline. Intended for callers that probe many ports
#      back-to-back (e.g. __xcind-assigned-allocate-new), where the N×3
#      subprocess fanout dominated wall time on slow environments
#      (WSL2 + Docker Desktop can spend ~100–500 ms per ss call).
#
#   2. When the cache is not primed — or when neither ss nor netstat is
#      available — __xcind-assigned-port-available falls back to the
#      original per-port ss/netstat/dev-tcp cascade. This keeps the
#      function's single-port contract (used by tests and external callers)
#      unchanged.
#
# The cache is module-scope bash state, not a file — priming it does not
# persist across processes. Callers should prime, probe, and clear within a
# single hook invocation; see __xcind-assigned-allocate-new.

# Space-wrapped set of listening TCP ports ("" when unprimed, " PORT PORT "
# when primed). Wrapping with leading/trailing spaces lets us test membership
# with `[[ $cache == *" $port "* ]]` without worrying about substring matches
# (e.g. "3306" matching "13306").
__xcind_assigned_listener_cache=""
# Source string used to populate the cache: "ss", "netstat", "none" (neither
# available), or "" (unprimed). The empty-vs-"none" distinction matters:
# "none" means we tried and can't build a snapshot, so per-port
# __xcind-assigned-port-available should do its own fallback without
# consulting the empty cache.
__xcind_assigned_listener_cache_source=""

# Populate the module-level listener cache in a single shot. Idempotent —
# calling it again overwrites whatever was there. Never fails: if neither
# ss nor netstat can be used, the source is set to "none" and callers will
# fall back to per-port probing.
#
# Emits a breadcrumb on every branch outcome so XCIND_DEBUG=1 traces
# surface exactly which tool was tried and why it didn't stick. Critical
# for diagnosing WSL2 reports where `ss` and `netstat` are both absent
# and the hook silently falls back to (slow) /dev/tcp probes.
__xcind-assigned-prime-listener-cache() {
  __xcind_assigned_listener_cache=""
  __xcind_assigned_listener_cache_source=""

  local out
  if command -v ss >/dev/null 2>&1; then
    if out=$(ss -H -tln 2>/dev/null); then
      __xcind_assigned_listener_cache=" $(printf '%s\n' "$out" | awk '
        {
          # Local-address column (ss -H omits the header). Split on `:` or
          # `.` so both IPv4 `0.0.0.0:PORT` and IPv6 `[::]:PORT` surface the
          # trailing port field. Guard the result with a numeric regex so
          # malformed lines (or a blank output) dont contribute junk.
          n = split($4, a, /[:.]/); p = a[n];
          if (p ~ /^[0-9]+$/) print p
        }
      ' | tr "\n" " ")"
      __xcind_assigned_listener_cache_source="ss"
      __xcind-debug "prime-listener-cache: source=ss"
      return 0
    fi
    __xcind-debug "prime-listener-cache: ss present but invocation failed — trying netstat"
  else
    __xcind-debug "prime-listener-cache: ss not found on PATH — trying netstat"
  fi

  if command -v netstat >/dev/null 2>&1; then
    if out=$(netstat -lnt 2>/dev/null); then
      __xcind_assigned_listener_cache=" $(printf '%s\n' "$out" | awk '
        # Skip the two header lines that Linux net-tools emits. BSD/macOS
        # netstat does not take `-lnt` and exits non-zero above, so this
        # branch only ever sees net-tools output.
        NR > 2 {
          n = split($4, a, /[:.]/); p = a[n];
          if (p ~ /^[0-9]+$/) print p
        }
      ' | tr "\n" " ")"
      __xcind_assigned_listener_cache_source="netstat"
      __xcind-debug "prime-listener-cache: source=netstat"
      return 0
    fi
    __xcind-debug "prime-listener-cache: netstat present but invocation failed (likely BSD-style, '-lnt' unsupported)"
  else
    __xcind-debug "prime-listener-cache: netstat not found on PATH"
  fi

  # Both unavailable — callers will probe /dev/tcp per port. Note this for
  # the operator; on WSL2 + Docker Desktop, per-port loopback connects can
  # stall for seconds each, which is exactly the slowdown this breadcrumb
  # helps diagnose.
  local has_timeout=yes
  command -v timeout >/dev/null 2>&1 || has_timeout=no
  __xcind-debug "prime-listener-cache: source=none (no ss/netstat) — port-available will use /dev/tcp per port, timeout_wrap=$has_timeout"
  __xcind_assigned_listener_cache_source="none"
  return 0
}

# Reset the listener cache. Callers should invoke this after finishing a
# batch of probes so later unrelated lookups (e.g. a direct single-port
# caller) re-probe the live kernel state.
__xcind-assigned-clear-listener-cache() {
  __xcind_assigned_listener_cache=""
  __xcind_assigned_listener_cache_source=""
}

# Return 0 if the TCP port is free on 127.0.0.1, 1 if something is listening.
#
# When the batch listener cache has been primed (ss or netstat source), the
# answer comes from a substring test — no subprocess. Otherwise falls back
# to the original per-port cascade: ss(8), then netstat(8), then a bash
# /dev/tcp connect probe. The /dev/tcp probe is wrapped with timeout(1) when
# available, because loopback connects through the WSL2 + Docker Desktop
# network stack can otherwise stall for several seconds apiece.
__xcind-assigned-port-available() {
  local port="$1"

  # Batch fast path. Only trusted when the cache was built from a real
  # listener list — "none" means priming failed and the cache is empty,
  # which would otherwise falsely report every port as free.
  if [[ $__xcind_assigned_listener_cache_source == "ss" ||
    $__xcind_assigned_listener_cache_source == "netstat" ]]; then
    if [[ $__xcind_assigned_listener_cache == *" $port "* ]]; then
      return 1
    fi
    return 0
  fi

  if command -v ss >/dev/null 2>&1; then
    if ss -H -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
      return 1
    fi
    return 0
  fi

  # netstat fallback: only trusted when the invocation actually succeeds.
  # Linux net-tools supports `-lnt`; BSD/macOS netstat rejects those flags
  # and would otherwise produce empty output that looks like "port free".
  # When netstat errors, fall through to the /dev/tcp probe below.
  if command -v netstat >/dev/null 2>&1; then
    local ns_out
    if ns_out=$(netstat -lnt 2>/dev/null); then
      if printf '%s\n' "$ns_out" | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
        return 1
      fi
      return 0
    fi
  fi

  # /dev/tcp fallback — a successful connect means something is listening.
  # Cap with timeout(1) when available so a stalled loopback handshake on
  # a loaded WSL2/Docker Desktop host cant wedge the allocation loop.
  if command -v timeout >/dev/null 2>&1; then
    if timeout 1 bash -c "exec 3<>/dev/tcp/127.0.0.1/$port" 2>/dev/null; then
      return 1
    fi
    return 0
  fi

  if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
    exec 3<&- 3>&- 2>/dev/null || true
    return 1
  fi
  return 0
}

# --------------------------------------------------------------------------
# State file I/O (callers must hold the assigned-ports lock)
# --------------------------------------------------------------------------

# Look up the host port assigned to (app_path, service). Prints the port and
# returns 0 on hit; returns 1 (no output) otherwise.
#
# Uses the iterator helper: the match callback sets a module-level result
# variable and returns 1 to short-circuit iteration. If iter returns 0 the
# whole file was scanned without a hit, so we return 1 (not found).
__xcind-assigned-lookup() {
  local app_path="$1" service="$2"
  __xcind_assigned_lookup_result=""
  if __xcind-assigned-iter __xcind-assigned-lookup-match \
    "$app_path" "$service"; then
    return 1
  fi
  printf '%s\n' "$__xcind_assigned_lookup_result"
  return 0
}

__xcind-assigned-lookup-match() {
  local L_port="$1" L_service="$4" L_path="$6"
  local target_path="$8" target_service="$9"
  if [[ $L_path == "$target_path" && $L_service == "$target_service" ]]; then
    __xcind_assigned_lookup_result="$L_port"
    return 1
  fi
  return 0
}

# Insert-or-update a single assignment. Any pre-existing row with the same
# (app_path, service) identity OR the same host port is removed first, then
# the new row is appended.
__xcind-assigned-upsert() {
  local port="$1" workspace="$2" application="$3" service="$4" \
    cport="$5" app_path="$6"
  __xcind-assigned-ensure-state-file

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  # Step 1: rewrite the state file, dropping any row that collides with the
  # incoming assignment on (app_path, service) identity or on host port.
  __xcind_assigned_upsert_path="$app_path"
  __xcind_assigned_upsert_service="$service"
  __xcind_assigned_upsert_port="$port"
  __xcind-assigned-rewrite __xcind-assigned-upsert-keep
  local rewrite_status=$?
  unset __xcind_assigned_upsert_path __xcind_assigned_upsert_service \
    __xcind_assigned_upsert_port
  # If the rewrite failed (e.g. mv couldn't replace the state file), bail
  # out before appending — otherwise we'd emit a new row on top of the
  # unmodified file and silently leave behind the identity/port collision
  # the rewrite was meant to drop.
  [[ $rewrite_status -eq 0 ]] || return "$rewrite_status"

  # Step 2: append the new row.
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$port" "$workspace" "$application" "$service" "$cport" "$app_path" "$ts" \
    >>"$XCIND_ASSIGNED_PORTS_FILE"
}

__xcind-assigned-upsert-keep() {
  local L_port="$1" L_service="$4" L_path="$6"
  [[ $L_path == "$__xcind_assigned_upsert_path" &&
    $L_service == "$__xcind_assigned_upsert_service" ]] && return 1
  [[ $L_port == "$__xcind_assigned_upsert_port" ]] && return 1
  return 0
}

# Remove any entry matching (app_path, service). No-op if not found.
__xcind-assigned-remove-entry() {
  local app_path="$1" service="$2"
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 0
  __xcind-assigned-rewrite __xcind-assigned-keep-not-entry \
    "$app_path" "$service"
}

__xcind-assigned-keep-not-entry() {
  local L_service="$4" L_path="$6"
  local target_path="$8" target_service="$9"
  [[ $L_path == "$target_path" && $L_service == "$target_service" ]] && return 1
  return 0
}

# Remove a single entry by host port. Returns 0 if an entry was removed,
# 1 if the port was not found in the state file.
__xcind-assigned-remove-port() {
  local port="$1"
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 1
  __xcind_assigned_remove_port_found=1
  __xcind-assigned-rewrite __xcind-assigned-keep-not-port "$port"
  return "$__xcind_assigned_remove_port_found"
}

__xcind-assigned-keep-not-port() {
  local L_port="$1"
  local target_port="$8"
  if [[ $L_port == "$target_port" ]]; then
    __xcind_assigned_remove_port_found=0
    return 1
  fi
  return 0
}

# Remove all entries whose app_path no longer exists on disk. Prints the
# number of entries pruned to stdout.
__xcind-assigned-prune() {
  __xcind_assigned_prune_count=0
  __xcind-assigned-rewrite __xcind-assigned-keep-existing-path
  printf '%s\n' "$__xcind_assigned_prune_count"
}

__xcind-assigned-keep-existing-path() {
  local L_path="$6"
  if [[ ! -d $L_path ]]; then
    __xcind_assigned_prune_count=$((__xcind_assigned_prune_count + 1))
    return 1
  fi
  return 0
}

# --------------------------------------------------------------------------
# Allocation
# --------------------------------------------------------------------------

# Scan upward from the declared port for an available host port.
# Prints the first free port; errors after XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS.
#
# Primes the listener cache with a single ss/netstat call so the scan loop
# answers each port via an in-bash substring check instead of spawning
# ss|awk|grep per attempt. On a loaded WSL2 + Docker Desktop host the
# per-iteration fanout was previously the dominant cost of the hook (100
# attempts × ~1 listener-snapshot each); batching drops that to one.
__xcind-assigned-allocate-new() {
  local declared="$1"

  __xcind-assigned-prime-listener-cache
  __xcind-debug "allocate-new: declared=$declared probe=$__xcind_assigned_listener_cache_source max_attempts=$XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS"

  local port="$declared"
  local attempts=0
  while [[ $attempts -lt $XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS ]]; do
    if __xcind-assigned-port-available "$port"; then
      __xcind-debug "allocate-new: chose port=$port attempts=$attempts"
      __xcind-assigned-clear-listener-cache
      printf '%s\n' "$port"
      return 0
    fi
    port=$((port + 1))
    attempts=$((attempts + 1))
  done
  __xcind-assigned-clear-listener-cache
  echo "Error: no free host port found in ${XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS} attempts from $declared" >&2
  return 1
}

# --------------------------------------------------------------------------
# Compose conflict warning
# --------------------------------------------------------------------------

# Emit a warning to stderr when a compose service already publishes the
# same container port via its own ports: entry. Requires yq.
__xcind-assigned-warn-compose-conflict() {
  local resolved_config="$1" svc="$2" cport="$3" host_port="$4" xport="$5"

  local port_count
  port_count=$(yq ".services.\"$svc\".ports | length" "$resolved_config" 2>/dev/null) || port_count=0
  [[ -z $port_count || $port_count == "null" ]] && port_count=0

  local idx=0
  while [[ $idx -lt $port_count ]]; do
    local target
    target=$(yq ".services.\"$svc\".ports[$idx].target" "$resolved_config" 2>/dev/null)
    if [[ $target == "$cport" ]]; then
      local published
      published=$(yq ".services.\"$svc\".ports[$idx].published" "$resolved_config" 2>/dev/null)
      if [[ -n $published && $published != "null" ]]; then
        echo "xcind: warning: service '$svc' already maps container port $cport to host port $published" >&2
        echo "xcind: assigned host port $host_port for export '$xport'" >&2
        echo "xcind: consider removing the host port from your compose file to avoid duplicate mappings" >&2
        return 0
      fi
    fi
    idx=$((idx + 1))
  done
}

# --------------------------------------------------------------------------
# Hook
# --------------------------------------------------------------------------

# Main hook function. Executes the full allocation + generation pipeline
# inside the assigned-ports lock. No-op when XCIND_PROXY_EXPORTS is unset
# or contains no `type=assigned` entries.
xcind-assigned-hook() {
  local app_root="$1"

  local __dbg_count=0
  [[ -n ${XCIND_PROXY_EXPORTS+set} ]] && __dbg_count=${#XCIND_PROXY_EXPORTS[@]}
  __xcind-debug "assigned-hook: entry app_root=$app_root exports_count=$__dbg_count"

  if [[ -z ${XCIND_PROXY_EXPORTS+set} || ${#XCIND_PROXY_EXPORTS[@]} -eq 0 ]]; then
    __xcind-debug "assigned-hook: skip — XCIND_PROXY_EXPORTS unset or empty"
    return 0
  fi

  # Count assigned entries without allocating anything yet. We parse
  # defensively here so a malformed entry still surfaces as an error at
  # GENERATE time, but delegate the authoritative error reporting to the
  # locked body's own parse loop.
  local entry _export_name _compose_service _port _type
  local has_assigned=0
  for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
    if __xcind-proxy-parse-entry "$entry" 2>/dev/null; then
      __xcind-debug "assigned-hook: count-pass entry='$entry' parse=ok name=$_export_name service=$_compose_service port=$_port type=$_type"
      [[ $_type == "assigned" ]] && {
        has_assigned=1
        break
      }
    else
      __xcind-debug "assigned-hook: count-pass entry='$entry' parse=fail"
    fi
  done
  if [[ $has_assigned -ne 1 ]]; then
    __xcind-debug "assigned-hook: skip — no type=assigned entries after count-pass"
    return 0
  fi

  __xcind-with-assigned-lock __xcind-assigned-hook-locked "$app_root"
}

# Locked body — must only be called via __xcind-with-assigned-lock.
__xcind-assigned-hook-locked() {
  local app_root="$1"

  if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for xcind-assigned-hook but was not found." >&2
    return 1
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"
  local app="${XCIND_APP:-$(basename "$app_root")}"
  local workspace="${XCIND_WORKSPACE:-}"

  # Pass 1: parse entries, skip proxied entries, validate services, resolve
  # container ports.
  local -a exp_names=() exp_services=() exp_cports=()

  local entry
  for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
    local _export_name _compose_service _port _type
    __xcind-proxy-parse-entry "$entry" || return 1

    if [[ $_type != "assigned" ]]; then
      __xcind-debug "assigned-hook: pass-1 entry='$entry' type=$_type skipped"
      continue
    fi

    __xcind-proxy-validate-service "$_compose_service" "$resolved_config" || return 1

    if [[ -z $_port ]]; then
      _port=$(__xcind-proxy-infer-port "$_compose_service" "$resolved_config") || return 1
    fi

    if [[ -z $_port || $_port == "0" ]]; then
      echo "Error: assigned export '$_export_name' has invalid container port '$_port'" >&2
      return 1
    fi

    __xcind-debug "assigned-hook: pass-1 entry='$entry' name=$_export_name service=$_compose_service cport=$_port — queued"
    exp_names+=("$_export_name")
    exp_services+=("$_compose_service")
    exp_cports+=("$_port")
  done

  # Nothing assigned after filtering: no compose overlay, no -f flag.
  if [[ ${#exp_names[@]} -eq 0 ]]; then
    __xcind-debug "assigned-hook: skip — exp_names empty after pass-1 filter"
    return 0
  fi

  # Pass 2: allocate host ports. A sticky TSV hit is trusted without probing;
  # only fresh allocations probe for availability.
  __xcind-assigned-ensure-state-file

  local -a exp_host_ports=()
  local i=0
  while [[ $i -lt ${#exp_names[@]} ]]; do
    local xport="${exp_names[$i]}"
    local cport="${exp_cports[$i]}"
    local host_port=""

    # Sticky hit: trust the TSV. We cannot tell "our own running container"
    # from "a foreign process" by probing the port — ss/netstat/dev-tcp all
    # just see a listener. Probing here self-evicts whenever the container
    # is up on a cache miss, causing the port to flap. If the port is truly
    # stolen, `docker compose up` will surface a clear bind error.
    local sticky
    if sticky=$(__xcind-assigned-lookup "$app_root" "$xport"); then
      host_port="$sticky"
      __xcind-debug "assigned-hook: allocate xport=$xport cport=$cport host_port=$host_port source=sticky"
    fi

    if [[ -z $host_port ]]; then
      host_port=$(__xcind-assigned-allocate-new "$cport") || return 1
      __xcind-debug "assigned-hook: allocate xport=$xport cport=$cport host_port=$host_port source=fresh"
    fi

    __xcind-assigned-upsert "$host_port" "$workspace" "$app" "$xport" "$cport" "$app_root"
    exp_host_ports+=("$host_port")

    __xcind-assigned-warn-compose-conflict \
      "$resolved_config" "${exp_services[$i]}" "$cport" "$host_port" "$xport"

    i=$((i + 1))
  done

  # Pass 3: build the compose overlay, grouped by compose service.
  local output="services:"
  local -a seen_services=()

  local s_idx=0
  while [[ $s_idx -lt ${#exp_names[@]} ]]; do
    local svc="${exp_services[$s_idx]}"

    local already_seen=false s
    for s in "${seen_services[@]+"${seen_services[@]}"}"; do
      if [[ $s == "$svc" ]]; then
        already_seen=true
        break
      fi
    done
    if [[ $already_seen == true ]]; then
      s_idx=$((s_idx + 1))
      continue
    fi
    seen_services+=("$svc")

    output+=$'\n\n  '"${svc}:"$'\n    ports:'

    local p_idx=0
    while [[ $p_idx -lt ${#exp_names[@]} ]]; do
      if [[ ${exp_services[$p_idx]} == "$svc" ]]; then
        local h="${exp_host_ports[$p_idx]}"
        local c="${exp_cports[$p_idx]}"
        output+=$'\n      - "'"${h}:${c}"'"'
      fi
      p_idx=$((p_idx + 1))
    done

    s_idx=$((s_idx + 1))
  done

  output+=$'\n'

  printf '%s' "$output" >"$XCIND_GENERATED_DIR/compose.assigned.yaml"
  __xcind-debug "assigned-hook: overlay written path=$XCIND_GENERATED_DIR/compose.assigned.yaml exports=${#exp_names[@]}"
  printf -- '-f %s\n' "$XCIND_GENERATED_DIR/compose.assigned.yaml"
}

# --------------------------------------------------------------------------
# JSON contract helper
# --------------------------------------------------------------------------

# Print a JSON object describing assigned exports for the given app path.
# Inner fields: compose_service, container_port, host_port, declared_port.
# Requires jq. Returns "{}" when no assignments exist or jq is unavailable.
#
# compose_service is resolved from the current XCIND_PROXY_EXPORTS array
# (filtered to type=assigned) when available — the state file does not
# store it.
__xcind-assigned-json-for-app() {
  local app_path="$1"
  if ! command -v jq &>/dev/null; then
    echo "{}"
    return 0
  fi
  if [[ ! -f $XCIND_ASSIGNED_PORTS_FILE ]]; then
    echo "{}"
    return 0
  fi

  # Map service → compose_service from the current declaration, if any.
  # These arrays are consumed by the iter callback below; declaring them at
  # module scope is intentional because Bash 3.2 has no declare -g and the
  # callback can't see function locals.
  __xcind_assigned_json_xps=()
  __xcind_assigned_json_svcs=()
  if [[ -n ${XCIND_PROXY_EXPORTS+set} ]] && [[ ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]]; then
    local entry
    for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
      local _export_name _compose_service _port _type
      __xcind-proxy-parse-entry "$entry" 2>/dev/null || continue
      [[ $_type == "assigned" ]] || continue
      __xcind_assigned_json_xps+=("$_export_name")
      __xcind_assigned_json_svcs+=("$_compose_service")
    done
  fi

  __xcind_assigned_json_result="{}"
  __xcind-assigned-iter __xcind-assigned-json-for-app-row "$app_path"
  printf '%s' "$__xcind_assigned_json_result"
  unset __xcind_assigned_json_xps __xcind_assigned_json_svcs \
    __xcind_assigned_json_result
}

__xcind-assigned-json-for-app-row() {
  local L_port="$1" L_service="$4" L_cport="$5" L_path="$6"
  local target_path="$8"
  [[ $L_path != "$target_path" ]] && return 0

  local svc=""
  local j=0
  while [[ $j -lt ${#__xcind_assigned_json_xps[@]} ]]; do
    if [[ ${__xcind_assigned_json_xps[$j]} == "$L_service" ]]; then
      svc="${__xcind_assigned_json_svcs[$j]}"
      break
    fi
    j=$((j + 1))
  done

  __xcind_assigned_json_result=$(printf '%s' "$__xcind_assigned_json_result" | jq \
    --arg name "$L_service" \
    --arg svc "$svc" \
    --argjson cport "$L_cport" \
    --argjson hport "$L_port" \
    --argjson declared "$L_cport" \
    '. + {($name): {compose_service: $svc, container_port: $cport, host_port: $hport, declared_port: $declared}}')
  return 0
}
