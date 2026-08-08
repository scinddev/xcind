#!/usr/bin/env bash
# xcind-host-gateway-lib.bash — Hook for normalizing host.docker.internal
#
# Generates a compose override that adds extra_hosts entries mapping
# host.docker.internal to the developer's workstation for every service
# that doesn't already define the mapping, and exposes the same resolved
# value as an XCIND_HOST_GATEWAY variable inside every service that does
# not already set it. Handles platform detection automatically (Docker
# Desktop, native Linux, WSL2 NAT/mirrored modes).
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default and runs for all apps.

# --------------------------------------------------------------------------
# Platform Detection Helpers
# --------------------------------------------------------------------------

# Returns 0 if running inside WSL2.
__xcind-is-wsl2() {
  grep -qi microsoft /proc/version 2>/dev/null
}

# Returns 0 if Docker Desktop is handling the Docker daemon.
__xcind-is-docker-desktop() {
  # Method 1: Docker Desktop's WSL integration mount
  if [[ -d /mnt/wsl/docker-desktop ]]; then
    return 0
  fi

  # Method 2: Docker context endpoint indicates Desktop
  local context
  context=$(docker context show 2>/dev/null) || return 1
  if [[ $context == "desktop-linux" || $context == "default" ]]; then
    local endpoint
    endpoint=$(docker context inspect "$context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null) || return 1
    if [[ $endpoint == *"docker-desktop"* || $endpoint == *"Docker/host"* ]]; then
      return 0
    fi
  fi

  return 1
}

# --------------------------------------------------------------------------
# WSL2 Gateway Detection
# --------------------------------------------------------------------------

# Prints the appropriate host gateway value for WSL2 environments.
__xcind-detect-host-gateway-wsl2() {
  local networking_mode
  networking_mode=$(wslinfo --networking-mode 2>/dev/null | tr -d '\r\n')

  # Fallback if wslinfo unavailable
  if [[ -z $networking_mode ]]; then
    if ip link show loopback0 &>/dev/null; then
      networking_mode="mirrored"
    else
      networking_mode="nat"
    fi
  fi

  case "$networking_mode" in
  mirrored | virtioproxy)
    # In mirrored mode, Docker's host-gateway resolves to the Docker
    # bridge gateway inside the WSL2 VM — NOT the Windows host.
    # We need the actual LAN IP, which WSL2 shares with Windows
    # in mirrored mode. This IP is reachable from containers.
    local lan_ip
    lan_ip=$(hostname -I | awk '{print $1}')
    if [[ -n $lan_ip ]]; then
      echo "$lan_ip"
    else
      # Last resort fallback
      echo "host-gateway"
    fi
    ;;
  nat | *)
    # NAT mode: the default gateway IS the Windows host
    local gw_ip
    gw_ip=$(ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1)
    if [[ -n $gw_ip ]]; then
      echo "$gw_ip"
    else
      # Fallback
      echo "host-gateway"
    fi
    ;;
  esac
}

# --------------------------------------------------------------------------
# Core Detection
# --------------------------------------------------------------------------

# Prints the appropriate host gateway value to stdout.
# Prints nothing if host.docker.internal already works (Docker Desktop).
__xcind-detect-host-gateway() {
  # User override — always wins
  if [[ -n ${XCIND_HOST_GATEWAY:-} ]]; then
    echo "$XCIND_HOST_GATEWAY"
    return 0
  fi

  # Docker Desktop — host.docker.internal works via DNS, no overlay needed
  if __xcind-is-docker-desktop; then
    return 0
  fi

  # WSL2 detection
  if __xcind-is-wsl2; then
    __xcind-detect-host-gateway-wsl2
    return $?
  fi

  # Native Linux — host-gateway resolves to docker0 bridge = the host
  echo "host-gateway"
}

# --------------------------------------------------------------------------
# Service Checking
# --------------------------------------------------------------------------

# Returns 0 if the service already has a host.docker.internal mapping.
__xcind-service-has-host-docker-internal() {
  local service="$1"
  local resolved_config="$2"

  # extra_hosts can use "hostname:value" or "hostname=value" separators
  local has_mapping
  has_mapping=$(yq -r \
    ".services.\"$service\".extra_hosts // [] | .[] | select(test(\"^host[.]docker[.]internal[=:]\"))" \
    "$resolved_config" 2>/dev/null)

  [[ -n $has_mapping ]]
}

# Returns 0 if the service already defines an XCIND_HOST_GATEWAY variable.
__xcind-service-has-host-gateway-env() {
  local service="$1"
  local resolved_config="$2"

  # `docker compose config` emits environment as a map, but a service that
  # is only present in an app compose file may still use the "NAME=value"
  # list form — accept both.
  #
  # `type` (not yq-go's `tag`) is used here because `tag` is a mikefarah/
  # yq-go extension that stock jq — and therefore kislyuk/yq, which is a
  # thin wrapper around jq — doesn't define. `type` is a real jq builtin,
  # but the two implementations disagree on its return value for YAML
  # collections: yq-go reports the YAML tag ("!!map"/"!!seq"), kislyuk/yq
  # reports the JSON type ("object"/"array"). Matching both spellings
  # keeps this expression portable across both flavors. Likewise `sub`
  # takes its arguments separated by `;` in standard jq; yq-go tolerates
  # a `,` separator, but jq (and kislyuk/yq) does not.
  local has_env
  has_env=$(yq -r \
    "(.services.\"$service\".environment // {}) | ((select(type == \"!!map\" or type == \"object\") | keys | .[]), (select(type == \"!!seq\" or type == \"array\") | .[] | sub(\"=.*\"; \"\"))) | select(. == \"XCIND_HOST_GATEWAY\")" \
    "$resolved_config" 2>/dev/null)

  [[ -n $has_env ]]
}

# Prints existing extra_hosts entries for a service, one per line.
__xcind-service-existing-extra-hosts() {
  local service="$1"
  local resolved_config="$2"

  yq -r ".services.\"$service\".extra_hosts // [] | .[]" \
    "$resolved_config" 2>/dev/null
}

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline on cache miss.
# Generates compose.host-gateway.yaml with extra_hosts entries and
# XCIND_HOST_GATEWAY environment entries.
xcind-host-gateway-hook() {
  local app_root="$1"
  : "$app_root" # Unused directly but required by hook interface

  # Check opt-out
  if [[ ${XCIND_HOST_GATEWAY_ENABLED:-1} == "0" ]]; then
    return 0
  fi

  # Detect the appropriate host gateway value
  local host_gateway
  host_gateway=$(__xcind-detect-host-gateway)

  # If empty (e.g., Docker Desktop where it's unnecessary), skip
  if [[ -z $host_gateway ]]; then
    return 0
  fi

  # yq is required for this hook; record and soft-skip if missing. The
  # consolidated summary is emitted by __xcind-run-hooks at the end of the run.
  if ! command -v yq &>/dev/null; then
    __XCIND_HOOKS_SKIPPED_NO_YQ+=("xcind-host-gateway-hook")
    return 0
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"

  # Enumerate all compose services
  local services
  services=$(__xcind-list-services "$resolved_config")

  if [[ -z $services ]]; then
    return 0
  fi

  # Collect the services that need each half of the overlay. A service can
  # need the extra_hosts mapping, the XCIND_HOST_GATEWAY variable, or both.
  local emit_services=()
  local needs_mapping=()
  local needs_env=()
  local service_name
  while IFS= read -r service_name; do
    [[ -z $service_name ]] && continue
    local wants_mapping=0 wants_env=0
    __xcind-service-has-host-docker-internal "$service_name" "$resolved_config" || wants_mapping=1
    __xcind-service-has-host-gateway-env "$service_name" "$resolved_config" || wants_env=1
    if [[ $wants_mapping == 1 || $wants_env == 1 ]]; then
      emit_services+=("$service_name")
      needs_mapping+=("$wants_mapping")
      needs_env+=("$wants_env")
    fi
  done <<<"$services"

  # If every service already has both, no-op
  if [[ ${#emit_services[@]} -eq 0 ]]; then
    return 0
  fi

  # Build output — preserve existing extra_hosts entries for each service
  local output="services:"
  local idx=0
  for service_name in "${emit_services[@]}"; do
    output+=$'\n'
    output+=$'\n'"  ${service_name}:"

    if [[ ${needs_mapping[$idx]} == 1 ]]; then
      output+=$'\n'"    extra_hosts:"

      # Carry forward existing entries so the overlay merges rather than replaces
      local existing_host
      while IFS= read -r existing_host; do
        [[ -z $existing_host ]] && continue
        output+=$'\n'"      - \"${existing_host}\""
      done < <(__xcind-service-existing-extra-hosts "$service_name" "$resolved_config")

      output+=$'\n'"      - \"host.docker.internal:${host_gateway}\""
    fi

    # Expose the resolved gateway as a variable inside the container, for
    # tools that read a host address from the environment (e.g. Xdebug
    # client_host). Compose merges environment maps by key, so no
    # carry-forward is needed. A service that already sets the variable
    # itself keeps its own value.
    if [[ ${needs_env[$idx]} == 1 ]]; then
      output+=$'\n'"    environment:"
      output+=$'\n'"      XCIND_HOST_GATEWAY: \"${host_gateway}\""
    fi

    idx=$((idx + 1))
  done

  output+=$'\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.host-gateway.yaml"

  # Print compose flag to stdout (hook contract)
  echo "-f $XCIND_GENERATED_DIR/compose.host-gateway.yaml"
}
