#!/usr/bin/env bash
# xcind-lib.bash — Shared library for xcind tooling
#
# This file is sourced by xcind-compose and xcind-config.
# It provides app root detection, config loading, and file resolution.

# --------------------------------------------------------------------------
# Version
# --------------------------------------------------------------------------

export XCIND_VERSION="0.5.0"

# --------------------------------------------------------------------------
# Built-in hooks
# --------------------------------------------------------------------------

__XCIND_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-naming-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-app-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-app-env-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-proxy-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-assigned-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-host-gateway-lib.bash"
# shellcheck disable=SC1091
source "$__XCIND_LIB_DIR/xcind-workspace-lib.bash"

XCIND_HOOKS_GENERATE=("xcind-naming-hook" "xcind-app-hook" "xcind-app-env-hook" "xcind-host-gateway-hook" "xcind-proxy-hook" "xcind-assigned-hook" "xcind-workspace-hook")
XCIND_HOOKS_EXECUTE=("__xcind-proxy-execute-hook" "__xcind-workspace-execute-hook")

# Names of hooks that soft-skipped this run because yq was missing.
# Populated by hooks themselves; drained and reported as a single
# consolidated warning by __xcind-run-hooks.
__XCIND_HOOKS_SKIPPED_NO_YQ=()

# --------------------------------------------------------------------------
# Portable SHA-256 helper
# --------------------------------------------------------------------------

# Cross-platform SHA-256 wrapper.
# Uses sha256sum (Linux coreutils/busybox) or shasum (macOS stock Perl).
__xcind-sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$@"
  else
    shasum -a 256 "$@"
  fi
}

# Enumerate compose service names from a resolved-config.yaml. Prints one
# service name per line. Silent on error or when .services is empty/missing —
# returns 0 whether yq succeeds or fails, so callers can safely use the
# result inside `local var; var=$(...)` under `set -e` + `pipefail`.
# Requires yq on PATH — callers must guard their own yq availability (hooks
# may soft-skip or hard-fail depending on whether their output is load-bearing).
#
# Usage:
#   while IFS= read -r svc; do ... done < <(__xcind-list-services "$path")
__xcind-list-services() {
  local resolved_config="$1"
  yq -r '.services // {} | keys | .[]' "$resolved_config" 2>/dev/null || true
}

# --------------------------------------------------------------------------
# Workspace Detection
# --------------------------------------------------------------------------

# Return 0 if <dir>/.xcind.sh exists and declares XCIND_IS_WORKSPACE=1
# when sourced in a clean subshell. Return 1 otherwise (including when
# the file does not exist).
#
# Usage:
#   if __xcind-is-workspace-dir "$dir"; then ...
__xcind-is-workspace-dir() {
  local dir="$1"
  [ -f "$dir/.xcind.sh" ] || return 1
  local _is
  # shellcheck disable=SC1091,SC2030,SC2031
  _is=$(
    XCIND_IS_WORKSPACE=""
    source "$dir/.xcind.sh" 2>/dev/null
    echo "${XCIND_IS_WORKSPACE:-}"
  )
  [ "$_is" = "1" ]
}

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
# shellcheck disable=SC2120  # __xcind-prepare-app calls with no args
__xcind-app-root() {
  # If explicitly set, trust it
  if [ -n "${XCIND_APP_ROOT+set}" ] && [ -n "$XCIND_APP_ROOT" ]; then
    echo "$XCIND_APP_ROOT"
    return 0
  fi

  local current_dir="${1:-$PWD}"

  while true; do
    # An app root has a .xcind.sh that is NOT a workspace marker
    if [ -f "$current_dir/.xcind.sh" ] && ! __xcind-is-workspace-dir "$current_dir"; then
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
# This populates XCIND_COMPOSE_FILES, XCIND_COMPOSE_ENV_FILES, etc.
#
# Expected variables that .xcind.sh may set:
#   XCIND_COMPOSE_FILES=()       — Compose file patterns (relative to app root)
#   XCIND_COMPOSE_ENV_FILES=()   — Env file patterns for compose YAML interpolation (--env-file)
#   XCIND_APP_ENV_FILES=()       — Env file patterns injected into containers (env_file:)
#   XCIND_BAKE_FILES=()          — Bake file patterns (reserved for future use)
#   XCIND_TOOLS=()               — Tool declarations (name:service[;key=value…])
#   XCIND_COMPOSE_DIR=""         — Subdirectory for compose files (optional convenience)
#
# Usage:
#   __xcind-load-config /path/to/app/root
__xcind-load-config() {
  local app_root="$1"

  # Defaults — only set when not already defined (e.g., by workspace .xcind.sh).
  # Mirror Docker Compose's default file discovery; only files that exist on
  # disk are used (see __xcind-resolve-files).
  if [[ -z ${XCIND_COMPOSE_FILES+set} ]]; then
    XCIND_COMPOSE_FILES=("compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml")
  fi
  if [[ -z ${XCIND_BAKE_FILES+set} ]]; then
    XCIND_BAKE_FILES=()
  fi
  if [[ -z ${XCIND_TOOLS+set} ]]; then
    XCIND_TOOLS=()
  fi
  if [[ -z ${XCIND_COMPOSE_DIR+set} ]]; then
    XCIND_COMPOSE_DIR=""
  fi
  if [[ -z ${XCIND_ADDITIONAL_CONFIG_FILES+set} ]]; then
    XCIND_ADDITIONAL_CONFIG_FILES=()
  fi

  if [ ! -f "$app_root/.xcind.sh" ]; then
    echo "Error: No .xcind.sh found in $app_root" >&2
    return 1
  fi

  # Source in current shell so arrays are available
  # shellcheck disable=SC1091
  source "$app_root/.xcind.sh"
  __XCIND_SOURCED_CONFIG_FILES+=("$app_root/.xcind.sh")

  # BC shim: migrate XCIND_ENV_FILES → XCIND_COMPOSE_ENV_FILES
  if [[ -n ${XCIND_ENV_FILES+set} ]]; then
    if [[ -n ${XCIND_COMPOSE_ENV_FILES+set} ]]; then
      echo "xcind: warning: both XCIND_ENV_FILES (deprecated) and XCIND_COMPOSE_ENV_FILES are set; XCIND_ENV_FILES will take precedence" >&2
    fi
    XCIND_COMPOSE_ENV_FILES=("${XCIND_ENV_FILES[@]}")
    echo "xcind: warning: XCIND_ENV_FILES is deprecated, use XCIND_COMPOSE_ENV_FILES instead" >&2
  fi

  # Env file defaults (after source + BC shim so migration works)
  if [[ -z ${XCIND_COMPOSE_ENV_FILES+set} ]]; then
    XCIND_COMPOSE_ENV_FILES=(".env")
  fi
  if [[ -z ${XCIND_APP_ENV_FILES+set} ]]; then
    XCIND_APP_ENV_FILES=()
  fi
}

# --------------------------------------------------------------------------
# Variable Expansion
# --------------------------------------------------------------------------

# Expand $VAR and ${VAR} references in a pattern from .xcind.sh.
# Prints the expanded result to stdout, or empty on failure.
#
# Compared to `eval echo "$pattern"`, this:
#   - Does not go through echo, so patterns like "-n" round-trip correctly.
#   - Disables glob expansion during the eval, so "*.yaml" is not expanded
#     against CWD.
# Command substitution ($(cmd)) is still honored for backward compatibility
# with existing .xcind.sh files that use patterns like ".env.$(hostname)".
#
# Usage:
#   expanded=$(__xcind-expand-vars "$pattern")
__xcind-expand-vars() {
  local pattern="$1"
  local expanded="" _prev_glob=on
  case $- in *f*) _prev_glob=off ;; esac
  set -f
  eval "expanded=\"${pattern//\"/\\\"}\"" 2>/dev/null || expanded=""
  [ "$_prev_glob" = on ] && set +f
  printf '%s' "$expanded"
}

# --------------------------------------------------------------------------
# Additional Config Sourcing
# --------------------------------------------------------------------------

# Source additional config files declared in XCIND_ADDITIONAL_CONFIG_FILES.
# For each entry: expand variables, resolve relative to base_dir, source if
# exists, then derive and source the .override variant if it exists.
#
# Usage:
#   __xcind-source-additional-configs /path/to/base/dir
__xcind-source-additional-configs() {
  local base_dir="$1"

  # Nothing to do if no additional configs declared or base_dir is empty
  [[ -z $base_dir ]] && return 0
  [[ -z ${XCIND_ADDITIONAL_CONFIG_FILES+set} ]] && return 0
  [[ ${#XCIND_ADDITIONAL_CONFIG_FILES[@]} -eq 0 ]] && return 0

  local pattern expanded full_path override_path

  for pattern in "${XCIND_ADDITIONAL_CONFIG_FILES[@]}"; do
    # Expand variables in the pattern (e.g., ${APP_ENV})
    expanded=$(__xcind-expand-vars "$pattern")
    [ -z "$expanded" ] && continue

    # Make relative paths absolute
    if [[ $expanded != /* ]]; then
      full_path="$base_dir/$expanded"
    else
      full_path="$expanded"
    fi

    # Source the file if it exists
    if [ -f "$full_path" ]; then
      # shellcheck disable=SC1090
      source "$full_path"
      __XCIND_SOURCED_CONFIG_FILES+=("$full_path")
    fi

    # Derive and source the override variant if it exists
    local override_name
    override_name=$(__xcind-derive-override "$expanded")

    if [[ $override_name != /* ]]; then
      override_path="$base_dir/$override_name"
    else
      override_path="$override_name"
    fi

    if [ -f "$override_path" ]; then
      # shellcheck disable=SC1090
      source "$override_path"
      __XCIND_SOURCED_CONFIG_FILES+=("$override_path")
    fi
  done
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
  *.yaml | *.yml | *.json | *.hcl | *.toml | *.sh)
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
    expanded=$(__xcind-expand-vars "$pattern")

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
  done < <(__xcind-resolve-files "$app_root" ${XCIND_COMPOSE_ENV_FILES[@]+"${XCIND_COMPOSE_ENV_FILES[@]}"})

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
# Pipeline
# --------------------------------------------------------------------------

# Run the full app-resolution pipeline: detect the app root, load config,
# resolve files, compute the SHA, populate the cache, and run GENERATE
# hooks. EXECUTE hooks and the final `docker compose` invocation are NOT
# run here — callers decide whether to run them.
#
# The following globals are populated in the CURRENT shell (not a
# subshell), so callers must invoke this function directly, not inside
# `$(...)`:
#   XCIND_APP_ROOT, XCIND_APP, XCIND_WORKSPACE, XCIND_WORKSPACE_ROOT,
#   XCIND_WORKSPACELESS, XCIND_APP_URL_TEMPLATE, XCIND_ROUTER_TEMPLATE,
#   XCIND_WORKSPACE_SERVICE_TEMPLATE, XCIND_APP_APEX_URL_TEMPLATE,
#   XCIND_APEX_ROUTER_TEMPLATE, XCIND_DOCKER_COMPOSE_OPTS,
#   __XCIND_SOURCED_CONFIG_FILES; and when any GENERATE hooks are
#   registered: XCIND_SHA, XCIND_CACHE_DIR, XCIND_GENERATED_DIR.
#
# Usage:
#   __xcind-prepare-app || exit 1
#   # ... use "$XCIND_APP_ROOT" and "${XCIND_DOCKER_COMPOSE_OPTS[@]}"
__xcind-prepare-app() {
  local app_root
  # shellcheck disable=SC2119  # intentionally called with no args
  app_root=$(__xcind-app-root) || return 1
  export XCIND_APP_ROOT="$app_root"

  # Reset the set of config files sourced during this pipeline run
  __XCIND_SOURCED_CONFIG_FILES=()

  # Discover workspace (sets XCIND_WORKSPACE* before load-config runs)
  __xcind-discover-workspace "$app_root"

  # Workspace-level additional configs (sourced before app config so app wins)
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]] && [[ -n ${XCIND_WORKSPACE_ROOT:-} ]]; then
    __xcind-source-additional-configs "$XCIND_WORKSPACE_ROOT"
  fi

  # App config + additional configs + workspace self-declaration
  __xcind-load-config "$app_root" || return 1
  __xcind-source-additional-configs "$app_root"
  __xcind-late-bind-workspace

  # Resolve names/URLs and build docker compose options
  __xcind-resolve-app "$app_root"
  __xcind-resolve-url-templates
  __xcind-build-compose-opts "$app_root"

  # Cache + GENERATE hooks only when hooks are registered
  if [[ ${#XCIND_HOOKS_GENERATE[@]} -gt 0 ]]; then
    XCIND_SHA=$(__xcind-compute-sha "$app_root")
    export XCIND_SHA
    export XCIND_CACHE_DIR="$app_root/.xcind/cache/$XCIND_SHA"
    export XCIND_GENERATED_DIR="$app_root/.xcind/generated/$XCIND_SHA"
    export XCIND_APP XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS
    export XCIND_APP_URL_TEMPLATE XCIND_ROUTER_TEMPLATE XCIND_WORKSPACE_SERVICE_TEMPLATE
    export XCIND_APP_APEX_URL_TEMPLATE XCIND_APEX_ROUTER_TEMPLATE

    # Explicit || return 1 because `set -e` does not propagate out of a
    # function called in a conditional context (`__xcind-prepare-app || exit 1`).
    __xcind-populate-cache "$app_root" || return 1
    __xcind-run-hooks "$app_root" || return 1
  fi
}

# --------------------------------------------------------------------------
# JSON Contract (for xcind-config / JetBrains plugin)
# --------------------------------------------------------------------------

# Parse XCIND_TOOLS into a JSON object keyed by tool name.
# First entry for a given tool name wins; subsequent duplicates are skipped.
#
# Usage:
#   __xcind-resolve-tools
#   # prints: {"php":{"service":"app","use":"exec"},"npm":{"service":"app","use":"exec"}}
__xcind-resolve-tools() {
  if [[ ${#XCIND_TOOLS[@]} -eq 0 ]]; then
    echo "{}"
    return 0
  fi

  local seen_names=""
  local first=true
  local entry name remainder service meta use path key val

  printf '{'
  for entry in "${XCIND_TOOLS[@]}"; do
    # Split on ':' for name and service (with optional metadata after ';')
    name="${entry%%:*}"
    remainder="${entry#*:}"
    service="${remainder%%;*}"
    meta=""
    if [[ $remainder == *";"* ]]; then
      meta="${remainder#*;}"
    fi

    # Skip duplicates (first wins) — linear scan of seen names
    case ",$seen_names," in
    *",$name,"*) continue ;;
    esac
    seen_names="${seen_names:+$seen_names,}$name"

    # Parse metadata key=value pairs
    use="exec"
    path=""
    if [[ -n $meta ]]; then
      local IFS=';'
      local pairs
      # shellcheck disable=SC2206
      pairs=($meta)
      unset IFS
      local pair
      for pair in "${pairs[@]}"; do
        key="${pair%%=*}"
        val="${pair#*=}"
        case "$key" in
        use) use="$val" ;;
        path) path="$val" ;;
        esac
      done
    fi

    # Emit JSON
    if [[ $first == true ]]; then
      first=false
    else
      printf ','
    fi

    if [[ -n $path ]]; then
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --arg u "$use" --arg p "$path" \
          '{service: $s, use: $u, path: $p}')"
    else
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --arg u "$use" \
          '{service: $s, use: $u}')"
    fi
  done
  printf '}'
}

# Print, one per line, the value following each `-f` flag in
# XCIND_DOCKER_COMPOSE_OPTS. Safe to call when the array is empty.
# Preserves paths containing spaces.
__xcind-extract-compose-f-files() {
  local i=0
  while [ "$i" -lt "${#XCIND_DOCKER_COMPOSE_OPTS[@]}" ]; do
    if [ "${XCIND_DOCKER_COMPOSE_OPTS[$i]}" = "-f" ]; then
      i=$((i + 1))
      printf '%s\n' "${XCIND_DOCKER_COMPOSE_OPTS[$i]}"
    fi
    i=$((i + 1))
  done
}

# Output the resolved configuration as JSON.
# Convert a bash array to a JSON array string.
# Requires jq.
__xcind-to-json-array() {
  if [ $# -eq 0 ]; then
    echo "[]"
  else
    printf '%s\n' "$@" | jq -R . | jq -s .
  fi
}

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
  local compose_env_files=()
  local _cef
  while IFS= read -r _cef; do
    compose_env_files+=("$_cef")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_COMPOSE_ENV_FILES[@]+"${XCIND_COMPOSE_ENV_FILES[@]}"})

  local app_env_files=()
  local _aef
  while IFS= read -r _aef; do
    app_env_files+=("$_aef")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_APP_ENV_FILES[@]+"${XCIND_APP_ENV_FILES[@]}"})

  local compose_files=()
  local compose_file
  local compose_dir="${XCIND_COMPOSE_DIR:+$app_root/$XCIND_COMPOSE_DIR}"
  local resolve_base="${compose_dir:-$app_root}"

  while IFS= read -r compose_file; do
    compose_files+=("$compose_file")
  done < <(__xcind-resolve-files "$resolve_base" ${XCIND_COMPOSE_FILES[@]+"${XCIND_COMPOSE_FILES[@]}"})

  # Include hook-generated compose files from XCIND_DOCKER_COMPOSE_OPTS,
  # skipping any file already resolved above.
  local _f
  while IFS= read -r _f; do
    local _already=false
    local _c
    for _c in "${compose_files[@]+"${compose_files[@]}"}"; do
      if [ "$_c" = "$_f" ]; then
        _already=true
        break
      fi
    done
    if [ "$_already" = false ]; then
      compose_files+=("$_f")
    fi
  done < <(__xcind-extract-compose-f-files)

  local bake_files=()
  local bake_file
  while IFS= read -r bake_file; do
    bake_files+=("$bake_file")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_BAKE_FILES[@]+"${XCIND_BAKE_FILES[@]}"})

  # Metadata
  local _ws_name="${XCIND_WORKSPACE:-}"
  local _app_name="${XCIND_APP:-$(basename "$app_root")}"
  local _workspaceless="${XCIND_WORKSPACELESS:-1}"

  # Resolve tools
  local tools_json
  tools_json=$(__xcind-resolve-tools)

  # Resolve assigned exports (empty object when none or jq unavailable)
  local assigned_json
  assigned_json=$(__xcind-assigned-json-for-app "$app_root")

  # Build JSON with jq
  jq -n \
    --arg app_root "$app_root" \
    --argjson config_files "$(__xcind-to-json-array ${__XCIND_SOURCED_CONFIG_FILES[@]+"${__XCIND_SOURCED_CONFIG_FILES[@]}"})" \
    --argjson compose_files "$(__xcind-to-json-array ${compose_files[@]+"${compose_files[@]}"})" \
    --argjson compose_env_files "$(__xcind-to-json-array ${compose_env_files[@]+"${compose_env_files[@]}"})" \
    --argjson app_env_files "$(__xcind-to-json-array ${app_env_files[@]+"${app_env_files[@]}"})" \
    --argjson bake_files "$(__xcind-to-json-array ${bake_files[@]+"${bake_files[@]}"})" \
    --argjson tools "$tools_json" \
    --argjson assigned_exports "$assigned_json" \
    --arg ws_name "$_ws_name" \
    --arg app_name "$_app_name" \
    --argjson workspaceless "$([ "$_workspaceless" = "0" ] && echo false || echo true)" \
    '{
            metadata: {
                workspace: (if $ws_name == "" then null else $ws_name end),
                app: $app_name,
                workspaceless: $workspaceless
            },
            appRoot: $app_root,
            configFiles: $config_files,
            composeFiles: $compose_files,
            composeEnvFiles: $compose_env_files,
            appEnvFiles: $app_env_files,
            bakeFiles: $bake_files,
            tools: $tools,
            assignedExports: $assigned_exports
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

# Dump the fully resolved Docker Compose configuration to stdout.
#
# Usage:
#   __xcind-dump-docker-compose-configuration
__xcind-dump-docker-compose-configuration() {
  xcind-compose config
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

  # Use already-populated opts if available (e.g., from xcind-config pipeline)
  if [[ ${#XCIND_DOCKER_COMPOSE_OPTS[@]} -eq 0 ]]; then
    __xcind-build-compose-opts "$app_root"
  fi

  echo "# Working directory: $app_root"

  # Shell-quote each argument so paths containing spaces (or other
  # special characters) round-trip through copy-paste. `printf '%q'` is a
  # Bash builtin and works on Bash 3.2+.
  local _arg _quoted_opts="" _quoted_args=""
  for _arg in "${XCIND_DOCKER_COMPOSE_OPTS[@]}"; do
    _quoted_opts+=" $(printf '%q' "$_arg")"
  done
  _quoted_opts="${_quoted_opts# }"

  for _arg in "$@"; do
    _quoted_args+=" $(printf '%q' "$_arg")"
  done
  _quoted_args="${_quoted_args# }"

  if [[ -n $_quoted_args ]]; then
    printf 'docker compose %s %s\n' "$_quoted_opts" "$_quoted_args"
  else
    printf 'docker compose %s\n' "$_quoted_opts"
  fi
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

# --------------------------------------------------------------------------
# Workspace Discovery
# --------------------------------------------------------------------------

# Discover workspace by checking if the parent directory of XCIND_APP_ROOT
# contains a .xcind.sh file. If found, source it and set workspace variables.
#
# Must be called after XCIND_APP_ROOT is set but before __xcind-load-config.
#
# Sets: XCIND_WORKSPACE_ROOT, XCIND_WORKSPACE, XCIND_WORKSPACELESS
__xcind-discover-workspace() {
  local app_root="$1"
  local parent
  parent="$(dirname "$app_root")"

  if __xcind-is-workspace-dir "$parent"; then
    XCIND_WORKSPACE_ROOT="$parent"
    XCIND_WORKSPACE="$(basename "$parent")"
    XCIND_WORKSPACELESS=0
    # shellcheck disable=SC1091
    source "$parent/.xcind.sh"
    __XCIND_SOURCED_CONFIG_FILES+=("$parent/.xcind.sh")
  else
    XCIND_WORKSPACELESS=1
    XCIND_WORKSPACE_ROOT=""
    XCIND_WORKSPACE=""
  fi
}

# Late-bind workspace self-declaration.
# If no workspace was discovered but app .xcind.sh set XCIND_WORKSPACE,
# flip to workspace mode.
__xcind-late-bind-workspace() {
  if [[ ${XCIND_WORKSPACELESS:-1} == "1" ]] && [[ -n ${XCIND_WORKSPACE:-} ]]; then
    XCIND_WORKSPACE_ROOT="${XCIND_WORKSPACE_ROOT:-$XCIND_APP_ROOT}"
    XCIND_WORKSPACELESS=0
  fi
}

# Resolve the application name.
# Defaults to basename of XCIND_APP_ROOT unless already set.
__xcind-resolve-app() {
  local app_root="$1"
  XCIND_APP="${XCIND_APP:-$(basename "$app_root")}"
}

# --------------------------------------------------------------------------
# URL Template Resolution
# --------------------------------------------------------------------------

# Select the correct URL template variants based on workspace mode.
# Sets XCIND_APP_URL_TEMPLATE, XCIND_ROUTER_TEMPLATE.
# Also defaults XCIND_WORKSPACE_SERVICE_TEMPLATE.
__xcind-resolve-url-templates() {
  # Defaults — assigned separately to avoid brace expansion in ${:-...}
  local _default_wl_url='{app}-{export}.{domain}'
  local _default_ws_url='{workspace}-{app}-{export}.{domain}'
  local _default_wl_router='{app}-{export}-{protocol}'
  local _default_ws_router='{workspace}-{app}-{export}-{protocol}'
  local _default_svc='{app}-{service}'

  # Apex defaults — shorter app-level hostnames without {export}
  local _default_wl_apex_url='{app}.{domain}'
  local _default_ws_apex_url='{workspace}-{app}.{domain}'
  local _default_wl_apex_router='{app}-{protocol}'
  local _default_ws_apex_router='{workspace}-{app}-{protocol}'

  local workspaceless_url="${XCIND_WORKSPACELESS_APP_URL_TEMPLATE:-$_default_wl_url}"
  local workspace_url="${XCIND_WORKSPACE_APP_URL_TEMPLATE:-$_default_ws_url}"
  local workspaceless_router="${XCIND_WORKSPACELESS_ROUTER_TEMPLATE:-$_default_wl_router}"
  local workspace_router="${XCIND_WORKSPACE_ROUTER_TEMPLATE:-$_default_ws_router}"

  # Apex: use ${VAR-default} (no colon) so explicit empty string disables apex
  local workspaceless_apex_url="${XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE-$_default_wl_apex_url}"
  local workspace_apex_url="${XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE-$_default_ws_apex_url}"
  local workspaceless_apex_router="${XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE-$_default_wl_apex_router}"
  local workspace_apex_router="${XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE-$_default_ws_apex_router}"

  # shellcheck disable=SC2034 # Used by hooks and exported by xcind-compose
  if [[ ${XCIND_WORKSPACELESS:-1} == "1" ]]; then
    XCIND_APP_URL_TEMPLATE="$workspaceless_url"
    XCIND_ROUTER_TEMPLATE="$workspaceless_router"
    XCIND_APP_APEX_URL_TEMPLATE="$workspaceless_apex_url"
    XCIND_APEX_ROUTER_TEMPLATE="$workspaceless_apex_router"
  else
    XCIND_APP_URL_TEMPLATE="$workspace_url"
    XCIND_ROUTER_TEMPLATE="$workspace_router"
    XCIND_APP_APEX_URL_TEMPLATE="$workspace_apex_url"
    XCIND_APEX_ROUTER_TEMPLATE="$workspace_apex_router"
  fi

  # shellcheck disable=SC2034 # Used by workspace hook
  XCIND_WORKSPACE_SERVICE_TEMPLATE="${XCIND_WORKSPACE_SERVICE_TEMPLATE:-$_default_svc}"
}

# --------------------------------------------------------------------------
# SHA Computation & Caching
# --------------------------------------------------------------------------

# Compute a SHA256 hash from resolved file paths, their content, and config files.
# Outputs the SHA hex string to stdout.
#
# Usage:
#   sha=$(__xcind-compute-sha /path/to/app/root)
__xcind-compute-sha() {
  local app_root="$1"
  local sha_input=""

  # Collect compose file paths from XCIND_DOCKER_COMPOSE_OPTS (-f flags)
  local compose_files=()
  local _f
  while IFS= read -r _f; do
    compose_files+=("$_f")
  done < <(__xcind-extract-compose-f-files)

  # Sort file paths for stability
  local sorted_files
  sorted_files=$(printf '%s\n' "${compose_files[@]}" | sort)

  # Add sorted paths + content hashes
  local file
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    sha_input+="$file"
    if [ -f "$file" ]; then
      sha_input+=$(__xcind-sha256 "$file" | cut -d' ' -f1)
    fi
  done <<<"$sorted_files"

  # Add compose env file content hashes
  local _env_file
  while IFS= read -r _env_file; do
    [ -z "$_env_file" ] && continue
    sha_input+="$_env_file"
    if [ -f "$_env_file" ]; then
      sha_input+=$(__xcind-sha256 "$_env_file" | cut -d' ' -f1)
    fi
  done < <(__xcind-resolve-files "$app_root" ${XCIND_COMPOSE_ENV_FILES[@]+"${XCIND_COMPOSE_ENV_FILES[@]}"})

  # Add app env file content hashes
  while IFS= read -r _env_file; do
    [ -z "$_env_file" ] && continue
    sha_input+="$_env_file"
    if [ -f "$_env_file" ]; then
      sha_input+=$(__xcind-sha256 "$_env_file" | cut -d' ' -f1)
    fi
  done < <(__xcind-resolve-files "$app_root" ${XCIND_APP_ENV_FILES[@]+"${XCIND_APP_ENV_FILES[@]}"})

  # Add app .xcind.sh content
  if [ -f "$app_root/.xcind.sh" ]; then
    sha_input+=$(__xcind-sha256 "$app_root/.xcind.sh" | cut -d' ' -f1)
  fi

  # Add workspace .xcind.sh content (if workspace mode)
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]] && [[ -n ${XCIND_WORKSPACE_ROOT:-} ]] && [ -f "$XCIND_WORKSPACE_ROOT/.xcind.sh" ]; then
    sha_input+=$(__xcind-sha256 "$XCIND_WORKSPACE_ROOT/.xcind.sh" | cut -d' ' -f1)
  fi

  # Add additional config file content hashes
  local _cfg
  for _cfg in "${__XCIND_SOURCED_CONFIG_FILES[@]+"${__XCIND_SOURCED_CONFIG_FILES[@]}"}"; do
    # Skip app and workspace .xcind.sh — already hashed above
    [[ $_cfg == "$app_root/.xcind.sh" ]] && continue
    if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]] && [[ -n ${XCIND_WORKSPACE_ROOT:-} ]] && [[ $_cfg == "$XCIND_WORKSPACE_ROOT/.xcind.sh" ]]; then
      continue
    fi
    if [ -f "$_cfg" ]; then
      sha_input+=$(__xcind-sha256 "$_cfg" | cut -d' ' -f1)
    fi
  done

  # Add global config if exists
  local global_config="${XDG_CONFIG_HOME:-$HOME/.config}/xcind/proxy/config.sh"
  if [ -f "$global_config" ]; then
    sha_input+=$(__xcind-sha256 "$global_config" | cut -d' ' -f1)
  fi

  # Add tools declarations
  if [[ ${#XCIND_TOOLS[@]} -gt 0 ]]; then
    sha_input+=$(printf '%s\n' "${XCIND_TOOLS[@]}")
  fi

  # Add naming-relevant variables so overrides invalidate the cache
  sha_input+="XCIND_APP=${XCIND_APP:-}
"
  sha_input+="XCIND_WORKSPACE=${XCIND_WORKSPACE:-}
"
  sha_input+="XCIND_WORKSPACELESS=${XCIND_WORKSPACELESS:-}
"

  # Add host-gateway variables so env changes invalidate the cache
  sha_input+="XCIND_HOST_GATEWAY_ENABLED=${XCIND_HOST_GATEWAY_ENABLED:-}
"
  sha_input+="XCIND_HOST_GATEWAY=${XCIND_HOST_GATEWAY:-}
"

  # Add the runtime-detected host-gateway value so IP or networking-mode
  # changes invalidate the cache (e.g. WSL2 mirrored mode LAN IP changing
  # after DHCP renewal or VPN toggle).
  if [[ ${XCIND_HOST_GATEWAY_ENABLED:-1} != "0" ]]; then
    sha_input+="XCIND_HOST_GATEWAY_DETECTED=$(__xcind-detect-host-gateway 2>/dev/null)
"
  fi

  printf '%s' "$sha_input" | __xcind-sha256 | cut -d' ' -f1
}

# Populate the cache directory with resolved config artifacts.
# Runs docker compose config and writes config.json + resolved-config.yaml.
#
# Usage:
#   __xcind-populate-cache /path/to/app/root
__xcind-populate-cache() {
  local app_root="$1"

  mkdir -p "$XCIND_CACHE_DIR"

  # Write resolved-config.yaml via docker compose config (use temp file to avoid
  # leaving a corrupt cache file if the command fails)
  local _resolved_tmp="$XCIND_CACHE_DIR/resolved-config.yaml.tmp"
  if docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" config >"$_resolved_tmp"; then
    mv -- "$_resolved_tmp" "$XCIND_CACHE_DIR/resolved-config.yaml"
  else
    rm -f -- "$_resolved_tmp"
    return 1
  fi

  # Write config.json (matching xcind-config format)
  if command -v jq &>/dev/null; then
    __xcind-resolve-json "$app_root" >"$XCIND_CACHE_DIR/config.json"
  fi
}

# --------------------------------------------------------------------------
# Dependency Check
# --------------------------------------------------------------------------

# Check whether required and optional external dependencies are available.
# Prints a human-readable report and returns 0 when all *required* deps are
# present (missing optional deps produce warnings but not a failure).
#
# Usage:
#   __xcind-check-deps
__xcind-check-deps() {
  local rc=0
  local required_missing=0
  local warnings=0

  echo "xcind v${XCIND_VERSION} — dependency check"
  echo ""

  # --- helpers -----------------------------------------------------------
  __check_required() {
    local cmd="$1" purpose="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
      local ver
      ver=$(__dep_version "$cmd")
      printf "  ✓ %-20s %s\n" "$cmd" "$ver"
    else
      printf "  ✗ %-20s %-12s  %s\n" "$cmd" "(not found)" "$purpose"
      required_missing=$((required_missing + 1))
      rc=1
    fi
  }

  __check_optional() {
    local cmd="$1" purpose="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
      local ver
      ver=$(__dep_version "$cmd")
      printf "  ✓ %-20s %s\n" "$cmd" "$ver"
    else
      printf "  ✗ %-20s %-12s  %s\n" "$cmd" "(not found)" "$purpose"
      warnings=$((warnings + 1))
    fi
  }

  __dep_version() {
    local cmd="$1" out
    case "$cmd" in
    bash) out=$(bash --version 2>/dev/null) && echo "$out" | head -1 | sed 's/.*version \([^ ]*\).*/\1/' ;;
    docker) docker --version 2>/dev/null | sed 's/Docker version \([^,]*\).*/\1/' ;;
    "docker compose") docker compose version --short 2>/dev/null || echo "?" ;;
    jq) jq --version 2>/dev/null | sed 's/^jq-//' ;;
    yq) yq --version 2>/dev/null | sed 's/.*version v\{0,1\}//' ;;
    sha256sum) out=$(sha256sum --version 2>/dev/null) && echo "$out" | head -1 | sed 's/.*(GNU coreutils) //' ;;
    shasum) out=$(shasum --version 2>/dev/null) && echo "$out" | head -1 || echo "?" ;;
    *) echo "" ;;
    esac
  }
  # -----------------------------------------------------------------------

  echo "Required:"
  __check_required bash "shell interpreter"
  __check_required docker "container runtime"
  __check_required yq "YAML parsing for default-registered hooks"

  # docker compose is a subcommand, not a standalone binary
  if docker compose version >/dev/null 2>&1; then
    local dc_ver
    dc_ver=$(__dep_version "docker compose")
    printf "  ✓ %-20s %s\n" "docker compose" "$dc_ver"
  else
    printf "  ✗ %-20s %-12s  %s\n" "docker compose" "(not found)" "required by xcind-compose"
    required_missing=$((required_missing + 1))
    rc=1
  fi

  # SHA-256: either sha256sum or shasum satisfies the requirement
  if command -v sha256sum >/dev/null 2>&1; then
    local ver
    ver=$(__dep_version sha256sum)
    printf "  ✓ %-20s %s\n" "sha256sum" "$ver"
  elif command -v shasum >/dev/null 2>&1; then
    local ver
    ver=$(__dep_version shasum)
    printf "  ✓ %-20s %s  %s\n" "shasum" "$ver" "(sha256sum alternative)"
  else
    printf "  ✗ %-20s %-12s  %s\n" "sha256sum/shasum" "(not found)" "cache invalidation"
    required_missing=$((required_missing + 1))
    rc=1
  fi

  echo ""
  echo "Optional (needed for specific features):"
  __check_optional jq "JSON output (xcind-config --json, xcind-workspace --json)"

  echo ""

  # --- summary -----------------------------------------------------------
  local issues=$((required_missing + warnings))
  if [ "$issues" -eq 0 ]; then
    echo "All dependencies found."
  else
    echo "$issues issue(s) found:"
    if [ "$required_missing" -gt 0 ]; then
      echo "  • Required dependencies are missing — core functionality will not work."
    fi
    if [ "$warnings" -gt 0 ]; then
      echo "  • Optional dependencies are missing — some features will be unavailable."
    fi
  fi

  # clean up helpers from the shell namespace
  unset -f __check_required __check_optional __dep_version

  return "$rc"
}

# Print a one-line hint to stderr when xcind dependencies are missing from
# PATH, suggesting the user run 'xcind-config --check' for details. Intended
# as a gentle nudge for interactive invocations — silent in scripts and CI.
#
# Suppressed when:
#   - $XCIND_SUPPRESS_DEP_WARNING is non-empty
#   - stderr is not a terminal
#
# Usage:
#   __xcind-maybe-warn-deps
__xcind-maybe-warn-deps() {
  [ -n "${XCIND_SUPPRESS_DEP_WARNING:-}" ] && return 0
  [ -t 2 ] || return 0

  local missing=()
  command -v yq >/dev/null 2>&1 || missing+=("yq")
  command -v jq >/dev/null 2>&1 || missing+=("jq")

  [ "${#missing[@]}" -eq 0 ] && return 0

  local list
  list=$(printf '%s, ' "${missing[@]}")
  list=${list%, }
  echo "xcind: dependency not found on PATH: ${list} — run 'xcind-config --check' for details" >&2
}

# --------------------------------------------------------------------------
# Hook Execution
# --------------------------------------------------------------------------

# Parse hook output line-by-line, validating that any `-f PATH` entries
# still reference existing files. Returns 0 if valid, 1 on first miss.
#
# Hook output format: one argument per line, each line either a single
# token (e.g. "--verbose") or a flag and value separated by a single space
# (e.g. "-f /path/to/compose.yaml"). Line-based parsing preserves paths
# containing spaces, which word-splitting does not.
__xcind-validate-hook-output() {
  local output="$1"
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ $line == *" "* ]]; then
      local flag="${line%% *}"
      local value="${line#* }"
      if [ "$flag" = "-f" ] && [ ! -f "$value" ]; then
        return 1
      fi
    fi
  done <<<"$output"
  return 0
}

# Append hook output tokens to XCIND_DOCKER_COMPOSE_OPTS, preserving paths
# with spaces. Each non-empty line becomes one or two array elements
# depending on whether it contains a space separator.
__xcind-append-hook-output-to-opts() {
  local output="$1"
  local line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ $line == *" "* ]]; then
      XCIND_DOCKER_COMPOSE_OPTS+=("${line%% *}" "${line#* }")
    else
      XCIND_DOCKER_COMPOSE_OPTS+=("$line")
    fi
  done <<<"$output"
}

# Run GENERATE hooks with cache hit/miss logic.
# On cache miss: runs hooks, persists output, appends to XCIND_DOCKER_COMPOSE_OPTS.
# On cache hit: replays persisted output, validates referenced files.
#
# Usage:
#   __xcind-run-hooks /path/to/app/root
__xcind-run-hooks() {
  local app_root="$1"

  # Reset skipped-hooks tracking for this run so the end-of-run summary
  # reflects only this invocation.
  __XCIND_HOOKS_SKIPPED_NO_YQ=()

  if [ -d "$XCIND_GENERATED_DIR" ]; then
    # Cache hit — replay persisted hook output in XCIND_HOOKS_GENERATE order
    local hook_name
    for hook_name in "${XCIND_HOOKS_GENERATE[@]}"; do
      local hook_output_file="$XCIND_GENERATED_DIR/.hook-output-$hook_name"
      [ -f "$hook_output_file" ] || continue

      # Read persisted output
      local output
      output=$(<"$hook_output_file")
      [ -z "$output" ] && continue

      # Verify referenced files still exist; on miss, rebuild from scratch.
      if ! __xcind-validate-hook-output "$output"; then
        rm -rf "$XCIND_GENERATED_DIR"
        __xcind-run-hooks "$app_root"
        return $?
      fi

      # Append to compose opts (preserves paths with spaces)
      __xcind-append-hook-output-to-opts "$output"
    done
  else
    # Cache miss — run hooks and persist output
    mkdir -p "$XCIND_GENERATED_DIR"

    local hook_name
    for hook_name in "${XCIND_HOOKS_GENERATE[@]}"; do
      local output
      output=$("$hook_name" "$app_root") || {
        local rc=$?
        echo "Error: Hook '$hook_name' failed with exit code $rc" >&2
        return $rc
      }

      # Persist hook output (printf, not echo — echo would swallow/transform
      # a first line starting with -n/-e/-E if a future hook ever emits one)
      printf '%s\n' "$output" >"$XCIND_GENERATED_DIR/.hook-output-$hook_name"

      # Append to compose opts (preserves paths with spaces)
      if [ -n "$output" ]; then
        __xcind-append-hook-output-to-opts "$output"
      fi
    done
  fi

  # Consolidated summary for hooks that soft-skipped due to missing yq.
  # Hard-failing hooks (proxy, app-env, assigned) never reach this point —
  # all three are opt-in via explicit exports declarations and their output
  # is load-bearing, so a missing yq there should halt the pipeline loudly.
  if [ "${#__XCIND_HOOKS_SKIPPED_NO_YQ[@]}" -gt 0 ]; then
    local _skipped_list
    _skipped_list=$(printf '%s, ' "${__XCIND_HOOKS_SKIPPED_NO_YQ[@]}")
    _skipped_list=${_skipped_list%, }
    echo "xcind: skipped hook(s) due to missing yq: ${_skipped_list}" >&2
    echo "xcind: install yq or run 'xcind-config --check' for details" >&2
  fi
}

# Run EXECUTE hooks unconditionally (no caching).
# These ensure runtime preconditions before docker compose runs.
#
# Usage:
#   __xcind-run-execute-hooks /path/to/app/root
__xcind-run-execute-hooks() {
  local app_root="$1"

  # Guard: empty array is unbound under set -u in Bash 3.2
  if [[ ${#XCIND_HOOKS_EXECUTE[@]} -eq 0 ]]; then
    return 0
  fi

  local hook_name
  for hook_name in "${XCIND_HOOKS_EXECUTE[@]}"; do
    "$hook_name" "$app_root"
  done
}
