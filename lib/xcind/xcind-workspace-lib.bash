#!/usr/bin/env bash
# xcind-workspace-lib.bash — Workspace networking hook for generating compose.workspace.yaml
#
# Provides xcind-workspace-hook, a post-resolve-generate hook that generates
# workspace network aliases for all compose services.
#
# Source this file in .xcind.sh to make the hook available:
#   source "$(dirname "$(command -v xcind-compose)")/../lib/xcind/xcind-workspace-lib.bash"
#   XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook" "xcind-workspace-hook")

# Per-service snippet template for workspace networking
XCIND_WORKSPACE_SERVICE_SNIPPET='  {service}:
    networks:
      default: {}
      {network}:
        aliases:
          - {alias}'

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline on cache miss.
# Generates compose.workspace.yaml with network aliases for all services.
xcind-workspace-hook() {
  local app_root="$1" # Hook contract requires this parameter
  : "$app_root"       # Unused in this hook but required by interface

  # Skip when not in workspace mode
  if [[ ${XCIND_WORKSPACELESS:-1} == "1" ]]; then
    return 0
  fi

  # Require yq
  if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for workspace hook but was not found." >&2
    return 1
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"
  local network="${XCIND_WORKSPACE}-internal"

  # Ensure workspace network exists (lazy, idempotent)
  docker network create "$network" >/dev/null 2>&1 || true

  # Enumerate all compose services
  local services
  services=$(yq -r '.services | keys | .[]' "$resolved_config" 2>/dev/null)

  if [ -z "$services" ]; then
    return 0
  fi

  # Build output
  local output="services:"

  local service_name
  while IFS= read -r service_name; do
    [ -z "$service_name" ] && continue

    # Generate alias
    local alias
    alias=$(__xcind-render-template "$XCIND_WORKSPACE_SERVICE_TEMPLATE" \
      workspace "${XCIND_WORKSPACE:-}" \
      app "$XCIND_APP" \
      service "$service_name")

    # Render service snippet
    local snippet
    snippet=$(__xcind-render-template "$XCIND_WORKSPACE_SERVICE_SNIPPET" \
      service "$service_name" \
      network "$network" \
      alias "$alias")

    output+=$'\n\n'"$snippet"
  done <<<"$services"

  # Append network footer
  output+=$'\n\nnetworks:\n  '"$network"$':\n    external: true\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.workspace.yaml"

  # Print compose flag to stdout
  echo "-f $XCIND_GENERATED_DIR/compose.workspace.yaml"
}
