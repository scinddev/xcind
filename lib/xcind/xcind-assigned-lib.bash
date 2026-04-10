#!/usr/bin/env bash
# xcind-assigned-lib.bash — Assigned-port hook and lifecycle helpers
#
# Provides xcind-assigned-hook (GENERATE), which reserves stable host port
# bindings for services declared in XCIND_ASSIGNED_EXPORTS and emits
# compose.assigned.yaml with matching "ports:" entries.
#
# Assignments are persisted in a flat TSV state file under the XDG config
# directory. Concurrent access is serialized with flock(1) when available.
# Port availability is checked via ss(8) (preferred), netstat(8), or a
# bash /dev/tcp probe as a last-resort fallback.
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default; apps only need to declare XCIND_ASSIGNED_EXPORTS to use it.

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

XCIND_ASSIGNED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xcind"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

# Maximum number of contiguous ports probed when allocating a new host port.
XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS=100

# TSV header written to new state files for human readability.
XCIND_ASSIGNED_PORTS_HEADER=$'# port\tapp\texport\tcontainer_port\tapp_path\tassigned_at'

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

# Return 0 if the TCP port is free on 127.0.0.1, 1 if something is listening.
# Prefers ss(8), then netstat(8), then a bash /dev/tcp connect probe.
__xcind-assigned-port-available() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    if ss -H -tln 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
      return 1
    fi
    return 0
  fi

  if command -v netstat >/dev/null 2>&1; then
    if netstat -lnt 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${port}\$"; then
      return 1
    fi
    return 0
  fi

  # /dev/tcp fallback — a successful connect means something is listening.
  if (exec 3<>/dev/tcp/127.0.0.1/"$port") 2>/dev/null; then
    exec 3<&- 3>&- 2>/dev/null || true
    return 1
  fi
  return 0
}

# --------------------------------------------------------------------------
# State file I/O (callers must hold the assigned-ports lock)
# --------------------------------------------------------------------------

# Look up the host port assigned to (app_path, export). Prints the port and
# returns 0 on hit; returns 1 (no output) otherwise.
__xcind-assigned-lookup() {
  local app_path="$1" xport="$2"
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 1
  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if [[ $L_path == "$app_path" && $L_xport == "$xport" ]]; then
      printf '%s\n' "$L_port"
      return 0
    fi
  done <"$XCIND_ASSIGNED_PORTS_FILE"
  return 1
}

# Insert-or-update a single assignment. Any pre-existing row with the same
# (app_path, export) identity OR the same host port is removed first.
__xcind-assigned-upsert() {
  local port="$1" app="$2" xport="$3" cport="$4" app_path="$5"
  __xcind-assigned-ensure-state-file

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if [[ $L_path == "$app_path" && $L_xport == "$xport" ]]; then
      continue
    fi
    if [[ $L_port == "$port" ]]; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$port" "$app" "$xport" "$cport" "$app_path" "$ts" >>"$tmp"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
}

# Remove any entry matching (app_path, export). No-op if not found.
__xcind-assigned-remove-entry() {
  local app_path="$1" xport="$2"
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 0

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if [[ $L_path == "$app_path" && $L_xport == "$xport" ]]; then
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
}

# Remove a single entry by host port. Returns 0 if an entry was removed,
# 1 if the port was not found in the state file.
__xcind-assigned-remove-port() {
  local port="$1"
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 1

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local found=1
  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if [[ $L_port == "$port" ]]; then
      found=0
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
  return "$found"
}

# Remove all entries whose app_path no longer exists on disk. Prints the
# number of entries pruned to stdout.
__xcind-assigned-prune() {
  __xcind-assigned-ensure-state-file

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local pruned=0
  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if [[ ! -d $L_path ]]; then
      pruned=$((pruned + 1))
      continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
  printf '%s\n' "$pruned"
}

# --------------------------------------------------------------------------
# Allocation
# --------------------------------------------------------------------------

# Scan upward from the declared port for an available host port.
# Prints the first free port; errors after XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS.
__xcind-assigned-allocate-new() {
  local declared="$1"
  local port="$declared"
  local attempts=0
  while [[ $attempts -lt $XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS ]]; do
    if __xcind-assigned-port-available "$port"; then
      printf '%s\n' "$port"
      return 0
    fi
    port=$((port + 1))
    attempts=$((attempts + 1))
  done
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
        echo "xcind: Xcind assigned host port $host_port for export '$xport'" >&2
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
# inside the assigned-ports lock. No-op when XCIND_ASSIGNED_EXPORTS is unset
# or empty.
xcind-assigned-hook() {
  local app_root="$1"

  if [[ -z ${XCIND_ASSIGNED_EXPORTS+set} || ${#XCIND_ASSIGNED_EXPORTS[@]} -eq 0 ]]; then
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

  # Pass 1: parse entries, validate services, resolve container ports.
  local -a exp_names=() exp_services=() exp_cports=()

  local entry
  for entry in "${XCIND_ASSIGNED_EXPORTS[@]}"; do
    local _export_name _compose_service _port
    __xcind-proxy-parse-entry "$entry"

    __xcind-proxy-validate-service "$_compose_service" "$resolved_config" || return 1

    if [[ -z $_port ]]; then
      _port=$(__xcind-proxy-infer-port "$_compose_service" "$resolved_config") || return 1
    fi

    if [[ -z $_port || $_port == "0" ]]; then
      echo "Error: assigned export '$_export_name' has invalid container port '$_port'" >&2
      return 1
    fi

    exp_names+=("$_export_name")
    exp_services+=("$_compose_service")
    exp_cports+=("$_port")
  done

  # Pass 2: allocate host ports (sticky when still available, fresh otherwise).
  __xcind-assigned-ensure-state-file

  local -a exp_host_ports=()
  local i=0
  while [[ $i -lt ${#exp_names[@]} ]]; do
    local xport="${exp_names[$i]}"
    local cport="${exp_cports[$i]}"
    local host_port=""

    local sticky
    if sticky=$(__xcind-assigned-lookup "$app_root" "$xport"); then
      if __xcind-assigned-port-available "$sticky"; then
        host_port="$sticky"
      else
        __xcind-assigned-remove-entry "$app_root" "$xport"
      fi
    fi

    if [[ -z $host_port ]]; then
      host_port=$(__xcind-assigned-allocate-new "$cport") || return 1
    fi

    __xcind-assigned-upsert "$host_port" "$app" "$xport" "$cport" "$app_root"
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
  printf -- '-f %s\n' "$XCIND_GENERATED_DIR/compose.assigned.yaml"
}

# --------------------------------------------------------------------------
# JSON contract helper
# --------------------------------------------------------------------------

# Print a JSON object describing assigned exports for the given app path.
# Inner fields: compose_service, container_port, host_port, declared_port.
# Requires jq. Returns "{}" when no assignments exist or jq is unavailable.
#
# compose_service is resolved from the current XCIND_ASSIGNED_EXPORTS array
# when available (the state file does not store it).
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

  # Map export_name → compose_service from the current declaration, if any.
  local -a xps=() svcs=()
  if [[ -n ${XCIND_ASSIGNED_EXPORTS+set} ]] && [[ ${#XCIND_ASSIGNED_EXPORTS[@]} -gt 0 ]]; then
    local entry
    for entry in "${XCIND_ASSIGNED_EXPORTS[@]}"; do
      local _export_name _compose_service _port
      __xcind-proxy-parse-entry "$entry"
      xps+=("$_export_name")
      svcs+=("$_compose_service")
    done
  fi

  local json="{}"
  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    [[ $L_path != "$app_path" ]] && continue

    local svc=""
    local j=0
    while [[ $j -lt ${#xps[@]} ]]; do
      if [[ ${xps[$j]} == "$L_xport" ]]; then
        svc="${svcs[$j]}"
        break
      fi
      j=$((j + 1))
    done

    json=$(printf '%s' "$json" | jq \
      --arg name "$L_xport" \
      --arg svc "$svc" \
      --argjson cport "$L_cport" \
      --argjson hport "$L_port" \
      --argjson declared "$L_cport" \
      '. + {($name): {compose_service: $svc, container_port: $cport, host_port: $hport, declared_port: $declared}}')
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  printf '%s' "$json"
}
