#!/usr/bin/env bash
# xcind-discovery-lib.bash — Hook for injecting service-discovery env vars
#
# Generates a compose override that adds an `environment:` block of
# XCIND_{APP}_{EXPORT}_{SUFFIX} variables to every service of the current app,
# so applications can read their own export hostnames/ports/URLs at runtime
# without hardcoding them. Scope is own-app only (v1): a container receives the
# discovery variables for its own app's exports, not other apps' exports.
#
# Variable schema (app/export segments hyphen→underscore, uppercased):
#   Proxied export E:
#     XCIND_{APP}_{E}_HOST    proxied hostname
#     XCIND_{APP}_{E}_PORT    proxy entrypoint port (https→443 / http→80, overridable)
#     XCIND_{APP}_{E}_SCHEME  http | https
#     XCIND_{APP}_{E}_URL     {scheme}://{hostname}
#     # plus _HTTPS_HOST/_PORT/_URL and _HTTP_HOST/_PORT/_URL when both schemes serve
#   Apex (first proxied export only, when an apex template is configured):
#     XCIND_{APP}_APEX_HOST/_PORT/_SCHEME/_URL
#   Assigned export E:
#     XCIND_{APP}_{E}_HOST       in-network host ({app}-{service} alias in a
#                                workspace, else the compose service name)
#     XCIND_{APP}_{E}_PORT       container port
#     XCIND_{APP}_{E}_HOST_PORT  allocated host-published port
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

# --------------------------------------------------------------------------
# Pair builder (shared seam)
# --------------------------------------------------------------------------

# Build the discovery KEY=VALUE pairs for an app under a given view.
#   view: "container" (in-network alias/service + container port) or
#         "host" (127.0.0.1 + assigned host port).
# Prints one KEY=VALUE per line on stdout. Pure: no file writes, no -f, no
# service enumeration. Requires jq only for assigned exports (soft-omitted when
# missing); does NOT require yq — the caller owns service enumeration.
#
# Single source of truth for the discovery variable set, shared by the GENERATE
# overlay (xcind-discovery-hook, container view) and the host-view env-file
# emitter (xcind-hostenv-lib.bash, host view) so the two never drift. The view
# split is strictly scoped to assigned exports: only their _HOST/_PORT change.
# The proxied + apex blocks and XCIND_WORKSPACE_NAME are view-invariant — a
# proxied _HOST is the SNI hostname Traefik routes on and MUST NOT be IP-substituted.
__xcind-discovery-build-pairs() {
  local app_root="$1" view="${2:-container}"
  local app="${XCIND_APP:-$(basename "$app_root")}"

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

  local app_env
  app_env=$(__xcind-discovery-envify "$app")

  # Accumulate KEY=VALUE pairs; the same set is attached to every service.
  local -a env_lines=()

  # Workspace identity (workspace mode only).
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]]; then
    env_lines+=("XCIND_WORKSPACE_NAME=${XCIND_WORKSPACE:-}")
  fi

  # ---- Proxied exports ----------------------------------------------------
  if [[ -n ${XCIND_PROXY_EXPORTS+set} && ${#XCIND_PROXY_EXPORTS[@]} -gt 0 ]]; then
    local entry
    local _export_name _compose_service _port _type _tls _effective_tls
    for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
      __xcind-proxy-parse-entry "$entry" 2>/dev/null || continue
      [[ $_type == "proxied" ]] || continue

      __xcind-proxy-resolve-export-tls "$proxy_tls_mode"
      local hostname scheme port url exp_env prefix
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

        local csvc cport hport host port_for_view exp_env prefix
        csvc=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].compose_service // ""')
        cport=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].container_port')
        hport=$(printf '%s' "$assigned_json" | jq -r --arg k "$xport" '.[$k].host_port')
        [[ -z $csvc ]] && csvc="$xport"

        if [[ $view == host ]]; then
          # Host view: reachable on the loopback IP + the allocated host port.
          # Literal 127.0.0.1 (not localhost) avoids ::1/IPv6 surprises in
          # strict clients; _PORT carries the host port on the host.
          host="127.0.0.1"
          port_for_view="$hport"
        else
          # Container view in-network host: workspace alias when in a workspace
          # (where the alias actually exists), else the compose service name
          # reachable on Compose's default network; _PORT is the container port.
          if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]]; then
            host=$(__xcind-render-template "$XCIND_WORKSPACE_SERVICE_TEMPLATE" \
              workspace "${XCIND_WORKSPACE:-}" app "$app" service "$csvc")
          else
            host="$csvc"
          fi
          port_for_view="$cport"
        fi

        exp_env=$(__xcind-discovery-envify "$xport")
        prefix="XCIND_${app_env}_${exp_env}"
        env_lines+=("${prefix}_HOST=$host")
        env_lines+=("${prefix}_PORT=$port_for_view")
        env_lines+=("${prefix}_HOST_PORT=$hport")
      done < <(printf '%s' "$assigned_json" | jq -r 'keys[]')
    fi
  fi

  # Emit one KEY=VALUE per line. Guard the empty case: under `set -u` Bash 3.2
  # errors on "${arr[@]}" for an empty array.
  if [[ ${#env_lines[@]} -gt 0 ]]; then
    local _pair
    for _pair in "${env_lines[@]}"; do
      printf '%s\n' "$_pair"
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
  local -a env_lines=()
  local _pair
  while IFS= read -r _pair; do
    [[ -n $_pair ]] && env_lines+=("$_pair")
  done < <(__xcind-discovery-build-pairs "$app_root" container)

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
