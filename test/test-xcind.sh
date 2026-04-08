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

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
__XCIND_SOURCED_CONFIG_FILES=()

bc_stderr_file=$(mktemp)
__xcind-load-config "$BC_APP" 2>"$bc_stderr_file"
bc_stderr=$(<"$bc_stderr_file")
rm "$bc_stderr_file"

assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES count" "1" "${#XCIND_COMPOSE_ENV_FILES[@]}"
assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES[0]" ".env.legacy" "${XCIND_COMPOSE_ENV_FILES[0]}"
assert_contains "BC shim emits deprecation warning" "deprecated" "$bc_stderr"

rm -rf "$BC_APP"
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ENV_FILES

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
export XCIND_WORKSPACELESS_APP_URL_TEMPLATE="{export}.{app}.{domain}"
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
export XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=""
export XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE=""
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
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
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
XCIND_HOOKS_GENERATE=("stub_hook")

# Build base opts
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
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
echo "=== Test: __xcind-run-hooks ordering (cache hit preserves XCIND_HOOKS_GENERATE order) ==="

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
# shellcheck disable=SC2034 # consumed by __xcind-run-hooks
XCIND_HOOKS_GENERATE=("hook_beta" "hook_alpha")

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
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
echo "=== Test: __xcind-run-execute-hooks ==="

EXEC_HOOK_CALLED=""
stub_execute_hook() {
  EXEC_HOOK_CALLED="yes:$1"
}
XCIND_HOOKS_EXECUTE=("stub_execute_hook")

__xcind-run-execute-hooks "/tmp/test-app"
assert_eq "execute hook called with app_root" "yes:/tmp/test-app" "$EXEC_HOOK_CALLED"

# Verify execute hooks always run (no caching)
EXEC_HOOK_COUNT=0
counting_execute_hook() {
  EXEC_HOOK_COUNT=$((EXEC_HOOK_COUNT + 1))
}
XCIND_HOOKS_EXECUTE=("counting_execute_hook")

__xcind-run-execute-hooks "/tmp/test-app"
__xcind-run-execute-hooks "/tmp/test-app"
__xcind-run-execute-hooks "/tmp/test-app"
assert_eq "execute hooks run every invocation (not cached)" "3" "$EXEC_HOOK_COUNT"

# Verify empty hooks array is safe
# shellcheck disable=SC2034 # consumed by __xcind-run-execute-hooks
XCIND_HOOKS_EXECUTE=()
__xcind-run-execute-hooks "/tmp/test-app"
assert_eq "empty execute hooks: no error" "0" "$?"

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
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
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

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
export APP_ENV="staging"
__xcind-load-config "$VAREXP_APP"
__xcind-source-additional-configs "$VAREXP_APP"

assert_eq "variable expansion resolves staging" "1" "${XCIND_STAGING_LOADED:-0}"

# Non-existent file is skipped silently
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES XCIND_STAGING_LOADED
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

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
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

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
export XCIND_APP_ROOT=""
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
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES

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
unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES XCIND_LOCAL_LOADED

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

unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
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

  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS XCIND_ADDITIONAL_CONFIG_FILES
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
echo "=== Test: xcind-naming-hook (workspaceless mode) ==="

NAMING_WL=$(mktemp -d)
export XCIND_SHA="naminghash"
export XCIND_CACHE_DIR="$NAMING_WL/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$NAMING_WL/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

XCIND_APP="myapp"
XCIND_WORKSPACELESS=1
XCIND_WORKSPACE=""

hook_output=$(xcind-naming-hook "$NAMING_WL")

assert_contains "naming hook returns -f flag" "-f $XCIND_GENERATED_DIR/compose.naming.yaml" "$hook_output"
assert_eq "compose.naming.yaml was created" "true" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.naming.yaml" ] && echo true || echo false)"

generated="$(cat "$XCIND_GENERATED_DIR/compose.naming.yaml")"
assert_contains "workspaceless name is app only" "name: myapp" "$generated"

rm -rf "$NAMING_WL"

# ======================================================================
echo ""
echo "=== Test: xcind-naming-hook (workspace mode) ==="

NAMING_WS=$(mktemp -d)
export XCIND_SHA="naminghash2"
export XCIND_CACHE_DIR="$NAMING_WS/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$NAMING_WS/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

XCIND_APP="frontend"
XCIND_WORKSPACELESS=0
XCIND_WORKSPACE="dev"

hook_output=$(xcind-naming-hook "$NAMING_WS")

assert_contains "naming hook returns -f flag" "-f $XCIND_GENERATED_DIR/compose.naming.yaml" "$hook_output"

generated="$(cat "$XCIND_GENERATED_DIR/compose.naming.yaml")"
assert_contains "workspace name is workspace-app" "name: dev-frontend" "$generated"

rm -rf "$NAMING_WS"

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
echo "=== Test: __xcind-check-deps ==="

CDEPS_STUBS=$(mktemp -d)
CDEPS_EMPTY=$(mktemp -d)

# docker stub: handles --version, compose version, and compose version --short
cat >"$CDEPS_STUBS/docker" <<'STUB'
#!/bin/sh
case "$*" in
  "--version")               echo "Docker version 24.0.0, build abc" ;;
  "compose version")         echo "Docker Compose version v2.20.0" ; exit 0 ;;
  "compose version --short") echo "v2.20.0" ; exit 0 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$CDEPS_STUBS/docker"

# bash stub (to give __check_required bash a known version)
printf '#!/bin/sh\necho "GNU bash, version 5.0.0(1)-release"\n' >"$CDEPS_STUBS/bash"
chmod +x "$CDEPS_STUBS/bash"

# sha256sum, jq, yq stubs
printf '#!/bin/sh\necho "sha256sum (GNU coreutils) 9.1.0"\n' >"$CDEPS_STUBS/sha256sum"
printf '#!/bin/sh\necho "jq-1.7"\n' >"$CDEPS_STUBS/jq"
printf '#!/bin/sh\necho "yq version 4.35.0"\n' >"$CDEPS_STUBS/yq"
chmod +x "$CDEPS_STUBS/sha256sum" "$CDEPS_STUBS/jq" "$CDEPS_STUBS/yq"

# 1. All required + optional deps present → returns 0, "All dependencies found."
cdeps_all_out=$(PATH="$CDEPS_STUBS" __xcind-check-deps 2>&1)
cdeps_all_rc=$?
assert_eq "all deps present: returns 0" "0" "$cdeps_all_rc"
assert_contains "all deps present: reports no issues" "All dependencies found." "$cdeps_all_out"

# 2. Optional deps missing but required present → still returns 0, warns about optional
# Remove jq/yq from stubs so they are not found
rm -f "$CDEPS_STUBS/jq" "$CDEPS_STUBS/yq"
cdeps_reqonly_out=$(PATH="$CDEPS_STUBS" __xcind-check-deps 2>&1)
cdeps_reqonly_rc=$?
assert_eq "required-only: returns 0" "0" "$cdeps_reqonly_rc"
assert_not_contains "required-only: no required-missing message" "Required dependencies are missing" "$cdeps_reqonly_out"
assert_contains "required-only: optional-missing warning shown" "Optional dependencies are missing" "$cdeps_reqonly_out"

# 3. Required deps missing → returns non-zero
cdeps_miss_out=$(PATH="$CDEPS_EMPTY" __xcind-check-deps 2>&1) && cdeps_miss_rc=0 || cdeps_miss_rc=$?
assert_eq "required missing: returns 1" "1" "$cdeps_miss_rc"
assert_contains "required missing: required message shown" "Required dependencies are missing" "$cdeps_miss_out"

# 4. Multiple required deps missing → issue count reflects all (not capped at 1)
# Empty PATH: bash, docker, docker compose, sha256sum all missing (4 required) + jq, yq (2 optional) = 6 issues
cdeps_count_str=$(echo "$cdeps_miss_out" | grep "issue(s) found" | sed 's/ .*//')
cdeps_count=${cdeps_count_str:-0}
if [ "${cdeps_count}" -gt 1 ] 2>/dev/null; then
  echo "  ✓ multiple required missing: issue count is $cdeps_count (> 1)"
  PASS=$((PASS + 1))
else
  echo "  ✗ multiple required missing: expected count > 1, got '${cdeps_count}'"
  FAIL=$((FAIL + 1))
fi

rm -rf "$CDEPS_STUBS" "$CDEPS_EMPTY"

# ======================================================================
echo ""
echo "=== Test: --generate-docker-compose-configuration ==="

if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then

  GCC_TEST_APP=$(mktemp -d)
  cat >"$GCC_TEST_APP/.xcind.sh" <<'XCINDEOF'
XCIND_COMPOSE_FILES=(compose.yaml)
XCIND_COMPOSE_ENV_FILES=()
XCINDEOF
  cat >"$GCC_TEST_APP/compose.yaml" <<'COMPEOF'
services:
  app:
    image: alpine
COMPEOF

  # 1. --generate-docker-compose-configuration=FILE generates the file
  GCC_OUT_FILE=$(mktemp -d)/compose.xcind.yaml
  (cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration="$GCC_OUT_FILE") && gcc_rc=0 || gcc_rc=$?
  assert_eq "generate-docker-compose-configuration: exit code 0" "0" "$gcc_rc"
  assert_eq "generate-docker-compose-configuration: file exists" "true" \
    "$([ -f "$GCC_OUT_FILE" ] && echo true || echo false)"
  gcc_yaml_content=$(cat "$GCC_OUT_FILE" 2>/dev/null || true)
  assert_contains "generate-docker-compose-configuration: contains services key" "services:" "$gcc_yaml_content"
  rm -rf "$(dirname "$GCC_OUT_FILE")"

  # 2. --generate-docker-compose-configuration FILE (space-separated) works identically
  GCC_OUT_FILE2=$(mktemp -d)/compose.xcind.yaml
  (cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration "$GCC_OUT_FILE2") && gcc_rc=0 || gcc_rc=$?
  assert_eq "generate-docker-compose-configuration space form: exit code 0" "0" "$gcc_rc"
  assert_eq "generate-docker-compose-configuration space form: file exists" "true" \
    "$([ -f "$GCC_OUT_FILE2" ] && echo true || echo false)"
  rm -rf "$(dirname "$GCC_OUT_FILE2")"

  # 3. --generate-docker-compose-configuration fails gracefully on bad config
  GCC_BAD_APP=$(mktemp -d)
  cat >"$GCC_BAD_APP/.xcind.sh" <<'XCINDEOF'
XCIND_COMPOSE_FILES=(nonexistent.yaml)
XCIND_COMPOSE_ENV_FILES=()
XCINDEOF
  GCC_BAD_OUT=$(mktemp -d)/compose.xcind.yaml
  (cd "$GCC_BAD_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration="$GCC_BAD_OUT" 2>&1) && gcc_bad_rc=0 || gcc_bad_rc=$?
  assert_eq "generate-docker-compose-configuration bad config: non-zero exit" "true" \
    "$([ "$gcc_bad_rc" -ne 0 ] && echo true || echo false)"
  assert_eq "generate-docker-compose-configuration bad config: no file left behind" "false" \
    "$([ -f "$GCC_BAD_OUT" ] && echo true || echo false)"
  rm -rf "$GCC_BAD_APP" "$(dirname "$GCC_BAD_OUT")"

  # 4. --generate-docker-compose-configuration (stdout mode) outputs content
  gcc_stdout_result=$(cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration) && gcc_stdout_rc=0 || gcc_stdout_rc=$?
  assert_eq "generate-docker-compose-configuration stdout: exit code 0" "0" "$gcc_stdout_rc"
  assert_contains "generate-docker-compose-configuration stdout: contains services key" \
    "services:" "$gcc_stdout_result"

  # 5. --generate-docker-compose-configuration=FILE --json succeeds (file + JSON to stdout)
  GCC_COMBINED_FILE=$(mktemp -d)/compose.xcind.yaml
  gcc_combined_result=$(cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration="$GCC_COMBINED_FILE" --json) && gcc_combined_rc=0 || gcc_combined_rc=$?
  assert_eq "generate-docker-compose-configuration + json: exit code 0" "0" "$gcc_combined_rc"
  assert_eq "generate-docker-compose-configuration + json: file exists" "true" \
    "$([ -f "$GCC_COMBINED_FILE" ] && echo true || echo false)"
  assert_contains "generate-docker-compose-configuration + json: JSON output" \
    "composeFiles" "$gcc_combined_result"
  rm -rf "$(dirname "$GCC_COMBINED_FILE")"

  rm -rf "$GCC_TEST_APP"

else
  echo "  (skipped: docker compose not available)"
fi

# 6. --generate-docker-compose-configuration (stdout) + --json conflicts (no docker needed)
gcc_conflict_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --generate-docker-compose-configuration --json 2>&1) && gcc_conflict_rc=0 || gcc_conflict_rc=$?
assert_eq "generate-docker-compose-configuration stdout + json: non-zero exit" "true" \
  "$([ "$gcc_conflict_rc" -ne 0 ] && echo true || echo false)"
assert_contains "generate-docker-compose-configuration stdout + json: error message" \
  "stdout" "$gcc_conflict_result"

# ======================================================================
echo ""
echo "=== Test: xcind-config argument validation ==="

# 5. Unknown flag is rejected
unknown_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --bogus-flag 2>&1) && unknown_rc=0 || unknown_rc=$?
assert_eq "unknown flag: non-zero exit" "true" \
  "$([ "$unknown_rc" -ne 0 ] && echo true || echo false)"
assert_contains "unknown flag: error message" "unknown option" "$unknown_result"

# 6. No arguments shows help
noargs_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config 2>&1) && noargs_rc=0 || noargs_rc=$?
assert_eq "no args: exit code 0" "0" "$noargs_rc"
assert_contains "no args: shows usage" "Usage:" "$noargs_result"

# 7. Standalone flag cannot be combined with others
standalone_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --check --json 2>&1) && standalone_rc=0 || standalone_rc=$?
assert_eq "standalone conflict: non-zero exit" "true" \
  "$([ "$standalone_rc" -ne 0 ] && echo true || echo false)"
assert_contains "standalone conflict: error message" "cannot be combined" "$standalone_result"

# 8. Two stdout-claiming flags conflict
stdout_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --json --generate-docker-wrapper 2>&1) && stdout_rc=0 || stdout_rc=$?
assert_eq "stdout conflict: non-zero exit" "true" \
  "$([ "$stdout_rc" -ne 0 ] && echo true || echo false)"
assert_contains "stdout conflict: error message" "stdout" "$stdout_result"

# ======================================================================
echo ""
echo "=== Test: xcind-config completion subcommand ==="

# 1. completion bash produces output
comp_bash_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  completion bash 2>&1) && comp_bash_rc=0 || comp_bash_rc=$?
assert_eq "completion bash: exit code 0" "0" "$comp_bash_rc"
assert_contains "completion bash: registers xcind-compose" \
  "complete -F _xcind_compose_completions xcind-compose" "$comp_bash_result"
assert_contains "completion bash: registers xcind-config" \
  "complete -F _xcind_config_completions xcind-config" "$comp_bash_result"
assert_contains "completion bash: registers xcind-proxy" \
  "complete -F _xcind_proxy_completions xcind-proxy" "$comp_bash_result"
assert_contains "completion bash: registers xcind-workspace" \
  "complete -F _xcind_workspace_completions xcind-workspace" "$comp_bash_result"
assert_contains "completion bash: has proxy init flags" \
  "--proxy-domain" "$comp_bash_result"

# 2. completion zsh produces output
comp_zsh_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  completion zsh 2>&1) && comp_zsh_rc=0 || comp_zsh_rc=$?
assert_eq "completion zsh: exit code 0" "0" "$comp_zsh_rc"
assert_contains "completion zsh: registers xcind-compose" \
  "compdef _xcind-compose xcind-compose" "$comp_zsh_result"
assert_contains "completion zsh: registers xcind-config" \
  "compdef _xcind-config xcind-config" "$comp_zsh_result"
assert_contains "completion zsh: registers xcind-proxy" \
  "compdef _xcind-proxy xcind-proxy" "$comp_zsh_result"
assert_contains "completion zsh: registers xcind-workspace" \
  "compdef _xcind-workspace xcind-workspace" "$comp_zsh_result"
assert_contains "completion zsh: has workspace init command" \
  "init:Initialize a workspace directory" "$comp_zsh_result"

# 3. completion with no arg fails
comp_noarg_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  completion 2>&1) && comp_noarg_rc=0 || comp_noarg_rc=$?
assert_eq "completion no arg: non-zero exit" "true" \
  "$([ "$comp_noarg_rc" -ne 0 ] && echo true || echo false)"
assert_contains "completion no arg: error message" \
  "completion requires a shell argument" "$comp_noarg_result"

# 4. completion with unsupported shell fails
comp_fish_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  completion fish 2>&1) && comp_fish_rc=0 || comp_fish_rc=$?
assert_eq "completion fish: non-zero exit" "true" \
  "$([ "$comp_fish_rc" -ne 0 ] && echo true || echo false)"
assert_contains "completion fish: error message" \
  "unsupported shell" "$comp_fish_result"

# 5. completion cannot combine with other options
comp_combine_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  completion bash --json 2>&1) && comp_combine_rc=0 || comp_combine_rc=$?
assert_eq "completion combined: non-zero exit" "true" \
  "$([ "$comp_combine_rc" -ne 0 ] && echo true || echo false)"
assert_contains "completion combined: error message" \
  "cannot be combined" "$comp_combine_result"

# ======================================================================
echo ""
echo "=== Test: XCIND_TOOLS parsing and JSON output ==="

if command -v jq &>/dev/null; then

  # --- Setup: fresh app root for tools tests ---
  TOOLS_APP=$(mktemp -d)
  cat >"$TOOLS_APP/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
  touch "$TOOLS_APP/compose.yaml"

  # 1. XCIND_TOOLS not set → "tools": {}
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")
  tools_obj=$(echo "$json" | jq -c '.tools')
  assert_eq "tools empty when XCIND_TOOLS unset" "{}" "$tools_obj"

  # 2. XCIND_TOOLS=() (explicit empty) → "tools": {}
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=()
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")
  tools_obj=$(echo "$json" | jq -c '.tools')
  assert_eq "tools empty when XCIND_TOOLS=()" "{}" "$tools_obj"

  # 3. Basic tool declarations
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("php:app" "npm:app")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")

  php_service=$(echo "$json" | jq -r '.tools.php.service')
  assert_eq "tools php service" "app" "$php_service"

  php_use=$(echo "$json" | jq -r '.tools.php.use')
  assert_eq "tools php use defaults to exec" "exec" "$php_use"

  npm_service=$(echo "$json" | jq -r '.tools.npm.service')
  assert_eq "tools npm service" "app" "$npm_service"

  tools_count=$(echo "$json" | jq '.tools | length')
  assert_eq "tools count" "2" "$tools_count"

  # 4. use=run is reflected
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("phpunit:app;use=run")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")

  phpunit_use=$(echo "$json" | jq -r '.tools.phpunit.use')
  assert_eq "tools phpunit use=run" "run" "$phpunit_use"

  # 5. path appears only when specified
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("php:app" "php85:app;path=/usr/local/bin/php8.5")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")

  php_has_path=$(echo "$json" | jq 'has("tools") and (.tools.php | has("path"))')
  assert_eq "tools php has no path key" "false" "$php_has_path"

  php85_path=$(echo "$json" | jq -r '.tools.php85.path')
  assert_eq "tools php85 path" "/usr/local/bin/php8.5" "$php85_path"

  # 6. Duplicate tool names → first wins
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("php:app" "php:cron")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")

  dup_service=$(echo "$json" | jq -r '.tools.php.service')
  assert_eq "tools duplicate first wins service" "app" "$dup_service"

  dup_count=$(echo "$json" | jq '.tools | length')
  assert_eq "tools duplicate count is 1" "1" "$dup_count"

  # 7. Multiple metadata key=value pairs
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("php:app;use=run;path=/usr/bin/php")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  json=$(__xcind-resolve-json "$TOOLS_APP")

  multi_use=$(echo "$json" | jq -r '.tools.php.use')
  assert_eq "tools multi-meta use" "run" "$multi_use"

  multi_path=$(echo "$json" | jq -r '.tools.php.path')
  assert_eq "tools multi-meta path" "/usr/bin/php" "$multi_path"

  # 8. SHA changes when XCIND_TOOLS changes
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
  XCIND_TOOLS=("php:app")
  __xcind-load-config "$TOOLS_APP"
  __xcind-build-compose-opts "$TOOLS_APP"
  sha1=$(__xcind-compute-sha "$TOOLS_APP")

  # shellcheck disable=SC2034  # read by __xcind-compute-sha
  XCIND_TOOLS=("php:app" "npm:app")
  sha2=$(__xcind-compute-sha "$TOOLS_APP")

  assert_eq "SHA changes when XCIND_TOOLS changes" "true" \
    "$([ "$sha1" != "$sha2" ] && echo true || echo false)"

  rm -rf "$TOOLS_APP"
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS

else
  echo "  (skipped: jq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-app-hook ==="

if command -v yq &>/dev/null; then
  APP_HOOK_DIR=$(mktemp -d)
  export XCIND_APP="myapp"
  export XCIND_SHA="apphooktest"
  export XCIND_CACHE_DIR="$APP_HOOK_DIR/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$APP_HOOK_DIR/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
  db:
    image: postgres
  redis:
    image: redis
YAML

  hook_output=$(xcind-app-hook "$APP_HOOK_DIR")
  assert_contains "app hook prints -f flag" \
    "-f $XCIND_GENERATED_DIR/compose.app.yaml" "$hook_output"
  assert_eq "compose.app.yaml was created" "true" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.app.yaml" ] && echo true || echo false)"

  generated=$(<"$XCIND_GENERATED_DIR/compose.app.yaml")
  assert_contains "app yaml has web service" "web:" "$generated"
  assert_contains "app yaml has db service" "db:" "$generated"
  assert_contains "app yaml has redis service" "redis:" "$generated"
  assert_contains "app yaml has xcind.app.name label" "xcind.app.name=myapp" "$generated"
  assert_contains "app yaml has xcind.app.path label" "xcind.app.path=$APP_HOOK_DIR" "$generated"

  # Test: fallback to basename when XCIND_APP is unset
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  unset XCIND_APP
  xcind-app-hook "$APP_HOOK_DIR" >/dev/null
  generated_fallback=$(<"$XCIND_GENERATED_DIR/compose.app.yaml")
  assert_contains "app hook uses dirname fallback" \
    "xcind.app.name=$(basename "$APP_HOOK_DIR")" "$generated_fallback"
  export XCIND_APP="myapp"

  # Test: skip when resolved-config.yaml is missing
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  rm -f "$XCIND_CACHE_DIR/resolved-config.yaml"
  skip_output=$(xcind-app-hook "$APP_HOOK_DIR" 2>/dev/null)
  assert_eq "app hook skips when no resolved-config" "" "$skip_output"
  assert_eq "no compose.app.yaml when skipped" "false" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.app.yaml" ] && echo true || echo false)"

  rm -rf "$APP_HOOK_DIR"
else
  echo "  (skipped app hook tests: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook no-op when disabled ==="

HGW_NOOP=$(mktemp -d)
export XCIND_SHA="hgwnoop"
export XCIND_CACHE_DIR="$HGW_NOOP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$HGW_NOOP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

# shellcheck disable=SC2034  # read by xcind-host-gateway-hook
XCIND_HOST_GATEWAY_ENABLED=0
hook_output=$(xcind-host-gateway-hook "$HGW_NOOP")
assert_eq "host-gateway hook no-op when disabled: no output" "" "$hook_output"
assert_eq "host-gateway hook no-op when disabled: no file" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.host-gateway.yaml" ] && echo true || echo false)"

unset XCIND_HOST_GATEWAY_ENABLED
rm -rf "$HGW_NOOP"

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook no-op when no services ==="

if command -v yq &>/dev/null; then
  HGW_EMPTY=$(mktemp -d)
  export XCIND_SHA="hgwempty"
  export XCIND_CACHE_DIR="$HGW_EMPTY/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_EMPTY/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  # Empty resolved config (no services)
  echo "services:" >"$XCIND_CACHE_DIR/resolved-config.yaml"

  # Force a known value so detection doesn't depend on environment
  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_EMPTY")
  assert_eq "host-gateway hook no-op when no services: no output" "" "$hook_output"
  assert_eq "host-gateway hook no-op when no services: no file" "false" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.host-gateway.yaml" ] && echo true || echo false)"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_EMPTY"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook generates for all services ==="

if command -v yq &>/dev/null; then
  HGW_ALL=$(mktemp -d)
  export XCIND_SHA="hgwall"
  export XCIND_CACHE_DIR="$HGW_ALL/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_ALL/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
  worker:
    image: alpine
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_ALL")

  assert_contains "host-gateway hook returns -f flag" \
    "-f $XCIND_GENERATED_DIR/compose.host-gateway.yaml" "$hook_output"
  assert_eq "compose.host-gateway.yaml was created" "true" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.host-gateway.yaml" ] && echo true || echo false)"

  generated="$(cat "$XCIND_GENERATED_DIR/compose.host-gateway.yaml")"
  assert_contains "generated YAML has web service" "web:" "$generated"
  assert_contains "generated YAML has worker service" "worker:" "$generated"
  assert_contains "generated YAML has host.docker.internal mapping" \
    "host.docker.internal:host-gateway" "$generated"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_ALL"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook skips services with existing mapping ==="

if command -v yq &>/dev/null; then
  HGW_SKIP=$(mktemp -d)
  export XCIND_SHA="hgwskip"
  export XCIND_CACHE_DIR="$HGW_SKIP/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_SKIP/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    extra_hosts:
      - "host.docker.internal:host-gateway"
  worker:
    image: alpine
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_SKIP")

  assert_contains "host-gateway hook returns -f flag (partial)" \
    "-f $XCIND_GENERATED_DIR/compose.host-gateway.yaml" "$hook_output"

  generated="$(cat "$XCIND_GENERATED_DIR/compose.host-gateway.yaml")"
  assert_not_contains "generated YAML does not have web service (already mapped)" "web:" "$generated"
  assert_contains "generated YAML has worker service" "worker:" "$generated"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_SKIP"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook skips all when all have mapping ==="

if command -v yq &>/dev/null; then
  HGW_ALLSKIP=$(mktemp -d)
  export XCIND_SHA="hgwallskip"
  export XCIND_CACHE_DIR="$HGW_ALLSKIP/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_ALLSKIP/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    extra_hosts:
      - "host.docker.internal:host-gateway"
  worker:
    image: alpine
    extra_hosts:
      - "host.docker.internal:192.168.1.1"
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_ALLSKIP")
  assert_eq "host-gateway hook no-op when all mapped: no output" "" "$hook_output"
  assert_eq "host-gateway hook no-op when all mapped: no file" "false" \
    "$([ -f "$XCIND_GENERATED_DIR/compose.host-gateway.yaml" ] && echo true || echo false)"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_ALLSKIP"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook preserves existing extra_hosts ==="

if command -v yq &>/dev/null; then
  HGW_MERGE=$(mktemp -d)
  export XCIND_SHA="hgwmerge"
  export XCIND_CACHE_DIR="$HGW_MERGE/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_MERGE/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    extra_hosts:
      - "myhost:10.0.0.1"
      - "otherhost:10.0.0.2"
  worker:
    image: alpine
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_MERGE")

  assert_contains "host-gateway merge hook returns -f flag" \
    "-f $XCIND_GENERATED_DIR/compose.host-gateway.yaml" "$hook_output"

  generated="$(cat "$XCIND_GENERATED_DIR/compose.host-gateway.yaml")"
  assert_contains "generated YAML preserves myhost entry" "myhost:10.0.0.1" "$generated"
  assert_contains "generated YAML preserves otherhost entry" "otherhost:10.0.0.2" "$generated"
  assert_contains "generated YAML has host.docker.internal mapping" \
    "host.docker.internal:host-gateway" "$generated"
  assert_contains "generated YAML has worker service" "worker:" "$generated"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_MERGE"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook uses XCIND_HOST_GATEWAY override ==="

if command -v yq &>/dev/null; then
  HGW_OVERRIDE=$(mktemp -d)
  export XCIND_SHA="hgwoverride"
  export XCIND_CACHE_DIR="$HGW_OVERRIDE/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_OVERRIDE/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="192.168.1.100"
  hook_output=$(xcind-host-gateway-hook "$HGW_OVERRIDE")

  assert_contains "host-gateway hook returns -f flag (override)" \
    "-f $XCIND_GENERATED_DIR/compose.host-gateway.yaml" "$hook_output"

  generated="$(cat "$XCIND_GENERATED_DIR/compose.host-gateway.yaml")"
  assert_contains "generated YAML uses override value" \
    "host.docker.internal:192.168.1.100" "$generated"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_OVERRIDE"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: __xcind-detect-host-gateway defaults to host-gateway ==="

# On non-WSL2 Linux (the CI environment), should return "host-gateway"
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  # Not WSL2 and not Docker Desktop (CI) — should get "host-gateway"
  unset XCIND_HOST_GATEWAY
  detected=$(__xcind-detect-host-gateway 2>/dev/null || true)
  # Docker Desktop detection may vary, but on native Linux CI we expect host-gateway
  if [[ "$detected" == "host-gateway" ]]; then
    echo "  ✓ detect-host-gateway returns host-gateway on native Linux"
    PASS=$((PASS + 1))
  elif [[ -z "$detected" ]]; then
    # Docker Desktop detected (or docker not available) — also acceptable in CI
    echo "  ✓ detect-host-gateway returns empty (Docker Desktop or docker unavailable)"
    PASS=$((PASS + 1))
  else
    echo "  ✗ detect-host-gateway unexpected value: '$detected'"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  (skipped: running in WSL2)"
fi

# ======================================================================
echo ""
echo "=== Test: __xcind-is-wsl2 returns false on Linux ==="

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  if __xcind-is-wsl2; then
    echo "  ✗ __xcind-is-wsl2 returned true on non-WSL2 system"
    FAIL=$((FAIL + 1))
  else
    echo "  ✓ __xcind-is-wsl2 correctly returns false on non-WSL2"
    PASS=$((PASS + 1))
  fi
else
  echo "  (skipped: running in WSL2)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook handles equals separator in extra_hosts ==="

if command -v yq &>/dev/null; then
  HGW_EQ=$(mktemp -d)
  export XCIND_SHA="hgweq"
  export XCIND_CACHE_DIR="$HGW_EQ/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HGW_EQ/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    extra_hosts:
      - "host.docker.internal=host-gateway"
  worker:
    image: alpine
YAML

  # shellcheck disable=SC2034  # read by xcind-host-gateway-hook
  XCIND_HOST_GATEWAY="host-gateway"
  hook_output=$(xcind-host-gateway-hook "$HGW_EQ")

  generated="$(cat "$XCIND_GENERATED_DIR/compose.host-gateway.yaml")"
  assert_not_contains "equals separator: web skipped (already mapped)" "web:" "$generated"
  assert_contains "equals separator: worker gets mapping" "worker:" "$generated"

  unset XCIND_HOST_GATEWAY
  rm -rf "$HGW_EQ"
else
  echo "  (skipped: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: __xcind-detect-host-gateway-wsl2 mirrored mode returns LAN IP ==="

# Mock wslinfo and hostname to simulate WSL2 mirrored mode
MOCK_BIN=$(mktemp -d)
cat >"$MOCK_BIN/wslinfo" <<'SCRIPT'
#!/usr/bin/env bash
echo "mirrored"
SCRIPT
chmod +x "$MOCK_BIN/wslinfo"

cat >"$MOCK_BIN/hostname" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-I" ]]; then
  echo "10.52.19.121 fd12::1"
else
  command hostname "$@"
fi
SCRIPT
chmod +x "$MOCK_BIN/hostname"

# Put mocks first in PATH so they shadow system commands
OLD_PATH="$PATH"
export PATH="$MOCK_BIN:$PATH"

mirrored_result=$(__xcind-detect-host-gateway-wsl2 2>/dev/null)
assert_eq "mirrored mode returns LAN IP" "10.52.19.121" "$mirrored_result"

# Also test virtioproxy mode
cat >"$MOCK_BIN/wslinfo" <<'SCRIPT'
#!/usr/bin/env bash
echo "virtioproxy"
SCRIPT
chmod +x "$MOCK_BIN/wslinfo"

virtioproxy_result=$(__xcind-detect-host-gateway-wsl2 2>/dev/null)
assert_eq "virtioproxy mode returns LAN IP" "10.52.19.121" "$virtioproxy_result"

# Test fallback when hostname -I returns empty
cat >"$MOCK_BIN/hostname" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-I" ]]; then
  echo ""
else
  command hostname "$@"
fi
SCRIPT
chmod +x "$MOCK_BIN/hostname"

# Reset wslinfo to mirrored
cat >"$MOCK_BIN/wslinfo" <<'SCRIPT'
#!/usr/bin/env bash
echo "mirrored"
SCRIPT
chmod +x "$MOCK_BIN/wslinfo"

fallback_result=$(__xcind-detect-host-gateway-wsl2 2>/dev/null)
assert_eq "mirrored mode falls back to host-gateway when no LAN IP" "host-gateway" "$fallback_result"

export PATH="$OLD_PATH"
rm -rf "$MOCK_BIN"

# ======================================================================
# Cleanup
rm -rf "$MOCK_APP"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
