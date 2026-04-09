#!/usr/bin/env bash
# xcind-app-lib.bash — Hook for applying app identity labels
#
# Generates a compose override that adds xcind.app.name and xcind.app.path
# labels to every service. This ensures all xcind-managed containers are
# discoverable via Docker labels, regardless of proxy or workspace status.
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default and runs for all apps.

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline on cache miss.
# Generates compose.app.yaml with app identity labels for all services.
xcind-app-hook() {
  local app_root="$1"
  local app="${XCIND_APP:-$(basename "$app_root")}"

  # yq is required for this hook; record and soft-skip if missing. The
  # consolidated summary is emitted by __xcind-run-hooks at the end of the run.
  if ! command -v yq &>/dev/null; then
    __XCIND_HOOKS_SKIPPED_NO_YQ+=("xcind-app-hook")
    return 0
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"

  if [[ ! -f "$resolved_config" ]]; then
    echo "Warning: resolved-config.yaml not found, skipping xcind-app-hook." >&2
    return 0
  fi

  # Enumerate all compose services
  local services
  services=$(yq -r '.services | keys | .[]' "$resolved_config" 2>/dev/null)

  if [[ -z "$services" ]]; then
    return 0
  fi

  # Build output
  local output="services:"
  local service_name
  while IFS= read -r service_name; do
    [[ -z "$service_name" ]] && continue
    output+=$'\n'
    output+=$'\n'"  ${service_name}:"
    output+=$'\n'"    labels:"
    output+=$'\n'"      - \"xcind.app.name=${app}\""
    output+=$'\n'"      - \"xcind.app.path=${app_root}\""
  done <<<"$services"

  output+=$'\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.app.yaml"

  # Print compose flag to stdout (hook contract)
  echo "-f $XCIND_GENERATED_DIR/compose.app.yaml"
}
