#!/usr/bin/env bash
# xcind-app-env-lib.bash — Hook for injecting env files into container services
#
# Generates a compose override that adds env_file: entries to every service,
# making XCIND_APP_ENV_FILES available inside running containers.

xcind-app-env-hook() {
  local app_root="$1"

  # Skip when no app env files are configured (guard against unset under set -u)
  if [[ -z ${XCIND_APP_ENV_FILES+set} || ${#XCIND_APP_ENV_FILES[@]} -eq 0 ]]; then
    return 0
  fi

  # Resolve app env files to absolute paths
  local resolved_files=()
  local f
  while IFS= read -r f; do
    resolved_files+=("$f")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_APP_ENV_FILES[@]+"${XCIND_APP_ENV_FILES[@]}"})

  # Skip if no files resolved
  if [[ ${#resolved_files[@]} -eq 0 ]]; then
    return 0
  fi

  # Require yq for service enumeration
  if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for app-env hook but was not found." >&2
    return 1
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"

  # Enumerate all compose services
  local services
  services=$(yq -r '.services | keys | .[]' "$resolved_config" 2>/dev/null)

  if [ -z "$services" ]; then
    return 0
  fi

  # Build env_file YAML list
  local env_file_yaml=""
  for f in "${resolved_files[@]}"; do
    env_file_yaml+=$'\n'"      - $f"
  done

  # Build output
  local output="services:"
  local service_name
  while IFS= read -r service_name; do
    [ -z "$service_name" ] && continue
    output+=$'\n\n'"  ${service_name}:"
    output+=$'\n'"    env_file:${env_file_yaml}"
  done <<<"$services"

  output+=$'\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.app-env.yaml"

  # Print compose flag to stdout (hook contract)
  echo "-f $XCIND_GENERATED_DIR/compose.app-env.yaml"
}
