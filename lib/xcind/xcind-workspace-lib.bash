#!/usr/bin/env bash
# xcind-workspace-lib.bash — Workspace networking hooks
#
# Provides two hooks:
#   xcind-workspace-hook (GENERATE) — generates compose.workspace.yaml with network aliases
#   __xcind-workspace-execute-hook (EXECUTE) — ensures workspace network exists
#
# This file is auto-sourced by xcind-lib.bash. Hooks are registered by
# default and activate automatically for apps inside a workspace.

# Per-service snippet template for workspace networking and identity labels
XCIND_WORKSPACE_SERVICE_SNIPPET='  {service}:
    labels:
      - "xcind.workspace.name={workspace}"
      - "xcind.workspace.path={workspace_path}"
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
      workspace "${XCIND_WORKSPACE:-}" \
      workspace_path "${XCIND_WORKSPACE_ROOT:-}" \
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

# --------------------------------------------------------------------------
# Execute Hook
# --------------------------------------------------------------------------

# EXECUTE hook: ensure workspace network exists before docker compose executes.
# Runs on every invocation (not cached). Skips if not in workspace mode.
__xcind-workspace-execute-hook() {
  # shellcheck disable=SC2034  # app_root required by hook interface
  local app_root="$1"

  if [[ ${XCIND_WORKSPACELESS:-1} == "1" ]]; then
    return 0
  fi

  local network="${XCIND_WORKSPACE}-internal"
  docker network create "$network" >/dev/null 2>&1 || true
}
