#!/usr/bin/env bash
# shellcheck disable=SC2016
# test-xcind.sh — Verify xcind resolution logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$XCIND_ROOT/lib/xcind/xcind-lib.bash"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack == *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack != *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected NOT to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

# ======================================================================
echo "=== Test: __xcind-derive-override ==="

assert_eq "yaml with dots" \
  "compose.common.override.yaml" \
  "$(__xcind-derive-override "compose.common.yaml")"

assert_eq "simple yaml" \
  "compose.override.yaml" \
  "$(__xcind-derive-override "compose.yaml")"

assert_eq "with directory" \
  "docker/compose.dev.override.yaml" \
  "$(__xcind-derive-override "docker/compose.dev.yaml")"

assert_eq "dotfile" \
  ".env.override" \
  "$(__xcind-derive-override ".env")"

assert_eq "dotfile with suffix" \
  ".env.local.override" \
  "$(__xcind-derive-override ".env.local")"

assert_eq "hcl file" \
  "docker-bake.override.hcl" \
  "$(__xcind-derive-override "docker-bake.hcl")"

assert_eq "sh file" \
  ".xcind.dev.override.sh" \
  "$(__xcind-derive-override ".xcind.dev.sh")"

# ======================================================================
echo ""
echo "=== Test: __xcind-app-root ==="

# Set up a mock application
MOCK_APP=$(mktemp -d)
mkdir -p "$MOCK_APP/src/deep/nested"
echo '# test config' >"$MOCK_APP/.xcind.sh"

# Test: find from application root
result=$(__xcind-app-root "$MOCK_APP")
assert_eq "finds root from root" "$MOCK_APP" "$result"

# Test: find from nested dir
result=$(__xcind-app-root "$MOCK_APP/src/deep/nested")
assert_eq "finds root from nested" "$MOCK_APP" "$result"

# Test: explicit XCIND_APP_ROOT overrides detection
# shellcheck disable=SC2034
XCIND_APP_ROOT="/explicit/path" result=$(__xcind-app-root "$MOCK_APP/src")
assert_eq "XCIND_APP_ROOT override" "/explicit/path" "$result"
unset XCIND_APP_ROOT

# Test: fails when no .xcind.sh found
EMPTY_DIR=$(mktemp -d)
result=$(__xcind-app-root "$EMPTY_DIR" 2>/dev/null) && status=0 || status=$?
assert_eq "fails without .xcind.sh" "1" "$status"

rm -rf "$MOCK_APP" "$EMPTY_DIR"

# ======================================================================
echo ""
echo "=== Test: __xcind-resolve-files ==="

# Set up a mock application with files
MOCK_APP=$(mktemp -d)
mkdir -p "$MOCK_APP/docker"

# Create some compose files
touch "$MOCK_APP/docker/compose.yaml"
touch "$MOCK_APP/docker/compose.override.yaml"
touch "$MOCK_APP/docker/compose.common.yaml"
touch "$MOCK_APP/docker/compose.dev.yaml"
touch "$MOCK_APP/docker/compose.dev.override.yaml"
# compose.traefik.yaml does NOT exist (should be skipped)
# compose.common.override.yaml does NOT exist (should be skipped)

# Create env files
touch "$MOCK_APP/.env"
touch "$MOCK_APP/.env.local"
# .env.override does NOT exist

resolved=$(
  __xcind-resolve-files "$MOCK_APP/docker" \
    "compose.yaml" \
    "compose.common.yaml" \
    "compose.dev.yaml" \
    "compose.traefik.yaml"
)

assert_contains "includes compose.yaml" \
  "compose.yaml" "$resolved"

assert_contains "includes compose.override.yaml (auto-derived)" \
  "compose.override.yaml" "$resolved"

assert_contains "includes compose.common.yaml" \
  "compose.common.yaml" "$resolved"

assert_not_contains "skips compose.common.override.yaml (doesn't exist)" \
  "compose.common.override" "$resolved"

assert_contains "includes compose.dev.yaml" \
  "compose.dev.yaml" "$resolved"

assert_contains "includes compose.dev.override.yaml (auto-derived)" \
  "compose.dev.override.yaml" "$resolved"

assert_not_contains "skips compose.traefik.yaml (doesn't exist)" \
  "compose.traefik" "$resolved"

# Test env file resolution
env_resolved=$(__xcind-resolve-files "$MOCK_APP" ".env" ".env.local")

assert_contains "includes .env" "$MOCK_APP/.env" "$env_resolved"
assert_contains "includes .env.local" "$MOCK_APP/.env.local" "$env_resolved"
assert_not_contains "skips .env.override (doesn't exist)" \
  ".env.override" "$env_resolved"

# ======================================================================
echo ""
echo "=== Test: Variable expansion in file patterns ==="

export APP_ENV="dev"
var_resolved=$(
  __xcind-resolve-files "$MOCK_APP/docker" \
    'compose.${APP_ENV}.yaml'
)

assert_contains 'expands ${APP_ENV} to dev' \
  "compose.dev.yaml" "$var_resolved"

assert_contains "derives override for expanded pattern" \
  "compose.dev.override.yaml" "$var_resolved"

# Test with a different APP_ENV value where file doesn't exist
export APP_ENV="prod"
prod_resolved=$(
  __xcind-resolve-files "$MOCK_APP/docker" \
    'compose.${APP_ENV}.yaml'
)

assert_not_contains "skips compose.prod.yaml (doesn't exist)" \
  "compose.prod" "$prod_resolved"

unset APP_ENV

# ======================================================================
echo ""
echo "=== Test: __xcind-load-config defaults ==="

# Set up an application with standard Docker Compose files and a minimal .xcind.sh
DEFAULT_APP=$(mktemp -d)
echo '# empty config — rely on defaults' >"$DEFAULT_APP/.xcind.sh"
touch "$DEFAULT_APP/compose.yaml"
touch "$DEFAULT_APP/docker-compose.yml"
touch "$DEFAULT_APP/.env"

__xcind-load-config "$DEFAULT_APP"

assert_eq "default XCIND_COMPOSE_FILES count" "4" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "default XCIND_COMPOSE_FILES[0]" "compose.yaml" "${XCIND_COMPOSE_FILES[0]}"
assert_eq "default XCIND_COMPOSE_FILES[1]" "compose.yml" "${XCIND_COMPOSE_FILES[1]}"
assert_eq "default XCIND_COMPOSE_FILES[2]" "docker-compose.yaml" "${XCIND_COMPOSE_FILES[2]}"
assert_eq "default XCIND_COMPOSE_FILES[3]" "docker-compose.yml" "${XCIND_COMPOSE_FILES[3]}"
assert_eq "default XCIND_COMPOSE_ENV_FILES count" "1" "${#XCIND_COMPOSE_ENV_FILES[@]}"
assert_eq "default XCIND_COMPOSE_ENV_FILES[0]" ".env" "${XCIND_COMPOSE_ENV_FILES[0]}"
assert_eq "default XCIND_APP_ENV_FILES count" "0" "${#XCIND_APP_ENV_FILES[@]}"
assert_eq "default XCIND_COMPOSE_DIR is empty" "" "$XCIND_COMPOSE_DIR"
assert_eq "default XCIND_BAKE_FILES count" "0" "${#XCIND_BAKE_FILES[@]}"

# Build compose opts and verify only existing files are included
__xcind-build-compose-opts "$DEFAULT_APP"
default_opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"

assert_contains "default opts include compose.yaml" "compose.yaml" "$default_opts"
assert_contains "default opts include docker-compose.yml" "docker-compose.yml" "$default_opts"
assert_not_contains "default opts skip docker-compose.yaml (doesn't exist)" "docker-compose.yaml" "$default_opts"
assert_contains "default opts include .env" ".env" "$default_opts"

rm -rf "$DEFAULT_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-load-config overrides defaults ==="

OVERRIDE_PROJECT=$(mktemp -d)
cat >"$OVERRIDE_PROJECT/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("my-compose.yaml")
XCIND_COMPOSE_ENV_FILES=(".env.custom")
EOF
touch "$OVERRIDE_PROJECT/my-compose.yaml"
touch "$OVERRIDE_PROJECT/.env.custom"

__xcind-load-config "$OVERRIDE_PROJECT"

assert_eq "override XCIND_COMPOSE_FILES count" "1" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "override XCIND_COMPOSE_FILES[0]" "my-compose.yaml" "${XCIND_COMPOSE_FILES[0]}"
assert_eq "override XCIND_COMPOSE_ENV_FILES count" "1" "${#XCIND_COMPOSE_ENV_FILES[@]}"
assert_eq "override XCIND_COMPOSE_ENV_FILES[0]" ".env.custom" "${XCIND_COMPOSE_ENV_FILES[0]}"

rm -rf "$OVERRIDE_PROJECT"

# ======================================================================
echo ""
echo "=== Test: BC shim migrates XCIND_ENV_FILES ==="

BC_APP=$(mktemp -d)
cat >"$BC_APP/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_ENV_FILES=(".env.legacy")
EOF
touch "$BC_APP/compose.yaml"
touch "$BC_APP/.env.legacy"

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES
__XCIND_SOURCED_CONFIG_FILES=()

bc_stderr_file=$(mktemp)
__xcind-load-config "$BC_APP" 2>"$bc_stderr_file"
bc_stderr=$(<"$bc_stderr_file")
rm "$bc_stderr_file"

assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES count" "1" "${#XCIND_COMPOSE_ENV_FILES[@]}"
assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES[0]" ".env.legacy" "${XCIND_COMPOSE_ENV_FILES[0]}"
assert_contains "BC shim emits deprecation warning" "deprecated" "$bc_stderr"

rm -rf "$BC_APP"
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ENV_FILES

# ======================================================================
echo ""
echo "=== Test: __xcind-load-config + full resolution ==="

cat >"$MOCK_APP/.xcind.sh" <<'EOF'
XCIND_COMPOSE_DIR="docker"
XCIND_COMPOSE_FILES=(
    "compose.yaml"
    "compose.common.yaml"
    "compose.dev.yaml"
)
XCIND_COMPOSE_ENV_FILES=(
    ".env"
    ".env.local"
)
XCIND_BAKE_FILES=()
EOF

__xcind-load-config "$MOCK_APP"

assert_eq "loads XCIND_COMPOSE_DIR" "docker" "$XCIND_COMPOSE_DIR"
assert_eq "loads 3 compose files" "3" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "loads 2 env files" "2" "${#XCIND_COMPOSE_ENV_FILES[@]}"

# Test full compose opts build
__xcind-build-compose-opts "$MOCK_APP"
opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"

assert_contains "opts include --env-file" "--env-file" "$opts"
assert_contains "opts include -f" "-f" "$opts"
assert_contains "opts include --project-directory" "--project-directory" "$opts"
assert_contains "opts include compose.override.yaml" "compose.override.yaml" "$opts"

# ======================================================================
echo ""
echo "=== Test: JSON output ==="

if command -v jq &>/dev/null; then
  json=$(__xcind-resolve-json "$MOCK_APP")

  json_root=$(echo "$json" | jq -r '.appRoot')
  assert_eq "JSON appRoot" "$MOCK_APP" "$json_root"

  json_compose_count=$(echo "$json" | jq '.composeFiles | length')
  # compose.yaml + compose.override.yaml + compose.common.yaml + compose.dev.yaml + compose.dev.override.yaml = 5
  assert_eq "JSON compose file count" "5" "$json_compose_count"

  json_compose_env_count=$(echo "$json" | jq '.composeEnvFiles | length')
  # .env + .env.local = 2 (no overrides exist)
  assert_eq "JSON composeEnvFiles count" "2" "$json_compose_env_count"

  json_app_env_count=$(echo "$json" | jq '.appEnvFiles | length')
  # XCIND_APP_ENV_FILES defaults to empty
  assert_eq "JSON appEnvFiles count" "0" "$json_app_env_count"
else
  echo "  (skipped: jq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: __xcind-dump-docker-compose-wrapper ==="

WRAPPER_APP=$(mktemp -d)
echo '# test' >"$WRAPPER_APP/.xcind.sh"

compose_wrapper=$(__xcind-dump-docker-compose-wrapper "$WRAPPER_APP" "/usr/local/bin")

assert_contains "compose wrapper has shebang" \
  "#!/bin/sh" "$compose_wrapper"

assert_contains "compose wrapper has set -eu" \
  "set -eu" "$compose_wrapper"

assert_not_contains "compose wrapper has no pipefail (POSIX)" \
  "pipefail" "$compose_wrapper"

assert_contains "compose wrapper adds xcind bin to PATH" \
  'PATH="$PATH:/usr/local/bin"' "$compose_wrapper"

assert_contains "compose wrapper exports XCIND_APP_ROOT" \
  "export XCIND_APP_ROOT=\"${WRAPPER_APP}\"" "$compose_wrapper"

assert_contains "compose wrapper calls xcind-compose" \
  'xcind-compose "$@"' "$compose_wrapper"

assert_contains "compose wrapper falls back to docker compose" \
  'docker compose "$@"' "$compose_wrapper"

# ======================================================================
echo ""
echo "=== Test: __xcind-dump-docker-wrapper ==="

docker_wrapper=$(__xcind-dump-docker-wrapper "$WRAPPER_APP" "/home/testuser/.nix-profile/bin")

assert_contains "docker wrapper has shebang" \
  "#!/bin/sh" "$docker_wrapper"

assert_contains "docker wrapper has set -eu" \
  "set -eu" "$docker_wrapper"

assert_not_contains "docker wrapper has no pipefail (POSIX)" \
  "pipefail" "$docker_wrapper"

assert_contains "docker wrapper adds xcind bin to PATH" \
  'PATH="$PATH:/home/testuser/.nix-profile/bin"' "$docker_wrapper"

assert_contains "docker wrapper exports XCIND_APP_ROOT" \
  "export XCIND_APP_ROOT=\"${WRAPPER_APP}\"" "$docker_wrapper"

assert_contains "docker wrapper checks for compose subcommand" \
  '[ "$1" = "compose" ]' "$docker_wrapper"

assert_contains "docker wrapper calls xcind-compose for compose" \
  'xcind-compose "$@"' "$docker_wrapper"

assert_contains "docker wrapper falls back to docker compose" \
  'docker compose "$@"' "$docker_wrapper"

assert_contains "docker wrapper passes non-compose to docker" \
  'docker "$@"' "$docker_wrapper"

assert_contains "compose wrapper strips -f/--file args" \
  '_xcind_newargs' "$compose_wrapper"

assert_contains "docker wrapper strips -f/--file args" \
  '_xcind_newargs' "$docker_wrapper"

assert_contains "compose wrapper handles -f with space" \
  '-f|--file) shift' "$compose_wrapper"

assert_contains "compose wrapper handles --file=value" \
  '--file=*) shift' "$compose_wrapper"

rm -rf "$WRAPPER_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-discover-workspace ==="

# Set up workspace layout: workspace/app/
WS_ROOT=$(mktemp -d)
mkdir -p "$WS_ROOT/myworkspace/myapp"
echo 'XCIND_IS_WORKSPACE=1' >"$WS_ROOT/myworkspace/.xcind.sh"
echo '# app config' >"$WS_ROOT/myworkspace/myapp/.xcind.sh"

# Test: workspace discovered from parent .xcind.sh
unset XCIND_APP_ROOT XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS XCIND_IS_WORKSPACE
__xcind-discover-workspace "$WS_ROOT/myworkspace/myapp"
assert_eq "workspace discovered - XCIND_WORKSPACE" "myworkspace" "${XCIND_WORKSPACE:-}"
assert_eq "workspace discovered - XCIND_WORKSPACE_ROOT" "$WS_ROOT/myworkspace" "${XCIND_WORKSPACE_ROOT:-}"
assert_eq "workspace discovered - XCIND_WORKSPACELESS" "0" "${XCIND_WORKSPACELESS:-}"

# Test: parent .xcind.sh without XCIND_IS_WORKSPACE=1 is not treated as workspace
NON_WS_PARENT=$(mktemp -d)
mkdir -p "$NON_WS_PARENT/someapp"
echo '# non-workspace config' >"$NON_WS_PARENT/.xcind.sh"
echo '# app config' >"$NON_WS_PARENT/someapp/.xcind.sh"
unset XCIND_APP_ROOT XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS XCIND_IS_WORKSPACE
__xcind-discover-workspace "$NON_WS_PARENT/someapp"
assert_eq "non-workspace parent - XCIND_WORKSPACELESS" "1" "${XCIND_WORKSPACELESS:-}"
assert_eq "non-workspace parent - XCIND_WORKSPACE empty" "" "${XCIND_WORKSPACE:-}"
assert_eq "non-workspace parent - XCIND_WORKSPACE_ROOT empty" "" "${XCIND_WORKSPACE_ROOT:-}"
rm -rf "$NON_WS_PARENT"

# Test: no workspace when parent has no .xcind.sh
STANDALONE_APP=$(mktemp -d)
echo '# standalone app' >"$STANDALONE_APP/.xcind.sh"
unset XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS XCIND_IS_WORKSPACE
__xcind-discover-workspace "$STANDALONE_APP"
assert_eq "no workspace - XCIND_WORKSPACELESS" "1" "${XCIND_WORKSPACELESS:-}"
assert_eq "no workspace - XCIND_WORKSPACE empty" "" "${XCIND_WORKSPACE:-}"
assert_eq "no workspace - XCIND_WORKSPACE_ROOT empty" "" "${XCIND_WORKSPACE_ROOT:-}"

# Test: __xcind-app-root skips XCIND_IS_WORKSPACE=1 dirs
unset XCIND_APP_ROOT XCIND_IS_WORKSPACE
result=$(__xcind-app-root "$WS_ROOT/myworkspace/myapp")
assert_eq "app-root skips workspace dir" "$WS_ROOT/myworkspace/myapp" "$result"

# Test: __xcind-app-root from within workspace root fails (no app .xcind.sh above)
unset XCIND_APP_ROOT XCIND_IS_WORKSPACE
result=$(__xcind-app-root "$WS_ROOT/myworkspace" 2>/dev/null) && status=0 || status=$?
assert_eq "app-root from workspace root fails" "1" "$status"

rm -rf "$WS_ROOT" "$STANDALONE_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-late-bind-workspace ==="

# Test: late-bind when app sets XCIND_WORKSPACE
unset XCIND_WORKSPACE_ROOT
XCIND_WORKSPACELESS=1
XCIND_WORKSPACE="myws"
XCIND_APP_ROOT="/tmp/test-app"
__xcind-late-bind-workspace
assert_eq "late-bind flips XCIND_WORKSPACELESS" "0" "$XCIND_WORKSPACELESS"
assert_eq "late-bind sets XCIND_WORKSPACE_ROOT" "/tmp/test-app" "$XCIND_WORKSPACE_ROOT"

# Test: no late-bind when already in workspace mode
XCIND_WORKSPACELESS=0
XCIND_WORKSPACE="already"
XCIND_WORKSPACE_ROOT="/already/set"
__xcind-late-bind-workspace
assert_eq "no late-bind when already workspace" "/already/set" "$XCIND_WORKSPACE_ROOT"

# Test: no late-bind when XCIND_WORKSPACE empty
XCIND_WORKSPACELESS=1
XCIND_WORKSPACE=""
__xcind-late-bind-workspace
assert_eq "no late-bind when workspace empty" "1" "$XCIND_WORKSPACELESS"

# ======================================================================
echo ""
echo "=== Test: __xcind-resolve-app ==="

unset XCIND_APP
__xcind-resolve-app "/path/to/myapp"
assert_eq "resolve-app defaults to basename" "myapp" "$XCIND_APP"

XCIND_APP="custom-name"
__xcind-resolve-app "/path/to/myapp"
assert_eq "resolve-app preserves explicit" "custom-name" "$XCIND_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-resolve-url-templates ==="

# Workspaceless mode
unset XCIND_APP_URL_TEMPLATE XCIND_ROUTER_TEMPLATE XCIND_WORKSPACE_SERVICE_TEMPLATE
unset XCIND_WORKSPACELESS_APP_URL_TEMPLATE XCIND_WORKSPACE_APP_URL_TEMPLATE
unset XCIND_WORKSPACELESS_ROUTER_TEMPLATE XCIND_WORKSPACE_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=1
__xcind-resolve-url-templates
assert_eq "workspaceless URL template" "{app}-{export}.{domain}" "$XCIND_APP_URL_TEMPLATE"
assert_eq "workspaceless router template" "{app}-{export}-{protocol}" "$XCIND_ROUTER_TEMPLATE"
assert_eq "default service template" "{app}-{service}" "$XCIND_WORKSPACE_SERVICE_TEMPLATE"

# Workspace mode
unset XCIND_APP_URL_TEMPLATE XCIND_ROUTER_TEMPLATE XCIND_WORKSPACE_SERVICE_TEMPLATE
XCIND_WORKSPACELESS=0
__xcind-resolve-url-templates
assert_eq "workspace URL template" "{workspace}-{app}-{export}.{domain}" "$XCIND_APP_URL_TEMPLATE"
assert_eq "workspace router template" "{workspace}-{app}-{export}-{protocol}" "$XCIND_ROUTER_TEMPLATE"

# Custom templates
unset XCIND_APP_URL_TEMPLATE XCIND_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=1
XCIND_WORKSPACELESS_APP_URL_TEMPLATE="{export}.{app}.{domain}"
__xcind-resolve-url-templates
assert_eq "custom workspaceless URL template" "{export}.{app}.{domain}" "$XCIND_APP_URL_TEMPLATE"
unset XCIND_WORKSPACELESS_APP_URL_TEMPLATE

# Apex template defaults — workspaceless
unset XCIND_APP_APEX_URL_TEMPLATE XCIND_APEX_ROUTER_TEMPLATE
unset XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE
unset XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=1
__xcind-resolve-url-templates
assert_eq "workspaceless apex URL template" "{app}.{domain}" "$XCIND_APP_APEX_URL_TEMPLATE"
assert_eq "workspaceless apex router template" "{app}-{protocol}" "$XCIND_APEX_ROUTER_TEMPLATE"

# Apex template defaults — workspace
unset XCIND_APP_APEX_URL_TEMPLATE XCIND_APEX_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=0
__xcind-resolve-url-templates
assert_eq "workspace apex URL template" "{workspace}-{app}.{domain}" "$XCIND_APP_APEX_URL_TEMPLATE"
assert_eq "workspace apex router template" "{workspace}-{app}-{protocol}" "$XCIND_APEX_ROUTER_TEMPLATE"

# Apex custom template
unset XCIND_APP_APEX_URL_TEMPLATE XCIND_APEX_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=1
XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE="{app}.custom.{domain}"
__xcind-resolve-url-templates
assert_eq "custom apex URL template" "{app}.custom.{domain}" "$XCIND_APP_APEX_URL_TEMPLATE"
unset XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE

# Apex opt-out — empty string disables apex
unset XCIND_APP_APEX_URL_TEMPLATE XCIND_APEX_ROUTER_TEMPLATE
XCIND_WORKSPACELESS=1
XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=""
XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE=""
__xcind-resolve-url-templates
assert_eq "apex URL opt-out (empty string)" "" "$XCIND_APP_APEX_URL_TEMPLATE"
assert_eq "apex router opt-out (empty string)" "" "$XCIND_APEX_ROUTER_TEMPLATE"
unset XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE

# ======================================================================
echo ""
echo "=== Test: __xcind-compute-sha ==="

SHA_APP=$(mktemp -d)
echo '# sha test config' >"$SHA_APP/.xcind.sh"
mkdir -p "$SHA_APP/docker"
echo 'version: "3"' >"$SHA_APP/docker/compose.yaml"
touch "$SHA_APP/.env"

# Build opts so SHA has compose files to hash
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES
__xcind-load-config "$SHA_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_COMPOSE_DIR="docker"
__xcind-build-compose-opts "$SHA_APP"

XCIND_WORKSPACELESS=1
XCIND_WORKSPACE_ROOT=""
sha1=$(__xcind-compute-sha "$SHA_APP")

# Same inputs = same SHA
sha2=$(__xcind-compute-sha "$SHA_APP")
assert_eq "SHA stable on no change" "$sha1" "$sha2"

# Change content = different SHA
echo 'version: "3.8"' >"$SHA_APP/docker/compose.yaml"
sha3=$(__xcind-compute-sha "$SHA_APP")
if [ "$sha1" != "$sha3" ]; then
  echo "  ✓ SHA invalidates on content change"
  PASS=$((PASS + 1))
else
  echo "  ✗ SHA invalidates on content change"
  FAIL=$((FAIL + 1))
fi

rm -rf "$SHA_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-run-hooks (stub) ==="

HOOK_APP=$(mktemp -d)
echo '# hook test' >"$HOOK_APP/.xcind.sh"
touch "$HOOK_APP/compose.yaml"

# Set up pipeline vars
export XCIND_SHA="testhash123"
export XCIND_CACHE_DIR="$HOOK_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$HOOK_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

# Create a stub hook function
stub_hook() {
  echo "-f $XCIND_GENERATED_DIR/compose.stub.yaml"
  touch "$XCIND_GENERATED_DIR/compose.stub.yaml"
}
XCIND_HOOKS_POST_RESOLVE_GENERATE=("stub_hook")

# Build base opts
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES
__xcind-load-config "$HOOK_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$HOOK_APP"

# Cache miss — should run hook
__xcind-run-hooks "$HOOK_APP"
opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"
assert_contains "hook output appended (cache miss)" "compose.stub.yaml" "$opts"

# Verify hook output persisted
assert_eq "hook output file exists" "true" "$([ -f "$XCIND_GENERATED_DIR/.hook-output-stub_hook" ] && echo true || echo false)"

# Cache hit — replay without re-running hook
__xcind-build-compose-opts "$HOOK_APP"
__xcind-run-hooks "$HOOK_APP"
opts2="${XCIND_DOCKER_COMPOSE_OPTS[*]}"
assert_contains "hook output replayed (cache hit)" "compose.stub.yaml" "$opts2"

# ======================================================================
echo ""
echo "=== Test: __xcind-run-hooks ordering (cache hit preserves XCIND_HOOKS_POST_RESOLVE_GENERATE order) ==="

ORDER_APP=$(mktemp -d)
echo '# order test' >"$ORDER_APP/.xcind.sh"
touch "$ORDER_APP/compose.yaml"

export XCIND_SHA="orderhash456"
export XCIND_CACHE_DIR="$ORDER_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$ORDER_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

hook_alpha() {
  echo "-f $XCIND_GENERATED_DIR/compose.alpha.yaml"
  touch "$XCIND_GENERATED_DIR/compose.alpha.yaml"
}
hook_beta() {
  echo "-f $XCIND_GENERATED_DIR/compose.beta.yaml"
  touch "$XCIND_GENERATED_DIR/compose.beta.yaml"
}
# Register beta before alpha to verify order is preserved (not lexicographic)
XCIND_HOOKS_POST_RESOLVE_GENERATE=("hook_beta" "hook_alpha")

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES
__xcind-load-config "$ORDER_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$ORDER_APP"

# Cache miss — populate generated dir
__xcind-run-hooks "$ORDER_APP"
miss_opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"

# Determine positions of beta and alpha in cache-miss output
beta_pos_miss=$(echo "$miss_opts" | tr ' ' '\n' | grep -n "compose.beta.yaml" | cut -d: -f1)
alpha_pos_miss=$(echo "$miss_opts" | tr ' ' '\n' | grep -n "compose.alpha.yaml" | cut -d: -f1)
assert_eq "cache miss: hook_beta before hook_alpha" "true" "$([ "$beta_pos_miss" -lt "$alpha_pos_miss" ] && echo true || echo false)"

# Cache hit — replay
__xcind-build-compose-opts "$ORDER_APP"
__xcind-run-hooks "$ORDER_APP"
hit_opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"

beta_pos_hit=$(echo "$hit_opts" | tr ' ' '\n' | grep -n "compose.beta.yaml" | cut -d: -f1)
alpha_pos_hit=$(echo "$hit_opts" | tr ' ' '\n' | grep -n "compose.alpha.yaml" | cut -d: -f1)
assert_eq "cache hit: hook_beta before hook_alpha (order preserved)" "true" "$([ "$beta_pos_hit" -lt "$alpha_pos_hit" ] && echo true || echo false)"

rm -rf "$ORDER_APP"

rm -rf "$HOOK_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-render-template (hostname generation) ==="

hostname=$(__xcind-render-template "{app}-{export}.{domain}" app "myapp" export "web" domain "localhost")
assert_eq "workspaceless hostname" "myapp-web.localhost" "$hostname"

hostname_ws=$(__xcind-render-template "{workspace}-{app}-{export}.{domain}" workspace "dev" app "myapp" export "web" domain "localhost")
assert_eq "workspace hostname" "dev-myapp-web.localhost" "$hostname_ws"

router=$(__xcind-render-template "{app}-{export}-{protocol}" app "myapp" export "api" protocol "http")
assert_eq "router name" "myapp-api-http" "$router"

# ======================================================================
echo ""
echo "=== Test: __xcind-source-additional-configs ==="

ADDCFG_APP=$(mktemp -d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$ADDCFG_APP/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_PROXY_EXPORTS=("nginx")
EOF

cat >"$ADDCFG_APP/.xcind.dev.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml" "compose.dev.yaml")
EOF

cat >"$ADDCFG_APP/.xcind.dev.override.sh" <<'EOF'
XCIND_PROXY_EXPORTS=("nginx" "mailhog")
EOF

# Load config then source additional configs
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
__xcind-load-config "$ADDCFG_APP"

assert_eq "base config sets XCIND_PROXY_EXPORTS" "nginx" "${XCIND_PROXY_EXPORTS[0]}"
assert_eq "base config XCIND_ADDITIONAL_CONFIG_FILES count" "1" "${#XCIND_ADDITIONAL_CONFIG_FILES[@]}"

__xcind-source-additional-configs "$ADDCFG_APP"

assert_eq "additional config overrides compose files count" "2" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "additional config compose[0]" "compose.yaml" "${XCIND_COMPOSE_FILES[0]}"
assert_eq "additional config compose[1]" "compose.dev.yaml" "${XCIND_COMPOSE_FILES[1]}"
assert_eq "override adds mailhog" "mailhog" "${XCIND_PROXY_EXPORTS[1]}"

# Check tracking array (app .xcind.sh + .xcind.dev.sh + .xcind.dev.override.sh = 3)
assert_eq "sourced config files count" "3" "${#__XCIND_SOURCED_CONFIG_FILES[@]}"
assert_eq "sourced[0] is app .xcind.sh" "$ADDCFG_APP/.xcind.sh" "${__XCIND_SOURCED_CONFIG_FILES[0]}"
assert_eq "sourced[1] is .xcind.dev.sh" "$ADDCFG_APP/.xcind.dev.sh" "${__XCIND_SOURCED_CONFIG_FILES[1]}"
assert_eq "sourced[2] is .xcind.dev.override.sh" "$ADDCFG_APP/.xcind.dev.override.sh" "${__XCIND_SOURCED_CONFIG_FILES[2]}"

rm -rf "$ADDCFG_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-source-additional-configs with variable expansion ==="

VAREXP_APP=$(mktemp -d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$VAREXP_APP/.xcind.sh" <<'XCEOF'
XCIND_ADDITIONAL_CONFIG_FILES=('.xcind.${APP_ENV:-dev}.sh')
XCEOF

cat >"$VAREXP_APP/.xcind.staging.sh" <<'EOF'
XCIND_STAGING_LOADED=1
EOF

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
export APP_ENV="staging"
__xcind-load-config "$VAREXP_APP"
__xcind-source-additional-configs "$VAREXP_APP"

assert_eq "variable expansion resolves staging" "1" "${XCIND_STAGING_LOADED:-0}"

# Non-existent file is skipped silently
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES XCIND_STAGING_LOADED
__XCIND_SOURCED_CONFIG_FILES=()
export APP_ENV="prod"
__xcind-load-config "$VAREXP_APP"
__xcind-source-additional-configs "$VAREXP_APP"

assert_eq "missing additional config skipped" "0" "${XCIND_STAGING_LOADED:-0}"
# Only app .xcind.sh was sourced (prod config doesn't exist)
assert_eq "only base config sourced for missing" "1" "${#__XCIND_SOURCED_CONFIG_FILES[@]}"

unset APP_ENV XCIND_STAGING_LOADED
rm -rf "$VAREXP_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-source-additional-configs with empty array ==="

EMPTY_APP=$(mktemp -d)
__XCIND_SOURCED_CONFIG_FILES=()
echo '# no additional configs' >"$EMPTY_APP/.xcind.sh"

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
__xcind-load-config "$EMPTY_APP"
__xcind-source-additional-configs "$EMPTY_APP"

assert_eq "empty additional configs — default count" "0" "${#XCIND_ADDITIONAL_CONFIG_FILES[@]}"
assert_eq "empty additional configs — only base sourced" "1" "${#__XCIND_SOURCED_CONFIG_FILES[@]}"

rm -rf "$EMPTY_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-source-additional-configs with unset variable ==="

__XCIND_SOURCED_CONFIG_FILES=()
WS_UNSET_ROOT=$(mktemp -d)
mkdir -p "$WS_UNSET_ROOT/myworkspace/myapp"

# Workspace only sets XCIND_IS_WORKSPACE, no XCIND_ADDITIONAL_CONFIG_FILES
echo 'XCIND_IS_WORKSPACE=1' >"$WS_UNSET_ROOT/myworkspace/.xcind.sh"
# App .xcind.sh is empty (no XCIND_ADDITIONAL_CONFIG_FILES set)
echo '# nothing' >"$WS_UNSET_ROOT/myworkspace/myapp/.xcind.sh"

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
XCIND_APP_ROOT=""
app_root=$(__xcind-app-root "$WS_UNSET_ROOT/myworkspace/myapp")
__xcind-discover-workspace "$app_root"

# This should NOT fail with "unbound variable" when XCIND_ADDITIONAL_CONFIG_FILES is unset
__xcind-source-additional-configs "$XCIND_WORKSPACE_ROOT"

__xcind-load-config "$app_root"
__xcind-source-additional-configs "$app_root"

assert_eq "unset additional configs — no error" "0" "${#XCIND_ADDITIONAL_CONFIG_FILES[@]}"

rm -rf "$WS_UNSET_ROOT"

# ======================================================================
echo ""
echo "=== Test: Workspace additional configs with inheritance ==="

WS_ADD_ROOT=$(mktemp -d)
mkdir -p "$WS_ADD_ROOT/myworkspace/myapp"
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$WS_ADD_ROOT/myworkspace/.xcind.sh" <<'EOF'
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
EOF

cat >"$WS_ADD_ROOT/myworkspace/.xcind.dev.sh" <<'EOF'
XCIND_PROXY_DOMAIN="dev.localhost"
EOF

cat >"$WS_ADD_ROOT/myworkspace/myapp/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_PROXY_EXPORTS=("web")
EOF

cat >"$WS_ADD_ROOT/myworkspace/myapp/.xcind.dev.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml" "compose.dev.yaml")
EOF

# Simulate the pipeline
unset XCIND_APP_ROOT XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS XCIND_IS_WORKSPACE
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES

__xcind-discover-workspace "$WS_ADD_ROOT/myworkspace/myapp"
assert_eq "workspace inherited - XCIND_WORKSPACELESS" "0" "${XCIND_WORKSPACELESS:-}"

# Source workspace additional configs
__xcind-source-additional-configs "$XCIND_WORKSPACE_ROOT"
assert_eq "workspace additional overrides proxy domain" "dev.localhost" "${XCIND_PROXY_DOMAIN:-}"

# Load app config (inherits XCIND_ADDITIONAL_CONFIG_FILES from workspace)
__xcind-load-config "$WS_ADD_ROOT/myworkspace/myapp"
assert_eq "app inherits additional config pattern" "1" "${#XCIND_ADDITIONAL_CONFIG_FILES[@]}"

# Source app additional configs (resolved relative to app root)
__xcind-source-additional-configs "$WS_ADD_ROOT/myworkspace/myapp"
assert_eq "app additional overrides compose files" "2" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "app additional compose[1]" "compose.dev.yaml" "${XCIND_COMPOSE_FILES[1]}"

# Verify full sourcing order in tracking array:
# 1. workspace/.xcind.sh, 2. workspace/.xcind.dev.sh, 3. app/.xcind.sh, 4. app/.xcind.dev.sh
assert_eq "full chain count" "4" "${#__XCIND_SOURCED_CONFIG_FILES[@]}"
assert_eq "chain[0] workspace .xcind.sh" "$WS_ADD_ROOT/myworkspace/.xcind.sh" "${__XCIND_SOURCED_CONFIG_FILES[0]}"
assert_eq "chain[1] workspace .xcind.dev.sh" "$WS_ADD_ROOT/myworkspace/.xcind.dev.sh" "${__XCIND_SOURCED_CONFIG_FILES[1]}"
assert_eq "chain[2] app .xcind.sh" "$WS_ADD_ROOT/myworkspace/myapp/.xcind.sh" "${__XCIND_SOURCED_CONFIG_FILES[2]}"
assert_eq "chain[3] app .xcind.dev.sh" "$WS_ADD_ROOT/myworkspace/myapp/.xcind.dev.sh" "${__XCIND_SOURCED_CONFIG_FILES[3]}"

rm -rf "$WS_ADD_ROOT"

# ======================================================================
echo ""
echo "=== Test: App overrides workspace XCIND_ADDITIONAL_CONFIG_FILES ==="

WS_OVR_ROOT=$(mktemp -d)
mkdir -p "$WS_OVR_ROOT/myworkspace/myapp"
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$WS_OVR_ROOT/myworkspace/.xcind.sh" <<'EOF'
XCIND_IS_WORKSPACE=1
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
EOF

cat >"$WS_OVR_ROOT/myworkspace/myapp/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.local.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
EOF

cat >"$WS_OVR_ROOT/myworkspace/myapp/.xcind.local.sh" <<'EOF'
XCIND_LOCAL_LOADED=1
EOF

unset XCIND_APP_ROOT XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS XCIND_IS_WORKSPACE
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES XCIND_LOCAL_LOADED

__xcind-discover-workspace "$WS_OVR_ROOT/myworkspace/myapp"

# Workspace additional configs (dev doesn't exist in workspace, skipped)
__xcind-source-additional-configs "$XCIND_WORKSPACE_ROOT"

# App config overrides XCIND_ADDITIONAL_CONFIG_FILES
__xcind-load-config "$WS_OVR_ROOT/myworkspace/myapp"
assert_eq "app overrides additional config pattern" ".xcind.local.sh" "${XCIND_ADDITIONAL_CONFIG_FILES[0]}"

# App additional configs use the overridden pattern
__xcind-source-additional-configs "$WS_OVR_ROOT/myworkspace/myapp"
assert_eq "app sources .xcind.local.sh" "1" "${XCIND_LOCAL_LOADED:-0}"

unset XCIND_LOCAL_LOADED
rm -rf "$WS_OVR_ROOT"

# ======================================================================
echo ""
echo "=== Test: SHA includes additional config hashes ==="

SHA_ADD_APP=$(mktemp -d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$SHA_ADD_APP/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
echo 'version: "3"' >"$SHA_ADD_APP/compose.yaml"
echo 'XCIND_DEV_VAR=original' >"$SHA_ADD_APP/.xcind.dev.sh"

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
__xcind-load-config "$SHA_ADD_APP"
__xcind-source-additional-configs "$SHA_ADD_APP"
__xcind-build-compose-opts "$SHA_ADD_APP"
XCIND_WORKSPACELESS=1
XCIND_WORKSPACE_ROOT=""

sha_before=$(__xcind-compute-sha "$SHA_ADD_APP")

# Change additional config content
echo 'XCIND_DEV_VAR=changed' >"$SHA_ADD_APP/.xcind.dev.sh"
sha_after=$(__xcind-compute-sha "$SHA_ADD_APP")

if [ "$sha_before" != "$sha_after" ]; then
  echo "  ✓ SHA invalidates on additional config change"
  PASS=$((PASS + 1))
else
  echo "  ✗ SHA invalidates on additional config change"
  FAIL=$((FAIL + 1))
fi

rm -rf "$SHA_ADD_APP"

# ======================================================================
echo ""
echo "=== Test: JSON output includes configFiles and metadata ==="

if command -v jq &>/dev/null; then
  JSON_APP=$(mktemp -d)
  __XCIND_SOURCED_CONFIG_FILES=()

  cat >"$JSON_APP/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
  touch "$JSON_APP/compose.yaml"
  echo '# dev config' >"$JSON_APP/.xcind.dev.sh"

  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_ADDITIONAL_CONFIG_FILES
  XCIND_WORKSPACELESS=1
  XCIND_WORKSPACE=""
  XCIND_APP="testapp"
  XCIND_DOCKER_COMPOSE_OPTS=()

  __xcind-load-config "$JSON_APP"
  __xcind-source-additional-configs "$JSON_APP"
  __xcind-build-compose-opts "$JSON_APP"

  json=$(__xcind-resolve-json "$JSON_APP")

  json_config_count=$(echo "$json" | jq '.configFiles | length')
  assert_eq "JSON configFiles count" "2" "$json_config_count"

  json_config_0=$(echo "$json" | jq -r '.configFiles[0]')
  assert_eq "JSON configFiles[0] is .xcind.sh" "$JSON_APP/.xcind.sh" "$json_config_0"

  json_config_1=$(echo "$json" | jq -r '.configFiles[1]')
  assert_eq "JSON configFiles[1] is .xcind.dev.sh" "$JSON_APP/.xcind.dev.sh" "$json_config_1"

  json_app=$(echo "$json" | jq -r '.metadata.app')
  assert_eq "JSON metadata.app" "testapp" "$json_app"

  json_workspaceless=$(echo "$json" | jq -r '.metadata.workspaceless')
  assert_eq "JSON metadata.workspaceless" "true" "$json_workspaceless"

  json_workspace=$(echo "$json" | jq -r '.metadata.workspace')
  assert_eq "JSON metadata.workspace is null" "null" "$json_workspace"

  rm -rf "$JSON_APP"

  # Test workspace metadata
  JSON_WS=$(mktemp -d)
  __XCIND_SOURCED_CONFIG_FILES=("$JSON_WS/.xcind.sh")
  XCIND_WORKSPACELESS=0
  XCIND_WORKSPACE="myws"
  XCIND_APP="myapp"
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_COMPOSE_FILES=()
  XCIND_COMPOSE_ENV_FILES=()
  XCIND_BAKE_FILES=()
  XCIND_COMPOSE_DIR=""

  json_ws=$(__xcind-resolve-json "$JSON_WS")

  json_ws_name=$(echo "$json_ws" | jq -r '.metadata.workspace')
  assert_eq "JSON workspace metadata.workspace" "myws" "$json_ws_name"

  json_ws_wl=$(echo "$json_ws" | jq -r '.metadata.workspaceless')
  assert_eq "JSON workspace metadata.workspaceless" "false" "$json_ws_wl"

  rm -rf "$JSON_WS"
else
  echo "  (skipped: jq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-app-env-hook (no-op when XCIND_APP_ENV_FILES unset) ==="

APPENV_NOOP=$(mktemp -d)
export XCIND_SHA="appenvnoop"
export XCIND_CACHE_DIR="$APPENV_NOOP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$APPENV_NOOP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

unset XCIND_APP_ENV_FILES
hook_output=$(xcind-app-env-hook "$APPENV_NOOP")
assert_eq "hook no-op when unset: no output" "" "$hook_output"
assert_eq "hook no-op when unset: no file generated" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.app-env.yaml" ] && echo true || echo false)"

XCIND_APP_ENV_FILES=()
hook_output=$(xcind-app-env-hook "$APPENV_NOOP")
assert_eq "hook no-op when empty array: no output" "" "$hook_output"
assert_eq "hook no-op when empty array: no file generated" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.app-env.yaml" ] && echo true || echo false)"

# XCIND_APP_ENV_FILES set to a non-existent file — resolves to nothing
XCIND_APP_ENV_FILES=(".nonexistent-env-file-xcind-test")
hook_output=$(xcind-app-env-hook "$APPENV_NOOP")
assert_eq "hook no-op when no files resolve: no output" "" "$hook_output"
assert_eq "hook no-op when no files resolve: no file generated" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.app-env.yaml" ] && echo true || echo false)"

rm -rf "$APPENV_NOOP"

# ======================================================================
echo ""
echo "=== Test: xcind-app-env-hook generates compose.app-env.yaml ==="

if command -v yq &>/dev/null; then
  APPENV_APP=$(mktemp -d)
  export XCIND_SHA="appenvhash"
  export XCIND_CACHE_DIR="$APPENV_APP/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$APPENV_APP/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  # Create env files that will be resolved
  echo "DB_URL=postgres://localhost/test" >"$APPENV_APP/.env"
  echo "API_KEY=secret" >"$APPENV_APP/.env.local"

  # Create a minimal resolved-config.yaml with two services
  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
  worker:
    image: alpine
YAML

  XCIND_APP_ENV_FILES=(".env" ".env.local")
  hook_output=$(xcind-app-env-hook "$APPENV_APP")

  # Verify -f flag is returned
  assert_contains "hook returns -f flag" "-f $XCIND_GENERATED_DIR/compose.app-env.yaml" "$hook_output"

  # Verify file was generated
  assert_eq "compose.app-env.yaml was created" "true" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.app-env.yaml" ] && echo true || echo false)"

  generated="$(cat "$XCIND_GENERATED_DIR/compose.app-env.yaml")"

  # Verify both services are present
  assert_contains "generated YAML has web service" "web:" "$generated"
  assert_contains "generated YAML has worker service" "worker:" "$generated"

  # Verify env_file entries use absolute paths
  assert_contains "generated YAML has absolute .env path" "$APPENV_APP/.env" "$generated"
  assert_contains "generated YAML has absolute .env.local path" "$APPENV_APP/.env.local" "$generated"

  # Verify both services include both env files
  web_env_count=$(yq -r '.services.web.env_file | length' "$XCIND_GENERATED_DIR/compose.app-env.yaml")
  assert_eq "web service has 2 env_file entries" "2" "$web_env_count"

  worker_env_count=$(yq -r '.services.worker.env_file | length' "$XCIND_GENERATED_DIR/compose.app-env.yaml")
  assert_eq "worker service has 2 env_file entries" "2" "$worker_env_count"

  # Verify single env file case
  XCIND_APP_ENV_FILES=(".env")
  rm -f "$XCIND_GENERATED_DIR/compose.app-env.yaml"
  hook_output_single=$(xcind-app-env-hook "$APPENV_APP")

  assert_contains "single env file: returns -f flag" "-f $XCIND_GENERATED_DIR/compose.app-env.yaml" "$hook_output_single"

  single_env_count=$(yq -r '.services.web.env_file | length' "$XCIND_GENERATED_DIR/compose.app-env.yaml")
  assert_eq "single env file: web has 1 env_file entry" "1" "$single_env_count"

  rm -rf "$APPENV_APP"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
# Cleanup
rm -rf "$MOCK_APP"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
