#!/usr/bin/env bash
# shellcheck disable=SC2016
# test-xcind.sh — Verify xcind resolution logic
set -euo pipefail

# yq and jq are required runtime dependencies (e9319cd promoted yq). The
# test suite exercises hook generators and JSON contracts that cannot run
# without them, so fail loudly rather than silently skipping tests.
for _xcind_required in yq jq; do
  if ! command -v "$_xcind_required" >/dev/null 2>&1; then
    echo "ERROR: $_xcind_required is required to run the xcind test suite." >&2
    echo "  Install it (e.g. 'apt-get install $_xcind_required' or 'nix-shell -p $_xcind_required-go')." >&2
    exit 1
  fi
done
unset _xcind_required

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$XCIND_ROOT/lib/xcind/xcind-lib.bash"

PASS=0
FAIL=0
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/assert.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/setup.sh"

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
MOCK_APP=$(mktemp_d)
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
EMPTY_DIR=$(mktemp_d)
err_file=$(mktemp)
result=$(__xcind-app-root "$EMPTY_DIR" 2>"$err_file") && status=0 || status=$?
err=$(<"$err_file")
rm -f "$err_file"
assert_eq "fails without .xcind.sh" "1" "$status"
assert_contains "error mentions missing .xcind.sh" ".xcind.sh" "$err"

rm -rf "$MOCK_APP" "$EMPTY_DIR"

# ======================================================================
echo ""
echo "=== Test: __xcind-resolve-files ==="

# Set up a mock application with files
MOCK_APP=$(mktemp_d)
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
DEFAULT_APP=$(mktemp_d)
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

OVERRIDE_PROJECT=$(mktemp_d)
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

BC_APP=$(mktemp_d)
cat >"$BC_APP/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_ENV_FILES=(".env.legacy")
EOF
touch "$BC_APP/compose.yaml"
touch "$BC_APP/.env.legacy"

reset_xcind_state

bc_stderr_file=$(mktemp)
__xcind-load-config "$BC_APP" 2>"$bc_stderr_file"
bc_stderr=$(<"$bc_stderr_file")
rm "$bc_stderr_file"

assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES count" "1" "${#XCIND_COMPOSE_ENV_FILES[@]}"
assert_eq "BC shim sets XCIND_COMPOSE_ENV_FILES[0]" ".env.legacy" "${XCIND_COMPOSE_ENV_FILES[0]}"
assert_contains "BC shim emits deprecation warning" "deprecated" "$bc_stderr"

rm -rf "$BC_APP"
reset_xcind_state

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

# ======================================================================
echo ""
echo "=== Test: __xcind-dump-docker-compose-wrapper ==="

WRAPPER_APP=$(mktemp_d)
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
WS_ROOT=$(mktemp_d)
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
NON_WS_PARENT=$(mktemp_d)
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
STANDALONE_APP=$(mktemp_d)
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
ws_err_file=$(mktemp)
result=$(__xcind-app-root "$WS_ROOT/myworkspace" 2>"$ws_err_file") && status=0 || status=$?
ws_err=$(<"$ws_err_file")
rm -f "$ws_err_file"
assert_eq "app-root from workspace root fails" "1" "$status"
assert_contains "app-root error mentions missing .xcind.sh" ".xcind.sh" "$ws_err"

rm -rf "$WS_ROOT" "$STANDALONE_APP"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace init CLI ==="

# Plain init creates .xcind.sh with XCIND_IS_WORKSPACE=1 and reports path
WS_PLAIN=$(mktemp_d)
init_out=$("$XCIND_ROOT/bin/xcind-workspace" init "$WS_PLAIN")
assert_file_exists "plain init: .xcind.sh created" "$WS_PLAIN/.xcind.sh"
content=$(<"$WS_PLAIN/.xcind.sh")
assert_contains "plain init: XCIND_IS_WORKSPACE=1 set" "XCIND_IS_WORKSPACE=1" "$content"
assert_contains "plain init: reports target path" "$WS_PLAIN" "$init_out"

# --name flag persists XCIND_WORKSPACE
WS_NAMED=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_NAMED" --name "myteam" >/dev/null
content=$(<"$WS_NAMED/.xcind.sh")
assert_contains "--name: XCIND_WORKSPACE persisted" 'XCIND_WORKSPACE="myteam"' "$content"

# --proxy-domain flag persists XCIND_PROXY_DOMAIN
WS_PROXY=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_PROXY" --proxy-domain "test.local" >/dev/null
content=$(<"$WS_PROXY/.xcind.sh")
assert_contains "--proxy-domain: XCIND_PROXY_DOMAIN persisted" \
  'XCIND_PROXY_DOMAIN="test.local"' "$content"

# Both flags together
WS_BOTH=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_BOTH" --name "combo" --proxy-domain "combo.test" >/dev/null
content=$(<"$WS_BOTH/.xcind.sh")
assert_contains "combined: name persisted" 'XCIND_WORKSPACE="combo"' "$content"
assert_contains "combined: domain persisted" 'XCIND_PROXY_DOMAIN="combo.test"' "$content"

# Idempotent init: second run without flags preserves existing config
content_before=$(<"$WS_NAMED/.xcind.sh")
idem_out=$("$XCIND_ROOT/bin/xcind-workspace" init "$WS_NAMED")
content_after=$(<"$WS_NAMED/.xcind.sh")
assert_eq "idempotent: file unchanged on re-init" "$content_before" "$content_after"
assert_contains "idempotent: reports already-initialized" "already initialized" "$idem_out"

# Re-init with flags updates the stored values
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_NAMED" --proxy-domain "new.example" >/dev/null
content=$(<"$WS_NAMED/.xcind.sh")
assert_contains "update: new domain applied" 'XCIND_PROXY_DOMAIN="new.example"' "$content"
assert_contains "update: prior name preserved" 'XCIND_WORKSPACE="myteam"' "$content"

# Init on a directory containing a non-workspace .xcind.sh (an app config) fails
APP_DIR=$(mktemp_d)
echo '# app config (no XCIND_IS_WORKSPACE)' >"$APP_DIR/.xcind.sh"
init_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" init "$APP_DIR" 2>"$init_err_file" && init_app_rc=0 || init_app_rc=$?
init_err=$(<"$init_err_file")
rm -f "$init_err_file"
assert_eq "init over app config: exits 1" "1" "$init_app_rc"
assert_contains "init over app: error mentions app configuration" \
  "app configuration" "$init_err"

# Unknown flag fails
unk_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_PLAIN" --bogus 2>"$unk_err_file" && unk_rc=0 || unk_rc=$?
unk_err=$(<"$unk_err_file")
rm -f "$unk_err_file"
assert_eq "unknown init flag: exits 1" "1" "$unk_rc"
assert_contains "unknown init flag: error names the flag" "--bogus" "$unk_err"

# --version short-circuits
ver_out=$("$XCIND_ROOT/bin/xcind-workspace" --version)
assert_contains "--version: prints xcind-workspace" "xcind-workspace" "$ver_out"

# --help prints usage
help_out=$("$XCIND_ROOT/bin/xcind-workspace" --help)
assert_contains "--help: prints Usage" "Usage: xcind-workspace" "$help_out"
assert_contains "--help: lists init subcommand" "init [DIR]" "$help_out"
assert_contains "--help: lists status subcommand" "status [DIR]" "$help_out"

# No arguments prints help and exits 0
noargs_out=$("$XCIND_ROOT/bin/xcind-workspace")
assert_contains "no args: prints help" "Usage: xcind-workspace" "$noargs_out"

# Unknown subcommand fails
badcmd_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" bogus 2>"$badcmd_err_file" && badcmd_rc=0 || badcmd_rc=$?
badcmd_err=$(<"$badcmd_err_file")
rm -f "$badcmd_err_file"
assert_eq "unknown subcommand: exits 1" "1" "$badcmd_rc"
assert_contains "unknown subcommand: error mentions Unknown command" \
  "Unknown command" "$badcmd_err"

rm -rf "$WS_PLAIN" "$WS_NAMED" "$WS_PROXY" "$WS_BOTH" "$APP_DIR"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace status CLI ==="

# Build a workspace + two apps. Mock docker so status doesn't touch real
# Docker state (mirrors test-xcind-proxy.sh's pattern).
WS_STATUS=$(mktemp_d)
WS_STATUS_HOME=$(mktemp_d)
_ws_status_orig_HOME="$HOME"
_ws_status_orig_PATH="$PATH"
export HOME="$WS_STATUS_HOME"
mkdir -p "$WS_STATUS_HOME/bin"
cat >"$WS_STATUS_HOME/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker for workspace status tests — report nothing running.
case "$1" in
network) exit 1 ;;  # no networks
ps) echo "" ;;
inspect) exit 1 ;;
*) exit 0 ;;
esac
MOCKEOF
chmod +x "$WS_STATUS_HOME/bin/docker"
export PATH="$WS_STATUS_HOME/bin:$_ws_status_orig_PATH"

# Initialize the workspace via the real CLI
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_STATUS" --name "wsstatus" >/dev/null

# Status with an empty workspace (no apps) — text mode
status_empty=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS" 2>&1)
assert_contains "status empty: Workspace header" "Workspace: wsstatus" "$status_empty"
assert_contains "status empty: Root line" "Root:" "$status_empty"
assert_contains "status empty: Apps section" "Apps:" "$status_empty"
assert_contains "status empty: reports (none)" "(none)" "$status_empty"

# Add a registered app (XCIND_WORKSPACE matches the workspace name)
mkdir -p "$WS_STATUS/webapp"
cat >"$WS_STATUS/webapp/.xcind.sh" <<'APPEOF'
# app config
XCIND_WORKSPACE="wsstatus"
XCIND_COMPOSE_FILES=("compose.yaml")
APPEOF
cat >"$WS_STATUS/webapp/compose.yaml" <<'COMPOSEEOF'
services:
  web:
    image: nginx
COMPOSEEOF

status_registered=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS" 2>&1)
assert_contains "status registered: Apps section" "Apps:" "$status_registered"
assert_contains "status registered: shows webapp name" "webapp/" "$status_registered"
assert_contains "status registered: shows stopped indicator" "stopped" "$status_registered"
assert_contains "status registered: shows network line" "Network:" "$status_registered"
assert_contains "status registered: shows proxy line" "Proxy:" "$status_registered"

# --json output
status_json=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS" --json 2>&1)
# Must be parseable JSON
printf '%s' "$status_json" | jq . >/dev/null && json_rc=0 || json_rc=$?
assert_eq "status --json: parseable JSON" "0" "$json_rc"

json_workspace=$(printf '%s' "$status_json" | jq -r '.workspace')
assert_eq "status --json: workspace name" "wsstatus" "$json_workspace"
json_root=$(printf '%s' "$status_json" | jq -r '.root')
assert_eq "status --json: root path" "$WS_STATUS" "$json_root"
json_has_apps=$(printf '%s' "$status_json" | jq -r '.apps | type')
assert_eq "status --json: apps is an array" "array" "$json_has_apps"
json_proxy_running=$(printf '%s' "$status_json" | jq -r '.proxy.running')
assert_eq "status --json: proxy.running is bool" "false" "$json_proxy_running"

# Status outside any workspace fails
OUTSIDE_DIR=$(mktemp_d)
out_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" status "$OUTSIDE_DIR" 2>"$out_err_file" && outside_rc=0 || outside_rc=$?
out_err=$(<"$out_err_file")
rm -f "$out_err_file"
assert_eq "status outside workspace: exits 1" "1" "$outside_rc"
assert_contains "status outside: error mentions Not inside" \
  "Not inside a workspace" "$out_err"

# Status on a missing directory fails
missing_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" status "/nonexistent/does-not-exist-xcind" \
  2>"$missing_err_file" && missing_rc=0 || missing_rc=$?
missing_err=$(<"$missing_err_file")
rm -f "$missing_err_file"
assert_eq "status missing dir: exits 1" "1" "$missing_rc"
assert_contains "status missing: error mentions Directory not found" \
  "Directory not found" "$missing_err"

# Unknown status flag
status_unk_err_file=$(mktemp)
"$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS" --bogus 2>"$status_unk_err_file" &&
  status_unk_rc=0 || status_unk_rc=$?
status_unk_err=$(<"$status_unk_err_file")
rm -f "$status_unk_err_file"
assert_eq "unknown status flag: exits 1" "1" "$status_unk_rc"
assert_contains "unknown status flag: error names the flag" \
  "--bogus" "$status_unk_err"

export HOME="$_ws_status_orig_HOME"
export PATH="$_ws_status_orig_PATH"
unset _ws_status_orig_HOME _ws_status_orig_PATH
rm -rf "$WS_STATUS" "$WS_STATUS_HOME" "$OUTSIDE_DIR"

# ======================================================================
echo ""
echo "=== Test: __xcind-late-bind-workspace ==="

# Test: late-bind when app sets XCIND_WORKSPACE
unset XCIND_WORKSPACE_ROOT
XCIND_WORKSPACELESS=1
XCIND_WORKSPACE="myws"
LATE_BIND_APP=$(mktemp_d)
XCIND_APP_ROOT="$LATE_BIND_APP"
__xcind-late-bind-workspace
assert_eq "late-bind flips XCIND_WORKSPACELESS" "0" "$XCIND_WORKSPACELESS"
assert_eq "late-bind sets XCIND_WORKSPACE_ROOT" "$LATE_BIND_APP" "$XCIND_WORKSPACE_ROOT"

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

SHA_APP=$(mktemp_d)
echo '# sha test config' >"$SHA_APP/.xcind.sh"
mkdir -p "$SHA_APP/docker"
echo 'version: "3"' >"$SHA_APP/docker/compose.yaml"
touch "$SHA_APP/.env"

# Build opts so SHA has compose files to hash
reset_xcind_state
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
echo "=== Test: SHA invalidates when detected host-gateway value changes ==="

HGW_SHA_APP=$(mktemp_d)
echo '# hgw sha test' >"$HGW_SHA_APP/.xcind.sh"
touch "$HGW_SHA_APP/compose.yaml"

reset_xcind_state
__xcind-load-config "$HGW_SHA_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$HGW_SHA_APP"

XCIND_WORKSPACELESS=1
XCIND_WORKSPACE_ROOT=""
unset XCIND_HOST_GATEWAY XCIND_HOST_GATEWAY_ENABLED

# First SHA with one detected value (simulating WSL2 mirrored mode LAN IP)
# shellcheck disable=SC2317,SC2329  # invoked indirectly via __xcind-compute-sha
__xcind-detect-host-gateway() { echo "192.168.1.100"; }
sha1=$(__xcind-compute-sha "$HGW_SHA_APP")

# Second SHA with a different detected value (simulating DHCP renewal)
# shellcheck disable=SC2317,SC2329  # invoked indirectly via __xcind-compute-sha
__xcind-detect-host-gateway() { echo "10.0.0.50"; }
sha2=$(__xcind-compute-sha "$HGW_SHA_APP")

assert_eq "SHA changes when detected host-gateway changes" "true" \
  "$([ "$sha1" != "$sha2" ] && echo true || echo false)"

# SHA should be stable when the detected value does not change
sha3=$(__xcind-compute-sha "$HGW_SHA_APP")
assert_eq "SHA stable when detected host-gateway unchanged" "$sha2" "$sha3"

# When the hook is disabled, detection must not influence the SHA
# shellcheck disable=SC2034  # read by __xcind-compute-sha
XCIND_HOST_GATEWAY_ENABLED=0
sha_disabled=$(__xcind-compute-sha "$HGW_SHA_APP")
# shellcheck disable=SC2317,SC2329  # invoked indirectly via __xcind-compute-sha
__xcind-detect-host-gateway() { echo "completely-different"; }
sha_disabled2=$(__xcind-compute-sha "$HGW_SHA_APP")
assert_eq "SHA unchanged when hook disabled regardless of detection" \
  "$sha_disabled" "$sha_disabled2"

# Restore the real detection function by re-sourcing the host-gateway lib
source "$XCIND_ROOT/lib/xcind/xcind-host-gateway-lib.bash"
unset XCIND_HOST_GATEWAY_ENABLED
rm -rf "$HGW_SHA_APP"
reset_xcind_state

# ======================================================================
echo ""
echo "=== Test: __xcind-run-hooks (stub) ==="

HOOK_APP=$(mktemp_d)
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
reset_xcind_state
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

ORDER_APP=$(mktemp_d)
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

reset_xcind_state
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

EXEC_APP=$(mktemp_d)
EXEC_HOOK_CALLED=""
stub_execute_hook() {
  EXEC_HOOK_CALLED="yes:$1"
}
XCIND_HOOKS_EXECUTE=("stub_execute_hook")

__xcind-run-execute-hooks "$EXEC_APP"
assert_eq "execute hook called with app_root" "yes:$EXEC_APP" "$EXEC_HOOK_CALLED"

# Verify execute hooks always run (no caching)
EXEC_HOOK_COUNT=0
counting_execute_hook() {
  EXEC_HOOK_COUNT=$((EXEC_HOOK_COUNT + 1))
}
XCIND_HOOKS_EXECUTE=("counting_execute_hook")

__xcind-run-execute-hooks "$EXEC_APP"
__xcind-run-execute-hooks "$EXEC_APP"
__xcind-run-execute-hooks "$EXEC_APP"
assert_eq "execute hooks run every invocation (not cached)" "3" "$EXEC_HOOK_COUNT"

# Verify empty hooks array leaves XCIND_DOCKER_COMPOSE_OPTS untouched.
# (Under set -e, the previous assertion — "exit 0" — was tautological:
#  any non-zero return would have aborted the script before we got here.)
# shellcheck disable=SC2034 # consumed by __xcind-run-execute-hooks
XCIND_HOOKS_EXECUTE=()
XCIND_DOCKER_COMPOSE_OPTS=("-f" "sentinel.yaml")
__xcind-run-execute-hooks "$EXEC_APP"
assert_eq "empty execute hooks: compose opts unchanged (count)" \
  "2" "${#XCIND_DOCKER_COMPOSE_OPTS[@]}"
assert_eq "empty execute hooks: compose opts unchanged (content)" \
  "-f sentinel.yaml" "${XCIND_DOCKER_COMPOSE_OPTS[*]}"

# ======================================================================
echo ""
echo "=== Test: __xcind-run-hooks failure modes ==="

# 1. Hook that exits non-zero must abort the pipeline and propagate the code.
FAIL_APP=$(mktemp_d)
echo '# fail hook test' >"$FAIL_APP/.xcind.sh"
touch "$FAIL_APP/compose.yaml"

export XCIND_SHA="failhook001"
export XCIND_CACHE_DIR="$FAIL_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$FAIL_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

# shellcheck disable=SC2317,SC2329 # invoked via XCIND_HOOKS_GENERATE
failing_hook() {
  echo "Error: intentional failure" >&2
  return 7
}
XCIND_HOOKS_GENERATE=("failing_hook")

reset_xcind_state
__xcind-load-config "$FAIL_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$FAIL_APP"

fail_stderr=$(__xcind-run-hooks "$FAIL_APP" 2>&1) && fail_rc=0 || fail_rc=$?
assert_eq "failing hook: rc propagates" "7" "$fail_rc"
assert_contains "failing hook: stderr mentions hook name" "failing_hook" "$fail_stderr"
assert_contains "failing hook: stderr mentions exit code" "exit code 7" "$fail_stderr"

unset -f failing_hook
rm -rf "$FAIL_APP"

# 2. Hook emits `-f` to a file that later disappears — cache-hit validation
#    must detect the missing file and rebuild from scratch.
REBUILD_APP=$(mktemp_d)
echo '# rebuild test' >"$REBUILD_APP/.xcind.sh"
touch "$REBUILD_APP/compose.yaml"

export XCIND_SHA="rebuild002"
export XCIND_CACHE_DIR="$REBUILD_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$REBUILD_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

REBUILD_COUNT_FILE=$(mktemp)
echo 0 >"$REBUILD_COUNT_FILE"

# shellcheck disable=SC2317,SC2329 # invoked via XCIND_HOOKS_GENERATE
rebuilding_hook() {
  local count
  count=$(<"$REBUILD_COUNT_FILE")
  count=$((count + 1))
  echo "$count" >"$REBUILD_COUNT_FILE"
  mkdir -p "$XCIND_GENERATED_DIR"
  touch "$XCIND_GENERATED_DIR/compose.rebuild.yaml"
  echo "-f $XCIND_GENERATED_DIR/compose.rebuild.yaml"
}
XCIND_HOOKS_GENERATE=("rebuilding_hook")

reset_xcind_state
__xcind-load-config "$REBUILD_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$REBUILD_APP"

# First run: cache miss → hook runs once, persists output.
__xcind-run-hooks "$REBUILD_APP"
first_count=$(<"$REBUILD_COUNT_FILE")
assert_eq "rebuild: hook ran on cache miss" "1" "$first_count"

# Remove the referenced compose file to invalidate the cached hook output.
rm -f "$XCIND_GENERATED_DIR/compose.rebuild.yaml"

# Second run: cache hit → validation fails → recursive rebuild. Hook must
# run a SECOND time because __xcind-run-hooks wipes XCIND_GENERATED_DIR
# and recurses into the cache-miss branch.
reset_xcind_state
__xcind-load-config "$REBUILD_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$REBUILD_APP"
__xcind-run-hooks "$REBUILD_APP"
second_count=$(<"$REBUILD_COUNT_FILE")
assert_eq "rebuild: hook re-ran after validation failure" "2" "$second_count"
assert_file_exists "rebuild: referenced file re-created" \
  "$XCIND_GENERATED_DIR/compose.rebuild.yaml"

unset -f rebuilding_hook
rm -rf "$REBUILD_APP"
rm -f "$REBUILD_COUNT_FILE"

# 3. Hook emits assorted line shapes — empty lines, single tokens, and
#    flag+value pairs. __xcind-append-hook-output-to-opts must not crash
#    and must normalize them correctly into XCIND_DOCKER_COMPOSE_OPTS.
SHAPES_APP=$(mktemp_d)
echo '# shapes test' >"$SHAPES_APP/.xcind.sh"
touch "$SHAPES_APP/compose.yaml"

export XCIND_SHA="shapes003"
export XCIND_CACHE_DIR="$SHAPES_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$SHAPES_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

# shellcheck disable=SC2317,SC2329 # invoked via XCIND_HOOKS_GENERATE
shapes_hook() {
  mkdir -p "$XCIND_GENERATED_DIR"
  touch "$XCIND_GENERATED_DIR/compose.shapes.yaml"
  # Intentionally weird output: blank line, single token, -f pair
  printf '\n--verbose\n-f %s\n' "$XCIND_GENERATED_DIR/compose.shapes.yaml"
}
XCIND_HOOKS_GENERATE=("shapes_hook")

reset_xcind_state
__xcind-load-config "$SHAPES_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$SHAPES_APP"

__xcind-run-hooks "$SHAPES_APP" && shapes_rc=0 || shapes_rc=$?
assert_eq "shapes: hook succeeds" "0" "$shapes_rc"

shapes_opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"
assert_contains "shapes: --verbose single token parsed" "--verbose" "$shapes_opts"
assert_contains "shapes: -f flag+value parsed" "compose.shapes.yaml" "$shapes_opts"

unset -f shapes_hook
rm -rf "$SHAPES_APP"

# 4. Hook emits -f to a nonexistent path on FIRST run — the cache-miss
#    branch persists the output verbatim, but the next cache-hit run
#    triggers validation failure and recurses. Without a guard this would
#    be an infinite loop if the hook kept emitting the bad path; our hook
#    does the same thing on both invocations so the final state after the
#    rebuild still has the bad path persisted. Assert that rc is still 0
#    (validation rebuilds, doesn't fail the pipeline) and that the hook
#    was re-invoked as expected.
BAD_APP=$(mktemp_d)
echo '# bad path test' >"$BAD_APP/.xcind.sh"
touch "$BAD_APP/compose.yaml"

export XCIND_SHA="badpath004"
export XCIND_CACHE_DIR="$BAD_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$BAD_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR"

BAD_COUNT_FILE=$(mktemp)
echo 0 >"$BAD_COUNT_FILE"

# shellcheck disable=SC2317,SC2329 # invoked via XCIND_HOOKS_GENERATE
bad_path_hook() {
  local count
  count=$(<"$BAD_COUNT_FILE")
  count=$((count + 1))
  echo "$count" >"$BAD_COUNT_FILE"
  mkdir -p "$XCIND_GENERATED_DIR"
  # Create the file for the first run only; subsequent rebuilds see it
  # present (because we created it earlier), so validation passes on
  # the second cache-hit attempt.
  touch "$XCIND_GENERATED_DIR/compose.bad.yaml"
  echo "-f $XCIND_GENERATED_DIR/compose.bad.yaml"
}
XCIND_HOOKS_GENERATE=("bad_path_hook")

reset_xcind_state
__xcind-load-config "$BAD_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$BAD_APP"

# First run — cache miss
__xcind-run-hooks "$BAD_APP"
# Delete the file to force validation failure on cache-hit path
rm -f "$XCIND_GENERATED_DIR/compose.bad.yaml"

# Second run — cache hit → validation fails → recurse. Hook re-creates
# the file so the recursive cache-miss branch succeeds and the whole
# call returns 0 without ever exposing the transient missing state.
reset_xcind_state
__xcind-load-config "$BAD_APP"
XCIND_COMPOSE_FILES=("compose.yaml")
__xcind-build-compose-opts "$BAD_APP"
__xcind-run-hooks "$BAD_APP" && bad_rc=0 || bad_rc=$?
assert_eq "bad -f: pipeline recovers via rebuild" "0" "$bad_rc"
bad_count=$(<"$BAD_COUNT_FILE")
assert_eq "bad -f: hook invoked twice (miss + rebuild)" "2" "$bad_count"
assert_file_exists "bad -f: referenced file re-created" \
  "$XCIND_GENERATED_DIR/compose.bad.yaml"

unset -f bad_path_hook
rm -rf "$BAD_APP"
rm -f "$BAD_COUNT_FILE"

# Restore default hooks and clean environment for subsequent tests
unset XCIND_SHA XCIND_CACHE_DIR XCIND_GENERATED_DIR
# shellcheck disable=SC2034 # reset for downstream tests
XCIND_HOOKS_GENERATE=("xcind-naming-hook" "xcind-app-hook" "xcind-app-env-hook" "xcind-host-gateway-hook" "xcind-proxy-hook" "xcind-assigned-hook" "xcind-workspace-hook")
reset_xcind_state

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

ADDCFG_APP=$(mktemp_d)
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
reset_xcind_state
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

VAREXP_APP=$(mktemp_d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$VAREXP_APP/.xcind.sh" <<'XCEOF'
XCIND_ADDITIONAL_CONFIG_FILES=('.xcind.${APP_ENV:-dev}.sh')
XCEOF

cat >"$VAREXP_APP/.xcind.staging.sh" <<'EOF'
XCIND_STAGING_LOADED=1
EOF

reset_xcind_state
export APP_ENV="staging"
__xcind-load-config "$VAREXP_APP"
__xcind-source-additional-configs "$VAREXP_APP"

assert_eq "variable expansion resolves staging" "1" "${XCIND_STAGING_LOADED:-0}"

# Non-existent file is skipped silently
reset_xcind_state
unset XCIND_STAGING_LOADED
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

EMPTY_APP=$(mktemp_d)
__XCIND_SOURCED_CONFIG_FILES=()
echo '# no additional configs' >"$EMPTY_APP/.xcind.sh"

reset_xcind_state
__xcind-load-config "$EMPTY_APP"
__xcind-source-additional-configs "$EMPTY_APP"

assert_eq "empty additional configs — default count" "0" "${#XCIND_ADDITIONAL_CONFIG_FILES[@]}"
assert_eq "empty additional configs — only base sourced" "1" "${#__XCIND_SOURCED_CONFIG_FILES[@]}"

rm -rf "$EMPTY_APP"

# ======================================================================
echo ""
echo "=== Test: __xcind-source-additional-configs with unset variable ==="

__XCIND_SOURCED_CONFIG_FILES=()
WS_UNSET_ROOT=$(mktemp_d)
mkdir -p "$WS_UNSET_ROOT/myworkspace/myapp"

# Workspace only sets XCIND_IS_WORKSPACE, no XCIND_ADDITIONAL_CONFIG_FILES
echo 'XCIND_IS_WORKSPACE=1' >"$WS_UNSET_ROOT/myworkspace/.xcind.sh"
# App .xcind.sh is empty (no XCIND_ADDITIONAL_CONFIG_FILES set)
echo '# nothing' >"$WS_UNSET_ROOT/myworkspace/myapp/.xcind.sh"

reset_xcind_state
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

WS_ADD_ROOT=$(mktemp_d)
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
reset_xcind_state
unset XCIND_APP_ROOT

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

WS_OVR_ROOT=$(mktemp_d)
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

reset_xcind_state
unset XCIND_APP_ROOT XCIND_LOCAL_LOADED

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

SHA_ADD_APP=$(mktemp_d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$SHA_ADD_APP/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
echo 'version: "3"' >"$SHA_ADD_APP/compose.yaml"
echo 'XCIND_DEV_VAR=original' >"$SHA_ADD_APP/.xcind.dev.sh"

reset_xcind_state
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

JSON_APP=$(mktemp_d)
__XCIND_SOURCED_CONFIG_FILES=()

cat >"$JSON_APP/.xcind.sh" <<'EOF'
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.dev.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
touch "$JSON_APP/compose.yaml"
echo '# dev config' >"$JSON_APP/.xcind.dev.sh"

reset_xcind_state
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
JSON_WS=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-naming-hook (workspaceless mode) ==="

NAMING_WL=$(mktemp_d)
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

NAMING_WS=$(mktemp_d)
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

APPENV_NOOP=$(mktemp_d)
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

APPENV_APP=$(mktemp_d)
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

# ======================================================================
echo "=== Test: __xcind-check-deps ==="

CDEPS_STUBS=$(mktemp_d)
CDEPS_EMPTY=$(mktemp_d)

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
# Remove jq from stubs (yq is required as of 0.5.x — see __xcind-check-deps)
rm -f "$CDEPS_STUBS/jq"
cdeps_reqonly_out=$(PATH="$CDEPS_STUBS" __xcind-check-deps 2>&1)
cdeps_reqonly_rc=$?
assert_eq "required-only: returns 0" "0" "$cdeps_reqonly_rc"
assert_not_contains "required-only: no required-missing message" "Required dependencies are missing" "$cdeps_reqonly_out"
assert_contains "required-only: optional-missing warning shown" "Optional dependencies are missing" "$cdeps_reqonly_out"

# 2b. Required yq missing → returns non-zero (regression guard for yq promotion)
rm -f "$CDEPS_STUBS/yq"
cdeps_noyq_out=$(PATH="$CDEPS_STUBS" __xcind-check-deps 2>&1) && cdeps_noyq_rc=0 || cdeps_noyq_rc=$?
assert_eq "yq missing: returns 1" "1" "$cdeps_noyq_rc"
assert_contains "yq missing: required message shown" "Required dependencies are missing" "$cdeps_noyq_out"

# 3. Required deps missing → returns non-zero
cdeps_miss_out=$(PATH="$CDEPS_EMPTY" __xcind-check-deps 2>&1) && cdeps_miss_rc=0 || cdeps_miss_rc=$?
assert_eq "required missing: returns 1" "1" "$cdeps_miss_rc"
assert_contains "required missing: required message shown" "Required dependencies are missing" "$cdeps_miss_out"

# 4. Multiple required deps missing → issue count reflects all (not capped at 1)
# Empty PATH: bash, docker, docker compose, sha256sum, yq all missing (5 required) + jq (1 optional) = 6 issues
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

  GCC_TEST_APP=$(mktemp_d)
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
  GCC_OUT_FILE=$(mktemp_d)/compose.xcind.yaml
  (cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration="$GCC_OUT_FILE") && gcc_rc=0 || gcc_rc=$?
  assert_eq "generate-docker-compose-configuration: exit code 0" "0" "$gcc_rc"
  assert_eq "generate-docker-compose-configuration: file exists" "true" \
    "$([ -f "$GCC_OUT_FILE" ] && echo true || echo false)"
  gcc_yaml_content=$(cat "$GCC_OUT_FILE" 2>/dev/null || true)
  assert_contains "generate-docker-compose-configuration: contains services key" "services:" "$gcc_yaml_content"
  rm -rf "$(dirname "$GCC_OUT_FILE")"

  # 2. --generate-docker-compose-configuration FILE (space-separated) works identically
  GCC_OUT_FILE2=$(mktemp_d)/compose.xcind.yaml
  (cd "$GCC_TEST_APP" && PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
    --generate-docker-compose-configuration "$GCC_OUT_FILE2") && gcc_rc=0 || gcc_rc=$?
  assert_eq "generate-docker-compose-configuration space form: exit code 0" "0" "$gcc_rc"
  assert_eq "generate-docker-compose-configuration space form: file exists" "true" \
    "$([ -f "$GCC_OUT_FILE2" ] && echo true || echo false)"
  rm -rf "$(dirname "$GCC_OUT_FILE2")"

  # 3. --generate-docker-compose-configuration fails gracefully on bad config
  GCC_BAD_APP=$(mktemp_d)
  cat >"$GCC_BAD_APP/.xcind.sh" <<'XCINDEOF'
XCIND_COMPOSE_FILES=(nonexistent.yaml)
XCIND_COMPOSE_ENV_FILES=()
XCINDEOF
  GCC_BAD_OUT=$(mktemp_d)/compose.xcind.yaml
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
  GCC_COMBINED_FILE=$(mktemp_d)/compose.xcind.yaml
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

# 9. --generate-*= with empty value is rejected with a clear error
empty_dw_rc=0
empty_dw_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --generate-docker-wrapper= 2>&1) || empty_dw_rc=$?
assert_eq "empty --generate-docker-wrapper=: non-zero exit" "1" "$empty_dw_rc"
assert_contains "empty --generate-docker-wrapper=: error message" \
  "requires a file path" "$empty_dw_result"

empty_dcw_rc=0
empty_dcw_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --generate-docker-compose-wrapper= 2>&1) || empty_dcw_rc=$?
assert_eq "empty --generate-docker-compose-wrapper=: non-zero exit" "1" "$empty_dcw_rc"
assert_contains "empty --generate-docker-compose-wrapper=: error message" \
  "requires a file path" "$empty_dcw_result"

empty_dcc_rc=0
empty_dcc_result=$(PATH="$XCIND_ROOT/bin:$PATH" xcind-config \
  --generate-docker-compose-configuration= 2>&1) || empty_dcc_rc=$?
assert_eq "empty --generate-docker-compose-configuration=: non-zero exit" "1" "$empty_dcc_rc"
assert_contains "empty --generate-docker-compose-configuration=: error message" \
  "requires a file path" "$empty_dcc_result"

# ======================================================================
echo ""
echo "=== Test: __xcind-preview-command quoting ==="

# Call __xcind-preview-command directly (xcind-lib.bash is already sourced
# at the top of this file) so the test does not require a Docker daemon.
# Inject a synthetic XCIND_DOCKER_COMPOSE_OPTS containing a path with a
# space; then evaluate the output with a mock docker to verify the path
# round-trips intact regardless of the quoting form printf '%q' uses
# (bash 3.2/4.0 may produce single-quoted form; bash 4.4+ backslash form).
_pq_out=$(
  XCIND_DOCKER_COMPOSE_OPTS=("-f" "/app/with space/compose.yaml" "--project-directory" "/app/with space")
  __xcind-preview-command "/app/with space" 2>&1
) && _pq_rc=0 || _pq_rc=$?
assert_eq "preview %q: exit 0" "0" "$_pq_rc"

_pq_cmd=$(printf '%s\n' "$_pq_out" | grep -v '^#')
_pq_args=$(
  # shellcheck disable=SC2317,SC2329
  docker() { printf '%s\n' "$@"; }
  eval "$_pq_cmd"
) && _pq_eval_rc=0 || _pq_eval_rc=$?
assert_eq "preview %q: output is valid shell" "0" "$_pq_eval_rc"
assert_contains "preview %q: space path round-trips as single arg" \
  "/app/with space/compose.yaml" "$_pq_args"

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

# --- Setup: fresh app root for tools tests ---
TOOLS_APP=$(mktemp_d)
cat >"$TOOLS_APP/.xcind.sh" <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
touch "$TOOLS_APP/compose.yaml"

# 1. XCIND_TOOLS not set → "tools": {}
reset_xcind_state
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")
tools_obj=$(echo "$json" | jq -c '.tools')
assert_eq "tools empty when XCIND_TOOLS unset" "{}" "$tools_obj"

# 2. XCIND_TOOLS=() (explicit empty) → "tools": {}
reset_xcind_state
XCIND_TOOLS=()
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")
tools_obj=$(echo "$json" | jq -c '.tools')
assert_eq "tools empty when XCIND_TOOLS=()" "{}" "$tools_obj"

# 3. Basic tool declarations
reset_xcind_state
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
reset_xcind_state
XCIND_TOOLS=("phpunit:app;use=run")
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")

phpunit_use=$(echo "$json" | jq -r '.tools.phpunit.use')
assert_eq "tools phpunit use=run" "run" "$phpunit_use"

# 5. path appears only when specified
reset_xcind_state
XCIND_TOOLS=("php:app" "php85:app;path=/usr/local/bin/php8.5")
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")

php_has_path=$(echo "$json" | jq 'has("tools") and (.tools.php | has("path"))')
assert_eq "tools php has no path key" "false" "$php_has_path"

php85_path=$(echo "$json" | jq -r '.tools.php85.path')
assert_eq "tools php85 path" "/usr/local/bin/php8.5" "$php85_path"

# 6. Duplicate tool names → first wins
reset_xcind_state
XCIND_TOOLS=("php:app" "php:cron")
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")

dup_service=$(echo "$json" | jq -r '.tools.php.service')
assert_eq "tools duplicate first wins service" "app" "$dup_service"

dup_count=$(echo "$json" | jq '.tools | length')
assert_eq "tools duplicate count is 1" "1" "$dup_count"

# 7. Multiple metadata key=value pairs
reset_xcind_state
XCIND_TOOLS=("php:app;use=run;path=/usr/bin/php")
__xcind-load-config "$TOOLS_APP"
__xcind-build-compose-opts "$TOOLS_APP"
json=$(__xcind-resolve-json "$TOOLS_APP")

multi_use=$(echo "$json" | jq -r '.tools.php.use')
assert_eq "tools multi-meta use" "run" "$multi_use"

multi_path=$(echo "$json" | jq -r '.tools.php.path')
assert_eq "tools multi-meta path" "/usr/bin/php" "$multi_path"

# 8. SHA changes when XCIND_TOOLS changes
reset_xcind_state
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
reset_xcind_state

# ======================================================================
echo ""
echo "=== Test: xcind-app-hook ==="

APP_HOOK_DIR=$(mktemp_d)
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
skip_err_file=$(mktemp)
skip_output=$(xcind-app-hook "$APP_HOOK_DIR" 2>"$skip_err_file")
skip_err=$(<"$skip_err_file")
rm -f "$skip_err_file"
assert_eq "app hook skips when no resolved-config" "" "$skip_output"
assert_contains "app hook warns about missing resolved-config" \
  "resolved-config.yaml not found" "$skip_err"
assert_eq "no compose.app.yaml when skipped" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.app.yaml" ] && echo true || echo false)"

rm -rf "$APP_HOOK_DIR"

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook no-op when disabled ==="

HGW_NOOP=$(mktemp_d)
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

HGW_EMPTY=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook generates for all services ==="

HGW_ALL=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook skips services with existing mapping ==="

HGW_SKIP=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook skips all when all have mapping ==="

HGW_ALLSKIP=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook preserves existing extra_hosts ==="

HGW_MERGE=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-host-gateway-hook uses XCIND_HOST_GATEWAY override ==="

HGW_OVERRIDE=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: __xcind-detect-host-gateway defaults to host-gateway ==="

# On non-WSL2 Linux (the CI environment), should return "host-gateway"
if ! grep -qi microsoft /proc/version 2>/dev/null; then
  # Not WSL2 and not Docker Desktop (CI) — should get "host-gateway"
  unset XCIND_HOST_GATEWAY
  detect_err_file=$(mktemp)
  detected=$(__xcind-detect-host-gateway 2>"$detect_err_file" || true)
  detect_err=$(<"$detect_err_file")
  rm -f "$detect_err_file"
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
    [ -n "$detect_err" ] && echo "    stderr: $detect_err"
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

HGW_EQ=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: __xcind-detect-host-gateway-wsl2 mirrored mode returns LAN IP ==="

# Mock wslinfo and hostname to simulate WSL2 mirrored mode
MOCK_BIN=$(mktemp_d)
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
echo ""
echo "=== Test: workspace registry — __xcind-registry-add idempotent ==="

reg_tmp=$(mktemp_d)
XDG_STATE_HOME="$reg_tmp" \
  XCIND_REGISTRY_DIR="$reg_tmp/xcind" \
  XCIND_REGISTRY_FILE="$reg_tmp/xcind/workspaces.tsv" \
  XCIND_REGISTRY_LOCK="$reg_tmp/xcind/workspaces.lock"

# Module globals need to be rebound so the freshly-set XDG_STATE_HOME
# takes effect for subsequent calls in this section.
XCIND_REGISTRY_DIR="$reg_tmp/xcind"
XCIND_REGISTRY_FILE="$reg_tmp/xcind/workspaces.tsv"
XCIND_REGISTRY_LOCK="$reg_tmp/xcind/workspaces.lock"

ws1="$reg_tmp/ws1"
mkdir -p "$ws1"
echo 'XCIND_IS_WORKSPACE=1' >"$ws1/.xcind.sh"

__xcind-with-registry-lock __xcind-registry-add "$ws1"
rows=$(grep -cv '^#' "$XCIND_REGISTRY_FILE" | tr -d '[:space:]')
assert_eq "add writes one data row" "1" "$rows"

__xcind-with-registry-lock __xcind-registry-add "$ws1"
rows=$(grep -cv '^#' "$XCIND_REGISTRY_FILE" | tr -d '[:space:]')
assert_eq "re-add is idempotent" "1" "$rows"

ws2="$reg_tmp/ws2"
mkdir -p "$ws2"
echo 'XCIND_IS_WORKSPACE=1' >"$ws2/.xcind.sh"
__xcind-with-registry-lock __xcind-registry-add "$ws2"
rows=$(grep -cv '^#' "$XCIND_REGISTRY_FILE" | tr -d '[:space:]')
assert_eq "second distinct add increments rows" "2" "$rows"

# ======================================================================
echo ""
echo "=== Test: workspace registry — remove and prune ==="

__xcind-with-registry-lock __xcind-registry-remove "$ws1"
rows=$(grep -cv '^#' "$XCIND_REGISTRY_FILE" | tr -d '[:space:]')
assert_eq "remove drops matching row" "1" "$rows"
# Remaining row is ws2
assert_contains "ws2 still present" "$ws2" "$(cat "$XCIND_REGISTRY_FILE")"

# Put ws1 back and make it stale, then prune.
__xcind-with-registry-lock __xcind-registry-add "$ws1"
rm -rf "$ws1"
pruned=$(__xcind-with-registry-lock __xcind-registry-prune | tr -d '[:space:]')
assert_eq "prune returns count" "1" "$pruned"
rows=$(grep -cv '^#' "$XCIND_REGISTRY_FILE" | tr -d '[:space:]')
assert_eq "prune drops stale row" "1" "$rows"

# Path that exists but isn't a workspace is also stale.
not_ws="$reg_tmp/not-a-workspace"
mkdir -p "$not_ws"
__xcind-with-registry-lock __xcind-registry-add "$not_ws"
pruned=$(__xcind-with-registry-lock __xcind-registry-prune | tr -d '[:space:]')
assert_eq "prune drops non-workspace dir" "1" "$pruned"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace init auto-registers ==="

init_tmp=$(mktemp_d)
init_ws="$init_tmp/dev"
XDG_STATE_HOME="$init_tmp/state" \
  "$XCIND_ROOT/bin/xcind-workspace" init "$init_ws" \
  --name dev-ws --proxy-domain dev.localhost >/dev/null
tsv="$init_tmp/state/xcind/workspaces.tsv"
assert_file_exists "init created the registry file" "$tsv"
assert_contains "init registered the workspace path" "$init_ws" "$(cat "$tsv")"

# Re-running init should not duplicate the row.
XDG_STATE_HOME="$init_tmp/state" \
  "$XCIND_ROOT/bin/xcind-workspace" init "$init_ws" >/dev/null
rows=$(grep -cv '^#' "$tsv" | tr -d '[:space:]')
assert_eq "re-init does not duplicate" "1" "$rows"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace list (text, JSON, stale, --prune) ==="

list_tmp=$(mktemp_d)
list_state="$list_tmp/state"
ws_a="$list_tmp/ws-a"
ws_b="$list_tmp/ws-b"

XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" init "$ws_a" \
  --name demo-a --proxy-domain a.local >/dev/null
XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" init "$ws_b" \
  --name demo-b >/dev/null

# Two apps under ws_a; one under ws_b.
mkdir -p "$ws_a/app1" "$ws_a/app2" "$ws_b/svc"
echo '# app config' >"$ws_a/app1/.xcind.sh"
echo '# app config' >"$ws_a/app2/.xcind.sh"
echo '# app config' >"$ws_b/svc/.xcind.sh"

list_out=$(XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" list)
assert_contains "list shows demo-a" "demo-a" "$list_out"
assert_contains "list shows demo-b" "demo-b" "$list_out"
assert_contains "list shows a.local domain" "a.local" "$list_out"
assert_contains "list shows ws_a path" "$ws_a" "$list_out"

json_out=$(XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" list --json)
apps_a=$(echo "$json_out" | jq -r '.workspaces[] | select(.name == "demo-a") | .apps')
assert_eq "json reports 2 apps for demo-a" "2" "$apps_a"
apps_b=$(echo "$json_out" | jq -r '.workspaces[] | select(.name == "demo-b") | .apps')
assert_eq "json reports 1 app for demo-b" "1" "$apps_b"
stale_count=$(echo "$json_out" | jq -r '.stale_count')
assert_eq "json reports 0 stale" "0" "$stale_count"

# Delete ws_b; it becomes stale.
rm -rf "$ws_b"
stale_out=$(XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" list)
assert_not_contains "list hides stale demo-b" "demo-b" "$stale_out"
assert_contains "list surfaces stale count" "1 stale entry" "$stale_out"

# TSV still contains the stale path.
stale_tsv="$list_state/xcind/workspaces.tsv"
assert_contains "stale entry still in TSV" "$ws_b" "$(cat "$stale_tsv")"

# --prune removes the stale entry.
XDG_STATE_HOME="$list_state" \
  "$XCIND_ROOT/bin/xcind-workspace" list --prune >/dev/null
assert_not_contains "prune removes stale from TSV" "$ws_b" "$(cat "$stale_tsv")"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace register / forget ==="

rf_tmp=$(mktemp_d)
rf_state="$rf_tmp/state"
good_ws="$rf_tmp/good"
bad_dir="$rf_tmp/bad"
mkdir -p "$good_ws" "$bad_dir"
echo 'XCIND_IS_WORKSPACE=1' >"$good_ws/.xcind.sh"
echo '# not a workspace' >"$bad_dir/.xcind.sh"

register_status=$(XDG_STATE_HOME="$rf_state" capture_status \
  "$XCIND_ROOT/bin/xcind-workspace" register "$bad_dir")
assert_eq "register rejects non-workspace" "1" "$register_status"

XDG_STATE_HOME="$rf_state" \
  "$XCIND_ROOT/bin/xcind-workspace" register "$good_ws" >/dev/null
rf_tsv="$rf_state/xcind/workspaces.tsv"
assert_contains "register adds workspace" "$good_ws" "$(cat "$rf_tsv")"

# forget a moved/deleted workspace by path (directory doesn't need to exist).
rm -rf "$good_ws"
XDG_STATE_HOME="$rf_state" \
  "$XCIND_ROOT/bin/xcind-workspace" forget "$good_ws" >/dev/null
assert_not_contains "forget removes entry for deleted dir" "$good_ws" "$(cat "$rf_tsv")"

# ======================================================================
echo ""
echo "=== Test: registry write failure does not break init ==="

fail_tmp=$(mktemp_d)
# A regular file can't host subdirs; mkdir -p underneath it fails. This
# exercises the silent-failure contract for registry writes.
touch "$fail_tmp/blocker"
XDG_STATE_HOME="$fail_tmp/blocker/nowhere" \
  "$XCIND_ROOT/bin/xcind-workspace" init "$fail_tmp/ws" \
  --name demo >/dev/null 2>&1
init_rc=$?
assert_eq "init returns 0 despite registry failure" "0" "$init_rc"
assert_file_exists "init still wrote .xcind.sh" "$fail_tmp/ws/.xcind.sh"

# ======================================================================
echo ""
echo "=== Test: __xcind-discover-workspace auto-registers ==="

disc_tmp=$(mktemp_d)
disc_state="$disc_tmp/state"
disc_ws="$disc_tmp/myws"
disc_app="$disc_ws/api"
mkdir -p "$disc_app"
echo 'XCIND_IS_WORKSPACE=1' >"$disc_ws/.xcind.sh"
echo '# app config' >"$disc_app/.xcind.sh"

# Run discovery in a subshell so XCIND_* global mutations don't bleed
# into later tests. Rebind registry constants to the per-test state dir
# (read by the registry lib; exports silence SC2034).
(
  export XDG_STATE_HOME="$disc_state"
  export XCIND_REGISTRY_DIR="$disc_state/xcind"
  export XCIND_REGISTRY_FILE="$disc_state/xcind/workspaces.tsv"
  export XCIND_REGISTRY_LOCK="$disc_state/xcind/workspaces.lock"
  reset_xcind_state
  __xcind-discover-workspace "$disc_app"
)

disc_tsv="$disc_state/xcind/workspaces.tsv"
assert_file_exists "discovery created registry file" "$disc_tsv"
assert_contains "discovery registered workspace root" "$disc_ws" "$(cat "$disc_tsv")"

# ======================================================================
echo ""
echo "=== Test: xcind-application init CLI ==="

# Plain init scaffolds .xcind.sh with default compose files
APP_PLAIN=$(mktemp_d)
app_init_out=$("$XCIND_ROOT/bin/xcind-application" init "$APP_PLAIN/demo")
assert_file_exists "plain init: .xcind.sh created" "$APP_PLAIN/demo/.xcind.sh"
app_content=$(<"$APP_PLAIN/demo/.xcind.sh")
assert_contains "plain init: XCIND_COMPOSE_FILES set" 'XCIND_COMPOSE_FILES=' "$app_content"
assert_not_contains "plain init: no XCIND_IS_WORKSPACE" "XCIND_IS_WORKSPACE" "$app_content"
assert_contains "plain init: reports target path" "$APP_PLAIN/demo" "$app_init_out"

# --name flag persists XCIND_APP
APP_NAMED=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-application" init "$APP_NAMED/svc" --name "custom" >/dev/null
app_content=$(<"$APP_NAMED/svc/.xcind.sh")
assert_contains "--name: XCIND_APP persisted" 'XCIND_APP="custom"' "$app_content"

# Idempotent init: second run without flags preserves existing config
content_before=$(<"$APP_NAMED/svc/.xcind.sh")
idem_out=$("$XCIND_ROOT/bin/xcind-application" init "$APP_NAMED/svc")
content_after=$(<"$APP_NAMED/svc/.xcind.sh")
assert_eq "idempotent: file unchanged on re-init" "$content_before" "$content_after"
assert_contains "idempotent: reports already-initialized" "already initialized" "$idem_out"

# Re-init with --name rewrites XCIND_APP
"$XCIND_ROOT/bin/xcind-application" init "$APP_NAMED/svc" --name "renamed" >/dev/null
app_content=$(<"$APP_NAMED/svc/.xcind.sh")
assert_contains "--name update: XCIND_APP rewritten" 'XCIND_APP="renamed"' "$app_content"

# Init refuses to overwrite a workspace config
APP_WS=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$APP_WS" >/dev/null 2>&1
ws_conflict_status=$(capture_status "$XCIND_ROOT/bin/xcind-application" init "$APP_WS")
assert_eq "init over workspace: exits 1" "1" "$ws_conflict_status"

# Init inside a workspace mentions the workspace name in the confirmation
APP_NESTED=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$APP_NESTED" --name "nestedws" >/dev/null 2>&1
nested_out=$("$XCIND_ROOT/bin/xcind-application" init "$APP_NESTED/myapp" 2>/dev/null)
assert_contains "nested init: mentions workspace name" "workspace: nestedws" "$nested_out"

# Unknown flag fails
app_unk_status=$(capture_status "$XCIND_ROOT/bin/xcind-application" init "$APP_PLAIN/demo2" --bogus)
assert_eq "unknown init flag: exits 1" "1" "$app_unk_status"

# --version short-circuits
app_ver_out=$("$XCIND_ROOT/bin/xcind-application" --version)
assert_contains "--version: prints xcind-application" "xcind-application" "$app_ver_out"

# --help prints usage
app_help_out=$("$XCIND_ROOT/bin/xcind-application" --help)
assert_contains "--help: lists init" "init [DIR]" "$app_help_out"
assert_contains "--help: lists status" "status [DIR]" "$app_help_out"
assert_contains "--help: lists list" "list [DIR]" "$app_help_out"

# No arguments prints help
app_noargs_out=$("$XCIND_ROOT/bin/xcind-application")
assert_contains "no args: prints help" "Usage: xcind-application" "$app_noargs_out"

# Unknown subcommand fails
app_badcmd_status=$(capture_status "$XCIND_ROOT/bin/xcind-application" bogus)
assert_eq "unknown subcommand: exits 1" "1" "$app_badcmd_status"

rm -rf "$APP_PLAIN" "$APP_NAMED" "$APP_WS" "$APP_NESTED"

# ======================================================================
echo ""
echo "=== Test: xcind-application list CLI ==="

APP_LIST_WS=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$APP_LIST_WS" --name "listws" >/dev/null 2>&1
"$XCIND_ROOT/bin/xcind-application" init "$APP_LIST_WS/alpha" >/dev/null
"$XCIND_ROOT/bin/xcind-application" init "$APP_LIST_WS/beta" >/dev/null

list_text=$("$XCIND_ROOT/bin/xcind-application" list "$APP_LIST_WS")
assert_contains "list text: shows header" "NAME" "$list_text"
assert_contains "list text: shows alpha" "alpha" "$list_text"
assert_contains "list text: shows beta" "beta" "$list_text"
assert_contains "list text: shows workspace" "listws" "$list_text"

# --json output
list_json=$("$XCIND_ROOT/bin/xcind-application" list "$APP_LIST_WS" --json)
# Parseable JSON
printf '%s' "$list_json" | jq . >/dev/null && list_json_rc=0 || list_json_rc=$?
assert_eq "list --json: parseable JSON" "0" "$list_json_rc"
list_json_ws=$(printf '%s' "$list_json" | jq -r '.workspace')
assert_eq "list --json: workspace name" "listws" "$list_json_ws"
list_json_count=$(printf '%s' "$list_json" | jq -r '.applications | length')
assert_eq "list --json: two applications" "2" "$list_json_count"

# List from inside a subdirectory of the workspace still returns the
# workspace's apps (walks up to find the enclosing workspace).
list_nested=$("$XCIND_ROOT/bin/xcind-application" list "$APP_LIST_WS/alpha")
assert_contains "list from app dir: shows siblings" "beta" "$list_nested"

# Hidden directories and nested workspaces must NOT appear as apps.
mkdir -p "$APP_LIST_WS/.git"
echo '# not an xcind config' >"$APP_LIST_WS/.git/ignored"
mkdir -p "$APP_LIST_WS/inner"
echo 'XCIND_IS_WORKSPACE=1' >"$APP_LIST_WS/inner/.xcind.sh"

list_filtered=$("$XCIND_ROOT/bin/xcind-application" list "$APP_LIST_WS")
assert_not_contains "list: hidden dirs hidden" ".git" "$list_filtered"
assert_not_contains "list: nested workspaces hidden" "inner" "$list_filtered"

# Standalone fallback: list against a directory whose .xcind.sh is an app
# config not inside any workspace returns a single-row list.
APP_SOLO=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-application" init "$APP_SOLO/lone" >/dev/null
solo_json=$("$XCIND_ROOT/bin/xcind-application" list "$APP_SOLO/lone" --json)
solo_count=$(printf '%s' "$solo_json" | jq -r '.applications | length')
assert_eq "list solo: single row" "1" "$solo_count"
solo_ws=$(printf '%s' "$solo_json" | jq -r '.workspace')
assert_eq "list solo: null workspace" "null" "$solo_ws"

# List against a directory with nothing underneath produces an empty/"no
# applications" message in text mode.
APP_EMPTY=$(mktemp_d)
empty_out=$("$XCIND_ROOT/bin/xcind-application" list "$APP_EMPTY")
assert_contains "list empty: reports no applications" "No applications" "$empty_out"

rm -rf "$APP_LIST_WS" "$APP_SOLO" "$APP_EMPTY"

# ======================================================================
echo ""
echo "=== Test: xcind-application status CLI ==="

APP_STATUS_WS=$(mktemp_d)
APP_STATUS_HOME=$(mktemp_d)
_app_status_orig_HOME="$HOME"
_app_status_orig_PATH="$PATH"
export HOME="$APP_STATUS_HOME"
mkdir -p "$APP_STATUS_HOME/bin"
cat >"$APP_STATUS_HOME/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker for application status tests: report nothing running, and
# synthesize `docker compose config` output so the xcind pipeline can
# populate its cache without a real docker engine.
case "$1" in
ps) echo "" ;;
inspect) exit 1 ;;
compose)
  shift
  # Scan remaining args for the `config` subcommand.
  for _arg in "$@"; do
    if [ "$_arg" = "config" ]; then
      echo 'services:'
      echo '  web:'
      echo '    image: nginx'
      echo '  db:'
      echo '    image: postgres'
      exit 0
    fi
  done
  exit 0
  ;;
*) exit 0 ;;
esac
MOCKEOF
chmod +x "$APP_STATUS_HOME/bin/docker"
export PATH="$APP_STATUS_HOME/bin:$_app_status_orig_PATH"

"$XCIND_ROOT/bin/xcind-workspace" init "$APP_STATUS_WS" --name "stws" >/dev/null 2>&1
"$XCIND_ROOT/bin/xcind-application" init "$APP_STATUS_WS/webapp" >/dev/null
cat >"$APP_STATUS_WS/webapp/compose.yaml" <<'COMPOSEEOF'
services:
  web:
    image: nginx
  db:
    image: postgres
COMPOSEEOF

status_out=$("$XCIND_ROOT/bin/xcind-application" status "$APP_STATUS_WS/webapp" 2>&1)
assert_contains "status text: Application header" "Application: webapp" "$status_out"
assert_contains "status text: Workspace line" "Workspace:" "$status_out"
assert_contains "status text: Services header" "Services:" "$status_out"
assert_contains "status text: lists web service" "web" "$status_out"
assert_contains "status text: lists db service" "db" "$status_out"
assert_contains "status text: summary line" "0/2 services running" "$status_out"

# --json output
status_json=$("$XCIND_ROOT/bin/xcind-application" status "$APP_STATUS_WS/webapp" --json 2>&1)
printf '%s' "$status_json" | jq . >/dev/null && status_json_rc=0 || status_json_rc=$?
assert_eq "status --json: parseable" "0" "$status_json_rc"
status_app=$(printf '%s' "$status_json" | jq -r '.app')
assert_eq "status --json: app name" "webapp" "$status_app"
status_total=$(printf '%s' "$status_json" | jq -r '.total')
assert_eq "status --json: two defined services" "2" "$status_total"
status_running=$(printf '%s' "$status_json" | jq -r '.running')
assert_eq "status --json: zero running" "0" "$status_running"

# Status from inside the app's own directory (no DIR arg) must work, since
# __xcind-application-find-root walks up from $PWD.
status_cwd_out=$(cd "$APP_STATUS_WS/webapp" && "$XCIND_ROOT/bin/xcind-application" status 2>&1)
assert_contains "status cwd: Application header" "Application: webapp" "$status_cwd_out"

# Status outside any app fails
APP_STATUS_OUTSIDE=$(mktemp_d)
status_outside_status=$(capture_status "$XCIND_ROOT/bin/xcind-application" status "$APP_STATUS_OUTSIDE")
assert_eq "status outside app: exits 1" "1" "$status_outside_status"

# Status on a missing directory fails
status_missing_status=$(capture_status "$XCIND_ROOT/bin/xcind-application" status "/nonexistent/does-not-exist-xcind-app")
assert_eq "status missing dir: exits 1" "1" "$status_missing_status"

export HOME="$_app_status_orig_HOME"
export PATH="$_app_status_orig_PATH"
unset _app_status_orig_HOME _app_status_orig_PATH
rm -rf "$APP_STATUS_WS" "$APP_STATUS_HOME" "$APP_STATUS_OUTSIDE"

# ======================================================================
# Cleanup
rm -rf "$MOCK_APP"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
