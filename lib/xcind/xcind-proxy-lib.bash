#!/usr/bin/env bash
# xcind-proxy-lib.bash — Proxy hook for generating compose.proxy.yaml
#
# Provides xcind-proxy-hook, a post-resolve-generate hook that generates
# Traefik proxy configuration from XCIND_PROXY_EXPORTS declarations.
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default — apps only need to declare XCIND_PROXY_EXPORTS to use it.

# Per-service YAML snippet template (without workspace labels)
# shellcheck disable=SC2016 # Template placeholders, not shell expansions
XCIND_PROXY_SERVICE_TEMPLATE='  {compose_service}:
    networks:
      default: {}
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=xcind-proxy"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.routers.{router}.service={router}"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"'

# Per-service YAML snippet template (with workspace labels)
# shellcheck disable=SC2016
XCIND_PROXY_SERVICE_TEMPLATE_WORKSPACE='  {compose_service}:
    networks:
      default: {}
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=xcind-proxy"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.routers.{router}.service={router}"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.workspace.name={workspace}"
      - "xcind.workspace.path={workspace_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"'

# Labels-only template for additional exports on the same compose service
# shellcheck disable=SC2016
XCIND_PROXY_LABELS_TEMPLATE='      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.routers.{router}.service={router}"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"'

# Per-service YAML snippet template with apex URL (without workspace labels)
# shellcheck disable=SC2016
XCIND_PROXY_SERVICE_TEMPLATE_APEX='  {compose_service}:
    networks:
      default: {}
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=xcind-proxy"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.routers.{router}.service={router}"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "traefik.http.routers.{apex_router}.rule=Host(`{apex_hostname}`)"
      - "traefik.http.routers.{apex_router}.entrypoints=web"
      - "traefik.http.routers.{apex_router}.service={apex_router}"
      - "traefik.http.services.{apex_router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"
      - "xcind.apex.host={apex_hostname}"
      - "xcind.apex.url=http://{apex_hostname}"'

# Per-service YAML snippet template with apex URL (with workspace labels)
# shellcheck disable=SC2016
XCIND_PROXY_SERVICE_TEMPLATE_APEX_WORKSPACE='  {compose_service}:
    networks:
      default: {}
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=xcind-proxy"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.routers.{router}.service={router}"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "traefik.http.routers.{apex_router}.rule=Host(`{apex_hostname}`)"
      - "traefik.http.routers.{apex_router}.entrypoints=web"
      - "traefik.http.routers.{apex_router}.service={apex_router}"
      - "traefik.http.services.{apex_router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.workspace.name={workspace}"
      - "xcind.workspace.path={workspace_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"
      - "xcind.apex.host={apex_hostname}"
      - "xcind.apex.url=http://{apex_hostname}"'

# --------------------------------------------------------------------------
# Export Entry Parsing
# --------------------------------------------------------------------------

# Parse a single XCIND_PROXY_EXPORTS entry into its components.
# Format: export_name[=compose_service][:port]
#
# Sets: _export_name, _compose_service, _port (empty if not specified)
__xcind-proxy-parse-entry() {
  local entry="$1"
  local right

  # Split on = (export_name=compose_service_and_port or just export_and_port)
  if [[ $entry == *=* ]]; then
    _export_name="${entry%%=*}"
    right="${entry#*=}"
  else
    right="$entry"
    _export_name=""
  fi

  # Split right side on : (service:port or just service)
  if [[ $right == *:* ]]; then
    local svc_part="${right%%:*}"
    _port="${right#*:}"
  else
    local svc_part="$right"
    _port=""
  fi

  _compose_service="$svc_part"

  # If no = was present, export name = compose service name
  if [ -z "$_export_name" ]; then
    _export_name="$_compose_service"
  fi
}

# --------------------------------------------------------------------------
# Port Inference
# --------------------------------------------------------------------------

# Infer the container port for a compose service from resolved-config.yaml.
# Requires yq.
#
# Usage:
#   port=$(__xcind-proxy-infer-port "web" /path/to/resolved-config.yaml)
__xcind-proxy-infer-port() {
  local service="$1"
  local resolved_config="$2"

  local port_count
  port_count=$(yq ".services.\"$service\".ports | length" "$resolved_config" 2>/dev/null) || port_count=0

  if [ "$port_count" -eq 0 ]; then
    echo "Error: Service '$service' has no port mappings. Specify port explicitly." >&2
    return 1
  elif [ "$port_count" -gt 1 ]; then
    echo "Error: Service '$service' has multiple port mappings. Specify port explicitly." >&2
    return 1
  fi

  # Extract the target (container) port from the single port mapping
  local target
  target=$(yq ".services.\"$service\".ports[0].target" "$resolved_config" 2>/dev/null)

  if [ -z "$target" ] || [ "$target" = "null" ]; then
    # Try published format (string like "80:8080")
    local port_str
    port_str=$(yq ".services.\"$service\".ports[0]" "$resolved_config" 2>/dev/null)
    if [[ $port_str == *:* ]]; then
      target="${port_str##*:}"
    else
      target="$port_str"
    fi
  fi

  echo "$target"
}

# --------------------------------------------------------------------------
# Service Validation
# --------------------------------------------------------------------------

# Check that a compose service exists in resolved-config.yaml.
__xcind-proxy-validate-service() {
  local service="$1"
  local resolved_config="$2"

  local exists
  exists=$(yq ".services | has(\"$service\")" "$resolved_config" 2>/dev/null)

  if [ "$exists" != "true" ]; then
    local available
    available=$(yq -r '.services | keys | .[]' "$resolved_config" 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
    echo "Error: Service '$service' not found in compose config. Available services: $available" >&2
    return 1
  fi
}

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline on cache miss.
# Reads pipeline env vars and generates compose.proxy.yaml.
xcind-proxy-hook() {
  local app_root="$1"

  # Check if exports are defined (guard against unset under set -u)
  if [[ -z ${XCIND_PROXY_EXPORTS+set} || ${#XCIND_PROXY_EXPORTS[@]} -eq 0 ]]; then
    return 0
  fi

  # Default domain and source global config
  XCIND_PROXY_DOMAIN="${XCIND_PROXY_DOMAIN:-localhost}"
  local global_config="${HOME}/.config/xcind/proxy/config.sh"
  if [ -f "$global_config" ]; then
    # shellcheck disable=SC1090
    source "$global_config"
  fi

  # Check xcind-proxy network exists
  if ! docker network inspect xcind-proxy &>/dev/null; then
    echo "Error: xcind-proxy network not found. Run 'xcind-proxy init' first." >&2
    return 1
  fi

  # Require yq
  if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for proxy hook but was not found." >&2
    return 1
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"

  # Select service template based on workspace mode
  local service_template
  local apex_service_template=""
  if [[ ${XCIND_WORKSPACELESS:-1} == "1" ]]; then
    service_template="$XCIND_PROXY_SERVICE_TEMPLATE"
    if [[ -n ${XCIND_APP_APEX_URL_TEMPLATE:-} ]]; then
      apex_service_template="$XCIND_PROXY_SERVICE_TEMPLATE_APEX"
    fi
  else
    service_template="$XCIND_PROXY_SERVICE_TEMPLATE_WORKSPACE"
    if [[ -n ${XCIND_APP_APEX_URL_TEMPLATE:-} ]]; then
      apex_service_template="$XCIND_PROXY_SERVICE_TEMPLATE_APEX_WORKSPACE"
    fi
  fi

  # Parse all export entries and group by compose service
  local -a export_names=()
  local -a compose_services=()
  local -a ports=()
  local -a hostnames=()
  local -a routers=()
  local apex_hostname=""
  local apex_router=""

  local entry
  for entry in "${XCIND_PROXY_EXPORTS[@]}"; do
    local _export_name _compose_service _port
    __xcind-proxy-parse-entry "$entry"

    # Validate service exists
    __xcind-proxy-validate-service "$_compose_service" "$resolved_config" || return 1

    # Resolve port
    if [ -z "$_port" ]; then
      _port=$(__xcind-proxy-infer-port "$_compose_service" "$resolved_config") || return 1
    fi

    # Generate hostname
    local hostname
    hostname=$(__xcind-render-template "$XCIND_APP_URL_TEMPLATE" \
      workspace "${XCIND_WORKSPACE:-}" app "$XCIND_APP" \
      export "$_export_name" domain "$XCIND_PROXY_DOMAIN")

    # Generate router name
    local router
    router=$(__xcind-render-template "$XCIND_ROUTER_TEMPLATE" \
      workspace "${XCIND_WORKSPACE:-}" app "$XCIND_APP" \
      export "$_export_name" protocol "http")

    # Generate apex hostname and router for primary export only
    if [[ ${#export_names[@]} -eq 0 && -n $apex_service_template ]]; then
      apex_hostname=$(__xcind-render-template "$XCIND_APP_APEX_URL_TEMPLATE" \
        workspace "${XCIND_WORKSPACE:-}" app "$XCIND_APP" \
        domain "$XCIND_PROXY_DOMAIN")
      apex_router=$(__xcind-render-template "$XCIND_APEX_ROUTER_TEMPLATE" \
        workspace "${XCIND_WORKSPACE:-}" app "$XCIND_APP" \
        protocol "http")
    fi

    export_names+=("$_export_name")
    compose_services+=("$_compose_service")
    ports+=("$_port")
    hostnames+=("$hostname")
    routers+=("$router")
  done

  # Build output grouped by compose service
  local output="services:"
  local -a seen_services=()

  local i=0
  while [ "$i" -lt "${#export_names[@]}" ]; do
    local svc="${compose_services[$i]}"

    # Check if we already rendered this compose service
    local already_seen=false
    local s
    for s in "${seen_services[@]+"${seen_services[@]}"}"; do
      if [ "$s" = "$svc" ]; then
        already_seen=true
        break
      fi
    done

    if [ "$already_seen" = true ]; then
      i=$((i + 1))
      continue
    fi

    seen_services+=("$svc")

    # Find all exports for this compose service
    local first=true
    local service_block=""
    local j=0
    while [ "$j" -lt "${#export_names[@]}" ]; do
      if [ "${compose_services[$j]}" = "$svc" ]; then
        if [ "$first" = true ]; then
          # Use apex template for primary export (index 0), base template otherwise
          local effective_template="$service_template"
          if [[ $j -eq 0 && -n $apex_service_template ]]; then
            effective_template="$apex_service_template"
          fi
          # Render full service block for first export
          service_block=$(__xcind-render-template "$effective_template" \
            compose_service "$svc" \
            router "${routers[$j]}" \
            hostname "${hostnames[$j]}" \
            port "${ports[$j]}" \
            app "$XCIND_APP" \
            app_path "$app_root" \
            workspace "${XCIND_WORKSPACE:-}" \
            workspace_path "${XCIND_WORKSPACE_ROOT:-}" \
            export "${export_names[$j]}" \
            apex_router "$apex_router" \
            apex_hostname "$apex_hostname")
          first=false
        else
          # Append additional labels for subsequent exports
          local extra_labels
          extra_labels=$(__xcind-render-template "$XCIND_PROXY_LABELS_TEMPLATE" \
            router "${routers[$j]}" \
            hostname "${hostnames[$j]}" \
            port "${ports[$j]}" \
            export "${export_names[$j]}")
          service_block+=$'\n'"$extra_labels"
        fi
      fi
      j=$((j + 1))
    done

    output+=$'\n\n'"$service_block"
    i=$((i + 1))
  done

  # Append network footer
  output+=$'\n\nnetworks:\n  xcind-proxy:\n    external: true\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.proxy.yaml"

  # Print compose flag to stdout
  echo "-f $XCIND_GENERATED_DIR/compose.proxy.yaml"
}
