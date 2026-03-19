#!/usr/bin/env bash
# xcind-lib.bash — Shared library for xcind tooling
#
# This file is sourced by xcind-compose and xcind-config.
# It provides app root detection, config loading, and file resolution.

# --------------------------------------------------------------------------
# Version
# --------------------------------------------------------------------------

export XCIND_VERSION="0.0.3"

# --------------------------------------------------------------------------
# App Root Detection
# --------------------------------------------------------------------------

# Walk upward from $PWD (or a given directory) looking for .xcind.sh.
# If XCIND_APP_ROOT is already set, use it directly.
#
# Usage:
#   root=$(__xcind-app-root)
#   root=$(__xcind-app-root /some/starting/dir)
#
# Returns 0 on success, 1 if no app root found.
# Prints the resolved path to stdout.
__xcind-app-root() {
  # If explicitly set, trust it
  if [ -n "${XCIND_APP_ROOT+set}" ] && [ -n "$XCIND_APP_ROOT" ]; then
    echo "$XCIND_APP_ROOT"
    return 0
  fi

  local current_dir="${1:-$PWD}"

  while true; do
    if [ -f "$current_dir/.xcind.sh" ]; then
      echo "$current_dir"
      return 0
    fi

    local parent_dir
    parent_dir=$(dirname "$current_dir")

    if [ "$parent_dir" = "/" ] || [ "$parent_dir" = "$current_dir" ]; then
      echo "Error: No .xcind.sh found. Are you inside an xcind-managed application?" >&2
      return 1
    fi

    current_dir="$parent_dir"
  done
}

# --------------------------------------------------------------------------
# Config Loading
# --------------------------------------------------------------------------

# Source the .xcind.sh config file from the given app root.
# This populates XCIND_COMPOSE_FILES, XCIND_ENV_FILES, etc.
#
# Expected variables that .xcind.sh may set:
#   XCIND_COMPOSE_FILES=()   — Compose file patterns (relative to app root)
#   XCIND_ENV_FILES=()       — Environment file patterns (relative to app root)
#   XCIND_BAKE_FILES=()      — Bake file patterns (reserved for future use)
#   XCIND_COMPOSE_DIR=""     — Subdirectory for compose files (optional convenience)
#
# Usage:
#   __xcind-load-config /path/to/app/root
__xcind-load-config() {
  local app_root="$1"

  # Defaults — can be overridden by .xcind.sh
  # Mirror Docker Compose's default file discovery; only files that exist on
  # disk are used (see __xcind-resolve-files).
  XCIND_COMPOSE_FILES=("compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml")
  XCIND_ENV_FILES=(".env")
  XCIND_BAKE_FILES=()
  XCIND_COMPOSE_DIR=""

  if [ ! -f "$app_root/.xcind.sh" ]; then
    echo "Error: No .xcind.sh found in $app_root" >&2
    return 1
  fi

  # Source in current shell so arrays are available
  # shellcheck disable=SC1091
  source "$app_root/.xcind.sh"
}

# --------------------------------------------------------------------------
# File Resolution
# --------------------------------------------------------------------------

# Given a filename pattern (possibly containing shell variables like ${APP_ENV}),
# expand it and derive the override variant.
#
# The override variant is derived by inserting ".override" before the final
# file extension. For example:
#   compose.common.yaml       → compose.common.override.yaml
#   docker-compose.dev.yaml   → docker-compose.dev.override.yaml
#   .env                      → .env.override
#   .env.local                → .env.local.override
#
# Usage:
#   __xcind-derive-override "compose.common.yaml"
#   # prints: compose.common.override.yaml
__xcind-derive-override() {
  local file="$1"
  local dir base

  dir=$(dirname "$file")
  base=$(basename "$file")

  local result

  # For files with a recognized config extension, insert .override before it.
  # Otherwise, append .override to the full name.
  case "$base" in
  *.yaml | *.yml | *.json | *.hcl | *.toml)
    local ext="${base##*.}"
    local stem="${base%.*}"
    result="${stem}.override.${ext}"
    ;;
  *)
    result="${base}.override"
    ;;
  esac

  if [ "$dir" = "." ]; then
    echo "$result"
  else
    echo "${dir}/${result}"
  fi
}

# Resolve a list of file patterns into concrete, existing file paths.
# For each pattern:
#   1. Expand shell variables (eval)
#   2. Prepend base_dir if the path is relative
#   3. If the file exists, include it
#   4. Derive the .override variant and include it if it exists
#
# Usage:
#   __xcind-resolve-files /path/to/app/root file1 file2 ...
#   # prints one file per line
__xcind-resolve-files() {
  local base_dir="$1"
  shift

  local pattern expanded full_path override_path

  for pattern in "$@"; do
    # Expand variables in the pattern (e.g., ${APP_ENV})
    # Using eval in a controlled context — patterns come from .xcind.sh
    expanded=$(eval echo "$pattern" 2>/dev/null) || continue

    # Skip empty expansions
    [ -z "$expanded" ] && continue

    # Make relative paths absolute
    if [[ $expanded != /* ]]; then
      full_path="$base_dir/$expanded"
    else
      full_path="$expanded"
    fi

    # Include the base file if it exists
    if [ -f "$full_path" ]; then
      echo "$full_path"
    fi

    # Derive and include the override variant if it exists
    local override_name
    override_name=$(__xcind-derive-override "$expanded")

    if [[ $override_name != /* ]]; then
      override_path="$base_dir/$override_name"
    else
      override_path="$override_name"
    fi

    if [ -f "$override_path" ]; then
      echo "$override_path"
    fi
  done
}

# --------------------------------------------------------------------------
# Compose Argument Assembly
# --------------------------------------------------------------------------

# Build the complete docker compose argument array.
# Populates the XCIND_DOCKER_COMPOSE_OPTS array.
#
# Usage:
#   __xcind-build-compose-opts /path/to/app/root
#   docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" "$@"
__xcind-build-compose-opts() {
  local app_root="$1"

  XCIND_DOCKER_COMPOSE_OPTS=()

  # Resolve env files → --env-file flags
  local env_file
  while IFS= read -r env_file; do
    XCIND_DOCKER_COMPOSE_OPTS+=("--env-file" "$env_file")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_ENV_FILES[@]+"${XCIND_ENV_FILES[@]}"})

  # Resolve compose files → -f flags
  local compose_file
  local compose_dir="${XCIND_COMPOSE_DIR:+$app_root/$XCIND_COMPOSE_DIR}"
  local resolve_base="${compose_dir:-$app_root}"

  while IFS= read -r compose_file; do
    XCIND_DOCKER_COMPOSE_OPTS+=("-f" "$compose_file")
  done < <(__xcind-resolve-files "$resolve_base" ${XCIND_COMPOSE_FILES[@]+"${XCIND_COMPOSE_FILES[@]}"})

  # Set Docker Compose project directory so relative paths in compose files resolve correctly
  XCIND_DOCKER_COMPOSE_OPTS+=("--project-directory" "$app_root")
}

# --------------------------------------------------------------------------
# JSON Contract (for xcind-config / JetBrains plugin)
# --------------------------------------------------------------------------

# Output the resolved configuration as JSON.
# Requires jq to be installed.
#
# Usage:
#   __xcind-resolve-json /path/to/app/root
__xcind-resolve-json() {
  local app_root="$1"

  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required for JSON output but was not found." >&2
    return 1
  fi

  # Collect resolved file lists
  local env_files=()
  local env_file
  while IFS= read -r env_file; do
    env_files+=("$env_file")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_ENV_FILES[@]+"${XCIND_ENV_FILES[@]}"})

  local compose_files=()
  local compose_file
  local compose_dir="${XCIND_COMPOSE_DIR:+$app_root/$XCIND_COMPOSE_DIR}"
  local resolve_base="${compose_dir:-$app_root}"

  while IFS= read -r compose_file; do
    compose_files+=("$compose_file")
  done < <(__xcind-resolve-files "$resolve_base" ${XCIND_COMPOSE_FILES[@]+"${XCIND_COMPOSE_FILES[@]}"})

  local bake_files=()
  local bake_file
  while IFS= read -r bake_file; do
    bake_files+=("$bake_file")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_BAKE_FILES[@]+"${XCIND_BAKE_FILES[@]}"})

  # Helper: convert a bash array to a JSON array string
  __to_json_array() {
    if [ $# -eq 0 ]; then
      echo "[]"
    else
      printf '%s\n' "$@" | jq -R . | jq -s .
    fi
  }

  # Build JSON with jq
  jq -n \
    --arg app_root "$app_root" \
    --argjson compose_files "$(__to_json_array ${compose_files[@]+"${compose_files[@]}"})" \
    --argjson env_files "$(__to_json_array ${env_files[@]+"${env_files[@]}"})" \
    --argjson bake_files "$(__to_json_array ${bake_files[@]+"${bake_files[@]}"})" \
    '{
            appRoot: $app_root,
            composeFiles: $compose_files,
            envFiles: $env_files,
            bakeFiles: $bake_files
        }'
}

# --------------------------------------------------------------------------
# Docker Wrapper Generation
# --------------------------------------------------------------------------

# Generate a POSIX-compatible docker-compose wrapper script.
# The wrapper tries xcind-compose first, falling back to docker compose.
#
# Usage:
#   __xcind-dump-docker-compose-wrapper /path/to/app /path/to/xcind/bin
__xcind-dump-docker-compose-wrapper() {
  local app_root="$1"
  local xcind_bin_dir="$2"

  cat <<EOF
#!/bin/sh
set -eu
PATH="\$PATH:${xcind_bin_dir}"
export XCIND_APP_ROOT="${app_root}"
if command -v xcind-compose >/dev/null 2>&1; then
    exec xcind-compose "\$@"
else
    exec docker compose "\$@"
fi
EOF
}

# Generate a POSIX-compatible docker wrapper script.
# Intercepts "docker compose" and routes it through xcind-compose;
# all other docker subcommands pass through to docker directly.
#
# Usage:
#   __xcind-dump-docker-wrapper /path/to/app /path/to/xcind/bin
__xcind-dump-docker-wrapper() {
  local app_root="$1"
  local xcind_bin_dir="$2"

  cat <<EOF
#!/bin/sh
set -eu
PATH="\$PATH:${xcind_bin_dir}"
export XCIND_APP_ROOT="${app_root}"
if [ \$# -gt 0 ] && [ "\$1" = "compose" ]; then
    shift
    if command -v xcind-compose >/dev/null 2>&1; then
        exec xcind-compose "\$@"
    else
        exec docker compose "\$@"
    fi
else
    exec docker "\$@"
fi
EOF
}

# --------------------------------------------------------------------------
# Debug / Dry-Run
# --------------------------------------------------------------------------

# Print the docker compose command that would be executed.
#
# Usage:
#   __xcind-preview-command /path/to/app/root [compose args...]
__xcind-preview-command() {
  local app_root="$1"
  shift

  __xcind-build-compose-opts "$app_root"

  echo "# Working directory: $app_root"
  echo "docker compose ${XCIND_DOCKER_COMPOSE_OPTS[*]} $*"
}

# --------------------------------------------------------------------------
# Template Rendering
# --------------------------------------------------------------------------

# Render a template string by replacing {key} placeholders with values.
# Remaining key/value pairs are passed as positional arguments after the template.
#
# Usage:
#   __xcind-render-template "{service}-{app}.{domain}" \
#     service "web" \
#     app "myapp" \
#     domain "localhost"
#   # prints: web-myapp.localhost
#
# Returns 0 on success.
__xcind-render-template() {
  local result="$1"
  shift
  while [[ $# -ge 2 ]]; do
    result="${result//\{$1\}/$2}"
    shift 2
  done
  echo "$result"
}
