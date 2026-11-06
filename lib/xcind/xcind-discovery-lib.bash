#!/usr/bin/env bash
# xcind-discovery-lib.bash — Hook for injecting service-discovery env vars
#
# Generates a compose override that adds an `environment:` block of
# XCIND_{APP}_{EXPORT}_{SUFFIX} variables to every service of the current app,
# so applications can read their own export hostnames/ports/URLs at runtime
# without hardcoding them. Scope is own-app only (v1): a container receives the
# discovery variables for its own app's exports, not other apps' exports.
#
# Variable schema (app/export segments hyphen→underscore, uppercased). The
# container view is shown; see __xcind-discovery-build-pairs for the host view.
#   Proxied export E:
#     XCIND_{APP}_{E}_HOST    proxied hostname
#     XCIND_{APP}_{E}_PORT    proxy entrypoint port (https→443 / http→80, overridable)
#     XCIND_{APP}_{E}_SCHEME  http | https
#     XCIND_{APP}_{E}_URL     {scheme}://{hostname}
#     # plus _HTTPS_HOST/_PORT/_URL and _HTTP_HOST/_PORT/_URL when both schemes serve
#     XCIND_{APP}_{E}_INTERNAL_HOST/_INTERNAL_PORT  in-network host + container port
#     XCIND_{APP}_{E}_EXTERNAL_HOST/_EXTERNAL_PORT  proxied hostname + proxy port
#   Apex (first proxied export only, when an apex template is configured):
#     XCIND_{APP}_APEX_HOST/_PORT/_SCHEME/_URL
#   Assigned export E:
#     XCIND_{APP}_{E}_HOST       in-network host ({app}-{service} alias in a
#                                workspace, else the compose service name)
#     XCIND_{APP}_{E}_PORT       container port
#     XCIND_{APP}_{E}_HOST_PORT  allocated host-published port
#     XCIND_{APP}_{E}_INTERNAL_HOST/_INTERNAL_PORT  same as _HOST/_PORT
#     XCIND_{APP}_{E}_EXTERNAL_HOST/_EXTERNAL_PORT  host-reachable host
#                                (XCIND_HOST_ENV_ASSIGNED_HOST) + host port
#   Unpublished export E (container view only; no router, no host port):
#     XCIND_{APP}_{E}_HOST/_PORT                    in-network host + container port
#     XCIND_{APP}_{E}_INTERNAL_HOST/_INTERNAL_PORT  same as _HOST/_PORT
#   Workspace mode:
#     XCIND_WORKSPACE_NAME       the workspace name
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered in
# XCIND_HOOKS_GENERATE (last, after xcind-assigned-hook so host ports are
# already allocated) and in XCIND_HOOKS_ALWAYS, because _HOST_PORT embeds live
# assigned-port state that lives outside the cache SHA — a cached replay could
# otherwise disagree with the re-run compose.assigned.yaml.

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

# Convert a name segment to an env-var-safe token: hyphens → underscores,
# uppercased. Bash 3.2 safe (no ${var^^}); uppercasing via tr.
__xcind-discovery-envify() {
  local s="${1//-/_}"
  printf '%s' "$s" | tr '[:lower:]' '[:upper:]'
}

# Render a public URL for a proxied host. Default ports stay implicit; custom
# proxy entrypoint ports are included so *_URL is directly usable.
__xcind-discovery-url() {
  local scheme="$1" host="$2" port="$3"
  if [[ $scheme == "https" && $port == "443" ]] ||
    [[ $scheme == "http" && $port == "80" ]]; then
    printf '%s://%s' "$scheme" "$host"
  else
    printf '%s://%s:%s' "$scheme" "$host" "$port"
  fi
}

# Quote a scalar as a YAML single-quoted string. Single quotes inside the value
# are represented by two adjacent single quotes. The quote char comes from a
# variable so the replacement contains no backslashes — Bash 3.2 keeps literal
# backslashes in `${var//x/\'}` replacements, which would corrupt the output.
__xcind-discovery-yaml-quote() {
  local sq="'"
  local s="${1//$sq/$sq$sq}"
  printf "'%s'" "$s"
}

# The in-network ("internal") host for a compose service: the workspace alias
# ({app}-{service} via XCIND_WORKSPACE_SERVICE_TEMPLATE) in a workspace, where
# the alias actually exists, else the compose service name, reachable on
# Compose's default network.
__xcind-discovery-internal-host() {
  local app="$1" service="$2"
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]]; then
    __xcind-render-template "$XCIND_WORKSPACE_SERVICE_TEMPLATE" \
      workspace "${XCIND_WORKSPACE:-}" app "$app" service "$service"
  else
    printf '%s\n' "$service"
  fi
}

# The host-reachable ("external") host for an assigned export, selected by
# XCIND_HOST_ENV_ASSIGNED_HOST:
#   loopback (default) — literal 127.0.0.1 (not localhost: avoids ::1/IPv6
#                        surprises in strict clients)
#   hostname           — the export's URL-template hostname, for setups whose
#                        proxy domain resolves to the Docker host (wildcard DNS)
# The caller validates the mode (see __xcind-discovery-build-pairs).
__xcind-discovery-external-assigned-host() {
  local export_name="$1" app="$2"
  if [[ ${XCIND_HOST_ENV_ASSIGNED_HOST:-loopback} == "hostname" ]]; then
    __xcind-proxy-export-hostname "$export_name" "$app" "$XCIND_PROXY_DOMAIN"
  else
    printf '127.0.0.1\n'
  fi
}

# Resolve an export's container port: the explicit port when given, else the
# single port mapping inferred from resolved-config.yaml (needs yq). Prints the
# normalized port; errors are export-named and return 1.
__xcind-discovery-container-port() {
  local export_name="$1" service="$2" port="$3"
  if [[ -z $port ]]; then
    local resolved_config="${XCIND_CACHE_DIR:-}/resolved-config.yaml"
    if ! command -v yq &>/dev/null || [[ ! -f $resolved_config ]]; then
      echo "Error: cannot infer the container port for XCIND_PROXY_EXPORTS entry '$export_name'. Specify the port explicitly." >&2
      return 1
    fi
    port=$(__xcind-proxy-infer-port "$service" "$resolved_config") || return 1
  fi
  __xcind-proxy-normalize-port "$export_name" "$port"
}

# Fail when two different XCIND_PROXY_EXPORTS declarations produce the same
# discovery prefix XCIND_{APP}_{EXPORT} (e.g. `mailpit` declared both proxied
# and unpublished, or `a-b` and `a_b`), or when an export's prefix collides
# with the apex variables. Byte-identical repeats (the same entry appended by
# two config files) are allowed. Two ports on one service need two export names.
__xcind-discovery-check-collisions() {
  local app_env="$1"
  [[ -n ${XCIND_PROXY_EXPORTS+set} && ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]] || return 0

  local -a seen_prefix=() seen_sig=() seen_entry=()
  local entry prefix sig sig_tls i apex_checked=false apex_active=false
  local _export_name _compose_service _port _type _tls
  for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
    _export_name="" _compose_service="" _port="" _type="" _tls=""
    __xcind-proxy-parse-entry "$entry" 2>/dev/null || continue
    prefix="XCIND_${app_env}_$(__xcind-discovery-envify "$_export_name")"
    # Compare normalized definitions: "80" and "80/tcp" are the same port, and
    # tls only matters for proxied exports.
    sig_tls=""
    [[ $_type == "proxied" ]] && sig_tls="$_tls"
    sig="${_export_name}|${_compose_service}|${_port%%/*}|${_type}|${sig_tls}"

    if [[ $prefix == "XCIND_${app_env}_APEX" ]]; then
      if [[ $apex_checked == false ]]; then
        apex_checked=true
        __xcind-proxy-apex-for-app >/dev/null 2>&1 && apex_active=true
      fi
      if [[ $apex_active == true ]]; then
        echo "Error: XCIND_PROXY_EXPORTS entry '$entry' produces discovery variables ${prefix}_*, which collide with the apex variables. Rename the export." >&2
        return 1
      fi
    fi

    for ((i = 0; i < ${#seen_prefix[@]}; i++)); do
      [[ ${seen_prefix[$i]} == "$prefix" ]] || continue
      [[ ${seen_sig[$i]} == "$sig" ]] && continue 2
      echo "Error: XCIND_PROXY_EXPORTS entries '${seen_entry[$i]}' and '$entry' both produce discovery variables ${prefix}_*. Give each export a distinct name (e.g. \"smtp=mailpit:1025;type=unpublished\")." >&2
      return 1
    done
    seen_prefix+=("$prefix")
    seen_sig+=("$sig")
    seen_entry+=("$entry")
  done
}

# --------------------------------------------------------------------------
# Pair builder (shared seam)
# --------------------------------------------------------------------------

# Build the discovery KEY=VALUE pairs for an app under a given view.
#   view: "container" — what a process inside a container uses
#         "host"      — what a host-run process uses (the host env file)
# Prints one KEY=VALUE per line on stdout. Pure: no file writes, no -f, no
# service enumeration. Requires jq only for assigned exports (soft-omitted when
# missing). yq is needed only to infer a container port that the entry does not
# state, in the container view.
#
# Single source of truth for the discovery variable set, shared by the GENERATE
# overlay (xcind-discovery-hook, container view) and the host-view env-file
# emitter (xcind-hostenv-lib.bash, host view) so the two never drift.
#
# View rules (ADR-0024):
#   - Base _HOST/_PORT: proxied and apex are view-invariant (a proxied _HOST is
#     the SNI hostname Traefik routes on and MUST NOT be IP-substituted);
#     assigned are internal in the container view, external in the host view.
#   - _INTERNAL_HOST/_INTERNAL_PORT (address inside Docker): container view only.
#   - _EXTERNAL_HOST/_EXTERNAL_PORT (address outside Docker): view-invariant.
#   - Unpublished exports: container view only; nothing in the host view.
#
# Returns 2 for an invalid view or XCIND_HOST_ENV_ASSIGNED_HOST, 1 for an
# export error (prefix collision, unresolvable unpublished port).
__xcind-discovery-build-pairs() {
  local app_root="$1" view="${2:-container}"
  local app="${XCIND_APP:-$(basename "$app_root")}"

  case "$view" in
  container | host) ;;
  *)
    echo "xcind: invalid discovery view '$view' (expected: container|host)" >&2
    return 2
    ;;
  esac

  # Establish domain, TLS mode, and proxy ports exactly as xcind-proxy-hook
  # does, so generated hostnames stay byte-identical with the proxy labels.
  XCIND_PROXY_DOMAIN="${XCIND_PROXY_DOMAIN:-localhost.scind.io}"
  local global_config="${XCIND_PROXY_CONFIG_DIR:-}/config.sh"
  if [[ -f $global_config ]]; then
    # shellcheck disable=SC1090
    source "$global_config"
  fi
  local proxy_tls_mode="${XCIND_PROXY_TLS_MODE:-auto}"
  local https_port="${XCIND_PROXY_HTTPS_PORT:-443}"
  local http_port="${XCIND_PROXY_HTTP_PORT:-80}"

  case "${XCIND_HOST_ENV_ASSIGNED_HOST:-loopback}" in
  loopback | hostname) ;;
  *)
    echo "xcind: invalid XCIND_HOST_ENV_ASSIGNED_HOST '${XCIND_HOST_ENV_ASSIGNED_HOST}' (expected: loopback|hostname)" >&2
    return 2
    ;;
  esac

  local app_env
  app_env=$(__xcind-discovery-envify "$app")

  __xcind-discovery-check-collisions "$app_env" || return 1

  # Accumulate KEY=VALUE pairs; the same set is attached to every service.
  local -a env_lines=()

  # Workspace identity (workspace mode only).
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]]; then
    env_lines+=("XCIND_WORKSPACE_NAME=${XCIND_WORKSPACE:-}")
  fi

  local entry
  local _export_name _compose_service _port _type _tls _effective_tls
  local exp_env prefix internal_host internal_port

  # ---- Proxied exports ----------------------------------------------------
  if [[ -n ${XCIND_PROXY_EXPORTS+set} && ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]]; then
    for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
      __xcind-proxy-parse-entry "$entry" 2>/dev/null || continue
      [[ $_type == "proxied" ]] || continue

      __xcind-proxy-resolve-export-tls "$proxy_tls_mode"
      local hostname scheme port url
      hostname=$(__xcind-proxy-export-hostname "$_export_name" "$app" "$XCIND_PROXY_DOMAIN")
      scheme=$(__xcind-proxy-preferred-scheme "$_effective_tls")
      if [[ $scheme == "https" ]]; then port="$https_port"; else port="$http_port"; fi
      url=$(__xcind-discovery-url "$scheme" "$hostname" "$port")
      exp_env=$(__xcind-discovery-envify "$_export_name")
      prefix="XCIND_${app_env}_${exp_env}"

      env_lines+=("${prefix}_HOST=$hostname")
      env_lines+=("${prefix}_PORT=$port")
      env_lines+=("${prefix}_SCHEME=$scheme")
      env_lines+=("${prefix}_URL=$url")

      # Protocol-specific variables only when both schemes serve the export.
      if [[ $_effective_tls == "both" ]]; then
        env_lines+=("${prefix}_HTTPS_HOST=$hostname")
        env_lines+=("${prefix}_HTTPS_PORT=$https_port")
        env_lines+=("${prefix}_HTTPS_URL=$(__xcind-discovery-url https "$hostname" "$https_port")")
        env_lines+=("${prefix}_HTTP_HOST=$hostname")
        env_lines+=("${prefix}_HTTP_PORT=$http_port")
        env_lines+=("${prefix}_HTTP_URL=$(__xcind-discovery-url http "$hostname" "$http_port")")
      fi

      # In-network address (container view only). The proxy hook has already
      # validated the service and port, so a failure here is unexpected.
      if [[ $view == container ]]; then
        internal_host=$(__xcind-discovery-internal-host "$app" "$_compose_service")
        internal_port=$(__xcind-discovery-container-port "$_export_name" "$_compose_service" "$_port") || return 1
        env_lines+=("${prefix}_INTERNAL_HOST=$internal_host")
        env_lines+=("${prefix}_INTERNAL_PORT=$internal_port")
      fi
      env_lines+=("${prefix}_EXTERNAL_HOST=$hostname")
      env_lines+=("${prefix}_EXTERNAL_PORT=$port")
    done

    # ---- Apex (first proxied export anchor) -------------------------------
    local _apex_tsv apex_url apex_host apex_scheme apex_port
    if _apex_tsv=$(__xcind-proxy-apex-for-app 2>/dev/null); then
      IFS=$'\t' read -r apex_url apex_host apex_scheme <<<"$_apex_tsv"
      if [[ $apex_scheme == "https" ]]; then apex_port="$https_port"; else apex_port="$http_port"; fi
      apex_url=$(__xcind-discovery-url "$apex_scheme" "$apex_host" "$apex_port")
      local aprefix="XCIND_${app_env}_APEX"
      env_lines+=("${aprefix}_HOST=$apex_host")
      env_lines+=("${aprefix}_PORT=$apex_port")
      env_lines+=("${aprefix}_SCHEME=$apex_scheme")
      env_lines+=("${aprefix}_URL=$apex_url")
    fi
  fi

  # ---- Assigned exports ---------------------------------------------------
  # Assigned discovery needs jq (the state-file JSON contract). When jq is
  # unavailable the assigned variables are simply omitted; proxied variables
  # are unaffected.
  if command -v jq &>/dev/null; then
    local -a current_assigned_exports=()
    if [[ -n ${XCIND_PROXY_EXPORTS+set} && ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]]; then
      local assigned_entry
      for assigned_entry in "${XCIND_PROXY_EXPORTS[@]}"; do
        _export_name="" _compose_service="" _port="" _type=""
        __xcind-proxy-parse-entry "$assigned_entry" 2>/dev/null || continue
        [[ $_type == "assigned" ]] || continue
        current_assigned_exports+=("$_export_name")
      done
    fi

    local assigned_json
    assigned_json=$(__xcind-assigned-json-for-app "$app_root")
    if [[ ${#current_assigned_exports[@]} -gt 0 && -n $assigned_json && $assigned_json != "{}" ]]; then
      local xport
      while IFS= read -r xport; do
        [[ -z $xport ]] && continue

        local declared=false declared_xport
        for declared_xport in "${current_assigned_exports[@]}"; do
          if [[ $declared_xport == "$xport" ]]; then
            declared=true
            break
          fi
        done
        [[ $declared == true ]] || continue

        local csvc cport hport external_host
        csvc=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].compose_service // ""')
        cport=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].container_port')
        hport=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].host_port')
        [[ -z $csvc ]] && csvc="$xport"

        external_host=$(__xcind-discovery-external-assigned-host "$xport" "$app")
        exp_env=$(__xcind-discovery-envify "$xport")
        prefix="XCIND_${app_env}_${exp_env}"

        if [[ $view == host ]]; then
          # Host view: the base pair is the external address.
          env_lines+=("${prefix}_HOST=$external_host")
          env_lines+=("${prefix}_PORT=$hport")
          env_lines+=("${prefix}_HOST_PORT=$hport")
        else
          # Container view: the base pair is the in-network address.
          internal_host=$(__xcind-discovery-internal-host "$app" "$csvc")
          env_lines+=("${prefix}_HOST=$internal_host")
          env_lines+=("${prefix}_PORT=$cport")
          env_lines+=("${prefix}_HOST_PORT=$hport")
          env_lines+=("${prefix}_INTERNAL_HOST=$internal_host")
          env_lines+=("${prefix}_INTERNAL_PORT=$cport")
        fi
        env_lines+=("${prefix}_EXTERNAL_HOST=$external_host")
        env_lines+=("${prefix}_EXTERNAL_PORT=$hport")
      done < <(printf '%s' "$assigned_json" | jq -r 'keys[]')
    fi
  fi

  # ---- Unpublished exports (container view only) --------------------------
  # Declared for discovery only: no Traefik router, no host port, and nothing
  # in the host view. Identical repeated entries are emitted once.
  if [[ $view == container && -n ${XCIND_PROXY_EXPORTS+set} && ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]]; then
    local -a seen_unpublished=()
    local seen_name resolved_config="${XCIND_CACHE_DIR:-}/resolved-config.yaml"
    for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
      _export_name="" _compose_service="" _port="" _type=""
      __xcind-proxy-parse-entry "$entry" 2>/dev/null || continue
      [[ $_type == "unpublished" ]] || continue

      if [[ ${#seen_unpublished[@]} -gt 0 ]]; then
        for seen_name in "${seen_unpublished[@]}"; do
          [[ $seen_name == "$_export_name" ]] && continue 2
        done
      fi
      seen_unpublished+=("$_export_name")

      if command -v yq &>/dev/null && [[ -f $resolved_config ]]; then
        __xcind-proxy-validate-service "$_compose_service" "$resolved_config" || return 1
      fi
      internal_host=$(__xcind-discovery-internal-host "$app" "$_compose_service")
      internal_port=$(__xcind-discovery-container-port "$_export_name" "$_compose_service" "$_port") || return 1
      exp_env=$(__xcind-discovery-envify "$_export_name")
      prefix="XCIND_${app_env}_${exp_env}"
      env_lines+=("${prefix}_HOST=$internal_host")
      env_lines+=("${prefix}_PORT=$internal_port")
      env_lines+=("${prefix}_INTERNAL_HOST=$internal_host")
      env_lines+=("${prefix}_INTERNAL_PORT=$internal_port")
    done
  fi

  # Emit one KEY=VALUE per line, checking variable names across exports: the
  # prefix check above cannot see suffix overlaps (an export `api-internal`
  # produces XCIND_{APP}_API_INTERNAL_HOST, as does `api`'s internal pair; the
  # same holds for -external, -host, -http, -https). A repeated key with the
  # same value (an identical repeated entry) is emitted once; a repeated key
  # with a different value fails rather than letting the last value win.
  # Bash 3.2 has no associative arrays; the pair count is small. Guard the empty
  # case: under `set -u` Bash 3.2 errors on "${arr[@]}" for an empty array.
  if [[ ${#env_lines[@]} -gt 0 ]]; then
    local -a seen_keys=() seen_vals=()
    local _pair _key _val j
    for _pair in "${env_lines[@]}"; do
      _key="${_pair%%=*}"
      _val="${_pair#*=}"
      for ((j = 0; j < ${#seen_keys[@]}; j++)); do
        [[ ${seen_keys[$j]} == "$_key" ]] || continue
        [[ ${seen_vals[$j]} == "$_val" ]] && continue 2
        echo "Error: discovery variable $_key is produced twice with different values ('${seen_vals[$j]}' and '$_val'). Two XCIND_PROXY_EXPORTS names overlap — one is the other plus a suffix such as -internal, -external, -host, -http, or -https. Rename one export." >&2
        return 1
      done
      seen_keys+=("$_key")
      seen_vals+=("$_val")
    done
    for ((j = 0; j < ${#seen_keys[@]}; j++)); do
      printf '%s=%s\n' "${seen_keys[$j]}" "${seen_vals[$j]}"
    done
  fi
}

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline. Generates
# compose.discovery.yaml with the discovery environment block (container view)
# for all services.
xcind-discovery-hook() {
  local app_root="$1"

  # yq is required for service enumeration; record and soft-skip if missing.
  # The consolidated summary is emitted by __xcind-run-hooks at the end of the
  # run. Containers still run without these convenience variables.
  if ! command -v yq &>/dev/null; then
    __XCIND_HOOKS_SKIPPED_NO_YQ+=("xcind-discovery-hook")
    return 0
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"
  if [[ ! -f $resolved_config ]]; then
    echo "Warning: resolved-config.yaml not found, skipping xcind-discovery-hook." >&2
    return 0
  fi

  # Build the container-view pairs (shared seam with the host-view emitter).
  # Captured rather than read from a process substitution so an export error
  # (prefix collision, unresolvable port) fails generation.
  local pairs
  pairs=$(__xcind-discovery-build-pairs "$app_root" container) || return 1
  local -a env_lines=()
  local _pair
  while IFS= read -r _pair; do
    [[ -n $_pair ]] && env_lines+=("$_pair")
  done <<<"$pairs"

  # Nothing to inject (no exports, not in a workspace).
  if [[ ${#env_lines[@]} -eq 0 ]]; then
    return 0
  fi

  # Enumerate all compose services.
  local services
  services=$(__xcind-list-services "$resolved_config")
  [[ -z $services ]] && return 0

  # Build the shared environment block once.
  local env_block="" line
  for line in "${env_lines[@]}"; do
    env_block+=$'\n'"      - $(__xcind-discovery-yaml-quote "$line")"
  done

  # Attach the block to every service.
  local output="services:"
  local service_name
  while IFS= read -r service_name; do
    [[ -z $service_name ]] && continue
    output+=$'\n\n'"  ${service_name}:"
    output+=$'\n'"    environment:${env_block}"
  done <<<"$services"
  output+=$'\n'

  echo "$output" >"$XCIND_GENERATED_DIR/compose.discovery.yaml"

  # Print compose flag to stdout (hook contract).
  echo "-f $XCIND_GENERATED_DIR/compose.discovery.yaml"
}
