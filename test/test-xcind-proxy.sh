#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2154,SC2329
# test-xcind-proxy.sh — Verify xcind-proxy CLI and hook libraries
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

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file not found: $path)"
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
    FAIL=$((FAIL + 1))
  fi
}

# ======================================================================
echo "=== Test: xcind-proxy init (mock HOME) ==="

# Use a temp dir as HOME to avoid touching real config
REAL_HOME="$HOME"
MOCK_HOME=$(mktemp -d)
export HOME="$MOCK_HOME"

# Mock docker command to avoid real Docker calls
REAL_PATH="$PATH"
export PATH="$MOCK_HOME/bin:$PATH"
mkdir -p "$MOCK_HOME/bin"
cat >"$MOCK_HOME/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker — accept network create silently
exit 0
MOCKEOF
chmod +x "$MOCK_HOME/bin/docker"

"$XCIND_ROOT/bin/xcind-proxy" init

PROXY_CONFIG_DIR="${MOCK_HOME}/.config/xcind/proxy"
PROXY_STATE_DIR="${MOCK_HOME}/.local/state/xcind/proxy"

assert_file_exists "config.sh created" "$PROXY_CONFIG_DIR/config.sh"
assert_file_exists "docker-compose.yaml created" "$PROXY_STATE_DIR/docker-compose.yaml"
assert_file_exists "traefik.yaml created" "$PROXY_STATE_DIR/traefik.yaml"

# Verify generated files are NOT in config dir (migration cleanup)
assert_eq "no docker-compose.yaml in config dir" "false" "$([ -f "$PROXY_CONFIG_DIR/docker-compose.yaml" ] && echo true || echo false)"
assert_eq "no traefik.yaml in config dir" "false" "$([ -f "$PROXY_CONFIG_DIR/traefik.yaml" ] && echo true || echo false)"

# Verify config.sh contents
config_content=$(<"$PROXY_CONFIG_DIR/config.sh")
assert_contains "config has XCIND_PROXY_DOMAIN" "XCIND_PROXY_DOMAIN" "$config_content"
assert_contains "config has XCIND_PROXY_IMAGE" "XCIND_PROXY_IMAGE" "$config_content"
assert_contains "config has XCIND_PROXY_HTTP_PORT" "XCIND_PROXY_HTTP_PORT" "$config_content"

# Verify docker-compose.yaml contents
compose_content=$(<"$PROXY_STATE_DIR/docker-compose.yaml")
assert_contains "compose has traefik service" "traefik:" "$compose_content"
assert_contains "compose has xcind-proxy network" "xcind-proxy:" "$compose_content"
assert_contains "compose has external network" "external: true" "$compose_content"
assert_contains "compose has docker socket volume" "/var/run/docker.sock" "$compose_content"

# Verify traefik.yaml contents
traefik_content=$(<"$PROXY_STATE_DIR/traefik.yaml")
assert_contains "traefik has web entrypoint" "web:" "$traefik_content"
assert_contains "traefik has docker provider" "docker:" "$traefik_content"
assert_contains "traefik has exposedByDefault false" "exposedByDefault: false" "$traefik_content"

# Test idempotency — config values should be preserved on re-init
"$XCIND_ROOT/bin/xcind-proxy" init
config_after=$(<"$PROXY_CONFIG_DIR/config.sh")
assert_contains "config values preserved on re-init" "XCIND_PROXY_DOMAIN" "$config_after"

export HOME="$REAL_HOME"
export PATH="$REAL_PATH"
rm -rf "$MOCK_HOME"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy init flags ==="

MOCK_HOME2=$(mktemp -d)
export HOME="$MOCK_HOME2"
export PATH="$MOCK_HOME2/bin:$REAL_PATH"
mkdir -p "$MOCK_HOME2/bin"
cat >"$MOCK_HOME2/bin/docker" <<'MOCKEOF'
#!/bin/sh
exit 0
MOCKEOF
chmod +x "$MOCK_HOME2/bin/docker"

PROXY_CONFIG_DIR2="${MOCK_HOME2}/.config/xcind/proxy"
PROXY_STATE_DIR2="${MOCK_HOME2}/.local/state/xcind/proxy"

# Test: init with --proxy-domain flag creates config with that domain
"$XCIND_ROOT/bin/xcind-proxy" init --proxy-domain xcind.localhost
config2=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "flag: proxy-domain set" 'XCIND_PROXY_DOMAIN="xcind.localhost"' "$config2"
assert_contains "flag: other defaults preserved (image)" 'XCIND_PROXY_IMAGE="traefik:v3"' "$config2"
assert_contains "flag: other defaults preserved (port)" 'XCIND_PROXY_HTTP_PORT="80"' "$config2"

# Test: re-init with --http-port changes only port, preserves domain
"$XCIND_ROOT/bin/xcind-proxy" init --http-port 8081
config3=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "flag: http-port updated" 'XCIND_PROXY_HTTP_PORT="8081"' "$config3"
assert_contains "flag: domain preserved" 'XCIND_PROXY_DOMAIN="xcind.localhost"' "$config3"

# Test: multiple flags in one invocation
"$XCIND_ROOT/bin/xcind-proxy" init --image traefik:v3.2 --dashboard true --dashboard-port 9090
config4=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "multi-flag: image updated" 'XCIND_PROXY_IMAGE="traefik:v3.2"' "$config4"
assert_contains "multi-flag: dashboard enabled" 'XCIND_PROXY_DASHBOARD="true"' "$config4"
assert_contains "multi-flag: dashboard-port updated" 'XCIND_PROXY_DASHBOARD_PORT="9090"' "$config4"
assert_contains "multi-flag: domain still preserved" 'XCIND_PROXY_DOMAIN="xcind.localhost"' "$config4"
assert_contains "multi-flag: port still preserved" 'XCIND_PROXY_HTTP_PORT="8081"' "$config4"

# Test: re-init with no flags preserves all values
"$XCIND_ROOT/bin/xcind-proxy" init
config5=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "no-flag reinit: domain preserved" 'XCIND_PROXY_DOMAIN="xcind.localhost"' "$config5"
assert_contains "no-flag reinit: port preserved" 'XCIND_PROXY_HTTP_PORT="8081"' "$config5"
assert_contains "no-flag reinit: image preserved" 'XCIND_PROXY_IMAGE="traefik:v3.2"' "$config5"

# Test: generated docker-compose.yaml reflects updated config
compose2=$(<"$PROXY_STATE_DIR2/docker-compose.yaml")
assert_contains "compose reflects updated port" "8081:80" "$compose2"
assert_contains "compose reflects updated image" "traefik:v3.2" "$compose2"

export HOME="$REAL_HOME"
export PATH="$REAL_PATH"
rm -rf "$MOCK_HOME2"

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-ensure-running ==="

MOCK_HOME2=$(mktemp -d)
REAL_HOME2="$HOME"
export HOME="$MOCK_HOME2"
# Re-derive proxy paths from new HOME
XCIND_PROXY_CONFIG_DIR="${HOME}/.config/xcind/proxy"
XCIND_PROXY_STATE_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_PROXY_DIR="$XCIND_PROXY_CONFIG_DIR"
XCIND_PROXY_COMPOSE="${XCIND_PROXY_STATE_DIR}/docker-compose.yaml"

# Track which docker commands were called
DOCKER_CALLS_FILE="$MOCK_HOME2/docker_calls.log"

# Mock docker with call tracking
# shellcheck disable=SC2317
docker() {
  echo "$*" >>"$DOCKER_CALLS_FILE"
  # "docker ps" returns empty = not running
  if [ "${1:-}" = "ps" ]; then
    echo ""
    return 0
  fi
  # "docker compose ... up -d" succeeds
  if [ "${1:-}" = "compose" ]; then
    return 0
  fi
  # network operations succeed
  if [ "${1:-}" = "network" ]; then
    return 0
  fi
  return 0
}

# Test: ensure-running auto-inits and starts when nothing exists
: >"$DOCKER_CALLS_FILE"
# shellcheck disable=SC2218
__xcind-proxy-ensure-running 2>/dev/null
assert_file_exists "ensure-running: config.sh created" "$MOCK_HOME2/.config/xcind/proxy/config.sh"
assert_file_exists "ensure-running: docker-compose.yaml created" "$MOCK_HOME2/.local/state/xcind/proxy/docker-compose.yaml"
assert_file_exists "ensure-running: traefik.yaml created" "$MOCK_HOME2/.local/state/xcind/proxy/traefik.yaml"
docker_calls=$(<"$DOCKER_CALLS_FILE")
assert_contains "ensure-running: called docker ps" "ps --filter" "$docker_calls"
assert_contains "ensure-running: called docker compose up" "compose" "$docker_calls"

# Test: ensure-running is no-op when proxy is already running
# shellcheck disable=SC2317
docker() {
  echo "$*" >>"$DOCKER_CALLS_FILE"
  if [ "${1:-}" = "ps" ]; then
    echo "abc123def456" # simulate running container
    return 0
  fi
  if [ "${1:-}" = "network" ]; then
    return 0
  fi
  return 0
}
: >"$DOCKER_CALLS_FILE"
# shellcheck disable=SC2218
__xcind-proxy-ensure-running 2>/dev/null
docker_calls=$(<"$DOCKER_CALLS_FILE")
assert_contains "ensure-running already-running: checked docker ps" "ps --filter" "$docker_calls"
assert_not_contains "ensure-running already-running: did not call compose up" "compose" "$docker_calls"

# Test: XCIND_PROXY_AUTO_START=0 skips everything except network
# shellcheck disable=SC2317
docker() {
  echo "$*" >>"$DOCKER_CALLS_FILE"
  if [ "${1:-}" = "network" ]; then
    return 0
  fi
  return 0
}
: >"$DOCKER_CALLS_FILE"
# shellcheck disable=SC2218
XCIND_PROXY_AUTO_START=0 __xcind-proxy-ensure-running 2>/dev/null
docker_calls=$(<"$DOCKER_CALLS_FILE")
assert_not_contains "auto-start=0: did not call docker ps" "ps --filter" "$docker_calls"
assert_not_contains "auto-start=0: did not call compose up" "compose" "$docker_calls"

# Test: staleness warning when config.sh is newer than generated files
# shellcheck disable=SC2317
docker() {
  echo "$*" >>"$DOCKER_CALLS_FILE"
  if [ "${1:-}" = "ps" ]; then
    echo "abc123def456" # simulate running container
    return 0
  fi
  if [ "${1:-}" = "network" ]; then
    return 0
  fi
  return 0
}
: >"$DOCKER_CALLS_FILE"
# Touch config.sh to be newer than docker-compose.yaml
sleep 1
touch "$XCIND_PROXY_CONFIG_DIR/config.sh"
staleness_stderr=$(__xcind-proxy-ensure-running 2>&1 1>/dev/null)
assert_contains "staleness: warns when config.sh is newer" "config.sh changed; run 'xcind-proxy up' to apply" "$staleness_stderr"

unset -f docker
export HOME="$REAL_HOME2"
XCIND_PROXY_CONFIG_DIR="${HOME}/.config/xcind/proxy"
XCIND_PROXY_STATE_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_PROXY_DIR="$XCIND_PROXY_CONFIG_DIR"
XCIND_PROXY_COMPOSE="${XCIND_PROXY_STATE_DIR}/docker-compose.yaml"
rm -rf "$MOCK_HOME2"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy version ==="

version_output=$("$XCIND_ROOT/bin/xcind-proxy" --version)
assert_contains "version output has xcind-proxy" "xcind-proxy" "$version_output"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy help ==="

help_output=$("$XCIND_ROOT/bin/xcind-proxy" --help)
assert_contains "help mentions init" "init" "$help_output"
assert_contains "help mentions up" "up" "$help_output"
assert_contains "help mentions down" "down" "$help_output"
assert_contains "help mentions status" "status" "$help_output"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy unknown subcommand ==="

result=$("$XCIND_ROOT/bin/xcind-proxy" badcmd 2>&1) && status=0 || status=$?
assert_eq "unknown subcommand exits 1" "1" "$status"
assert_contains "unknown subcommand error message" "Unknown subcommand" "$result"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy no subcommand ==="

result=$("$XCIND_ROOT/bin/xcind-proxy" 2>&1) && status=0 || status=$?
assert_eq "no subcommand exits 0" "0" "$status"
assert_contains "no subcommand shows help" "Usage" "$result"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy status --json (not initialized) ==="

MOCK_HOME_JSON=$(mktemp -d)
REAL_HOME_JSON="$HOME"
export HOME="$MOCK_HOME_JSON"

json_result=$("$XCIND_ROOT/bin/xcind-proxy" status --json 2>&1) && json_status=0 || json_status=$?
assert_eq "status --json not initialized exits 0" "0" "$json_status"
assert_contains "json has initialized false" '"initialized":false' "$json_result"
assert_contains "json has not_initialized status" '"status":"not_initialized"' "$json_result"

export HOME="$REAL_HOME_JSON"
rm -rf "$MOCK_HOME_JSON"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy status --json (initialized) ==="

MOCK_HOME_JSON2=$(mktemp -d)
REAL_HOME_JSON2="$HOME"
export HOME="$MOCK_HOME_JSON2"

REAL_PATH_JSON2="$PATH"
export PATH="$MOCK_HOME_JSON2/bin:$PATH"
mkdir -p "$MOCK_HOME_JSON2/bin"
cat >"$MOCK_HOME_JSON2/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker — simulate running container for ps, accept network inspect
case "$1" in
  compose) echo '{"Name":"traefik"}' ;;
  network) exit 0 ;;
  *) exit 0 ;;
esac
MOCKEOF
chmod +x "$MOCK_HOME_JSON2/bin/docker"

"$XCIND_ROOT/bin/xcind-proxy" init >/dev/null

json_result2=$("$XCIND_ROOT/bin/xcind-proxy" status --json 2>&1) && json_status2=0 || json_status2=$?
assert_eq "status --json initialized exits 0" "0" "$json_status2"
assert_contains "json has initialized true" '"initialized":true' "$json_result2"
assert_contains "json has running status" '"status":"running"' "$json_result2"
assert_contains "json has config" '"config":"current"' "$json_result2"
assert_contains "json has image" '"image":"traefik:v3"' "$json_result2"
assert_contains "json has http_port" '"http_port":80' "$json_result2"
assert_contains "json has network_name" '"network_name":"xcind-proxy"' "$json_result2"
assert_contains "json has network_exists" '"network_exists":true' "$json_result2"

# Also verify text mode still works
text_result=$("$XCIND_ROOT/bin/xcind-proxy" status 2>&1) && text_status=0 || text_status=$?
assert_eq "status text exits 0" "0" "$text_status"
assert_contains "text has Status: running" "Status: running" "$text_result"
assert_contains "text has Image:" "Image:" "$text_result"

export HOME="$REAL_HOME_JSON2"
export PATH="$REAL_PATH_JSON2"
rm -rf "$MOCK_HOME_JSON2"

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-parse-entry ==="

# Format: "web" (export=service, no port)
__xcind-proxy-parse-entry "web"
assert_eq "parse 'web' export" "web" "$_export_name"
assert_eq "parse 'web' service" "web" "$_compose_service"
assert_eq "parse 'web' port" "" "$_port"

# Format: "api:3000" (export=service, explicit port)
__xcind-proxy-parse-entry "api:3000"
assert_eq "parse 'api:3000' export" "api" "$_export_name"
assert_eq "parse 'api:3000' service" "api" "$_compose_service"
assert_eq "parse 'api:3000' port" "3000" "$_port"

# Format: "db=postgres" (export!=service, no port)
__xcind-proxy-parse-entry "db=postgres"
assert_eq "parse 'db=postgres' export" "db" "$_export_name"
assert_eq "parse 'db=postgres' service" "postgres" "$_compose_service"
assert_eq "parse 'db=postgres' port" "" "$_port"

# Format: "db=postgres:5432" (export!=service, explicit port)
__xcind-proxy-parse-entry "db=postgres:5432"
assert_eq "parse 'db=postgres:5432' export" "db" "$_export_name"
assert_eq "parse 'db=postgres:5432' service" "postgres" "$_compose_service"
assert_eq "parse 'db=postgres:5432' port" "5432" "$_port"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy-hook (YAML generation) ==="

# These tests require yq
if command -v yq &>/dev/null; then
  HOOK_APP=$(mktemp -d)
  echo '# hook test' >"$HOOK_APP/.xcind.sh"

  # Sandbox HOME so __xcind-proxy-ensure-init never writes to the real home dir
  _orig_HOME="$HOME"
  HOME=$(mktemp -d)
  export XCIND_PROXY_CONFIG_DIR="${HOME}/.config/xcind/proxy"
  export XCIND_PROXY_STATE_DIR="${HOME}/.local/state/xcind/proxy"
  export XCIND_PROXY_DIR="$XCIND_PROXY_CONFIG_DIR"
  export XCIND_PROXY_COMPOSE="${XCIND_PROXY_STATE_DIR}/docker-compose.yaml"

  # Set up pipeline env vars
  export XCIND_APP="myapp"
  export XCIND_WORKSPACE=""
  export XCIND_WORKSPACE_ROOT=""
  export XCIND_WORKSPACELESS=1
  export XCIND_APP_URL_TEMPLATE='{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{app}-{export}-{protocol}'
  export XCIND_PROXY_DOMAIN="localhost"
  export XCIND_SHA="hooktest123"
  export XCIND_CACHE_DIR="$HOOK_APP/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$HOOK_APP/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  # Create a resolved-config.yaml with services
  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    ports:
      - target: 80
        published: "8080"
  api:
    image: node
    ports:
      - target: 3000
        published: "3001"
  postgres:
    image: postgres
    ports:
      - target: 5432
        published: "5433"
YAML

  # Mock docker to accept proxy lifecycle operations
  # shellcheck disable=SC2317  # invoked indirectly via xcind-proxy
  docker() {
    if [ "${1:-}" = "network" ]; then
      return 0
    fi
    # Mock "docker ps" for ensure-running check (simulate proxy not running)
    if [ "${1:-}" = "ps" ]; then
      echo ""
      return 0
    fi
    # Mock "docker compose ... up -d" for auto-start
    if [ "${1:-}" = "compose" ]; then
      return 0
    fi
    command docker "$@"
  }

  # Test: basic workspaceless generation
  XCIND_PROXY_EXPORTS=("web" "api:3000" "db=postgres:5432")
  hook_output=$(xcind-proxy-hook "$HOOK_APP")

  assert_contains "hook prints -f flag" "-f" "$hook_output"
  assert_contains "hook output has compose.proxy.yaml" "compose.proxy.yaml" "$hook_output"
  assert_file_exists "compose.proxy.yaml created" "$XCIND_GENERATED_DIR/compose.proxy.yaml"

  proxy_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
  assert_contains "yaml has web service" "web:" "$proxy_yaml"
  assert_contains "yaml has api service" "api:" "$proxy_yaml"
  assert_contains "yaml has postgres service" "postgres:" "$proxy_yaml"
  assert_contains "yaml has traefik.enable" "traefik.enable=true" "$proxy_yaml"
  assert_contains "yaml has myapp-web.localhost hostname" "myapp-web.localhost" "$proxy_yaml"
  assert_contains "yaml has myapp-api.localhost hostname" "myapp-api.localhost" "$proxy_yaml"
  assert_contains "yaml has myapp-db.localhost hostname" "myapp-db.localhost" "$proxy_yaml"
  assert_contains "yaml has myapp-web-http router" "myapp-web-http" "$proxy_yaml"
  assert_contains "yaml has port 80" "server.port=80" "$proxy_yaml"
  assert_contains "yaml has port 3000" "server.port=3000" "$proxy_yaml"
  assert_contains "yaml has port 5432" "server.port=5432" "$proxy_yaml"
  assert_not_contains "yaml has no xcind.app.name (moved to app hook)" "xcind.app.name" "$proxy_yaml"
  assert_contains "yaml has xcind.export.web.host" "xcind.export.web.host=myapp-web.localhost" "$proxy_yaml"
  assert_contains "yaml has xcind.export.db.host" "xcind.export.db.host=myapp-db.localhost" "$proxy_yaml"
  assert_contains "yaml has xcind-proxy network" "xcind-proxy:" "$proxy_yaml"
  assert_contains "yaml has external network" "external: true" "$proxy_yaml"

  # Test: workspace mode
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACE="dev"
  export XCIND_WORKSPACE_ROOT="/workspaces/dev"
  export XCIND_WORKSPACELESS=0
  export XCIND_APP_URL_TEMPLATE='{workspace}-{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{workspace}-{app}-{export}-{protocol}'

  XCIND_PROXY_EXPORTS=("web")
  xcind-proxy-hook "$HOOK_APP" >/dev/null

  proxy_yaml_ws=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
  assert_contains "workspace yaml has dev-myapp-web.localhost" "dev-myapp-web.localhost" "$proxy_yaml_ws"
  assert_not_contains "workspace yaml has no workspace.name (moved to ws hook)" "xcind.workspace.name" "$proxy_yaml_ws"
  assert_not_contains "workspace yaml has no workspace.path (moved to ws hook)" "xcind.workspace.path" "$proxy_yaml_ws"

  # Test: port inference (single port)
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACELESS=1
  export XCIND_APP_URL_TEMPLATE='{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{app}-{export}-{protocol}'

  XCIND_PROXY_EXPORTS=("web")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  proxy_yaml_infer=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
  assert_contains "inferred port 80 for web" "server.port=80" "$proxy_yaml_infer"

  # Test: empty exports = no output
  XCIND_PROXY_EXPORTS=()
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  empty_output=$(xcind-proxy-hook "$HOOK_APP")
  assert_eq "empty exports = no output" "" "$empty_output"

  # Test: unset XCIND_PROXY_EXPORTS = no output (guard against set -u abort)
  unset XCIND_PROXY_EXPORTS
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  unset_output=$(xcind-proxy-hook "$HOOK_APP")
  assert_eq "unset exports = no output" "" "$unset_output"

  # Test: multi-export grouping (two exports on same compose service)
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  nginx:
    image: nginx
    ports:
      - target: 80
        published: "8080"
      - target: 443
        published: "8443"
YAML

  XCIND_PROXY_EXPORTS=("web=nginx:80" "admin=nginx:443")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  grouped_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")

  # Should have only one "nginx:" block, not two
  nginx_count=$(echo "$grouped_yaml" | grep -c '  nginx:' || true)
  assert_eq "grouped: single nginx block" "1" "$nginx_count"
  assert_contains "grouped: web hostname" "myapp-web.localhost" "$grouped_yaml"
  assert_contains "grouped: admin hostname" "myapp-admin.localhost" "$grouped_yaml"

  # Test: apex URL — workspaceless, primary export gets apex
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACELESS=1
  export XCIND_APP_URL_TEMPLATE='{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{app}-{export}-{protocol}'
  export XCIND_APP_APEX_URL_TEMPLATE='{app}.{domain}'
  export XCIND_APEX_ROUTER_TEMPLATE='{app}-{protocol}'

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    ports:
      - target: 80
        published: "8080"
  api:
    image: node
    ports:
      - target: 3000
        published: "3001"
YAML

  XCIND_PROXY_EXPORTS=("web" "api:3000")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  apex_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")

  assert_contains "apex: primary has apex hostname" "myapp.localhost" "$apex_yaml"
  assert_contains "apex: primary has apex router rule" 'traefik.http.routers.myapp-http.rule=Host(`myapp.localhost`)' "$apex_yaml"
  assert_contains "apex: primary has xcind.apex.host" "xcind.apex.host=myapp.localhost" "$apex_yaml"
  assert_contains "apex: primary has xcind.apex.url" "xcind.apex.url=http://myapp.localhost" "$apex_yaml"
  assert_contains "apex: primary still has export hostname" "myapp-web.localhost" "$apex_yaml"

  # Extract api service block (from "  api:" to next service or end)
  api_block=$(echo "$apex_yaml" | sed -n '/^  api:/,/^  [a-z]/p' | head -n -1)
  assert_not_contains "apex: non-primary has no apex.host" "xcind.apex.host" "$api_block"
  assert_not_contains "apex: non-primary has no apex.url" "xcind.apex.url" "$api_block"

  # Test: apex disabled — empty template
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_APP_APEX_URL_TEMPLATE=""
  export XCIND_APEX_ROUTER_TEMPLATE=""

  XCIND_PROXY_EXPORTS=("web" "api:3000")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  noapex_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")

  assert_not_contains "apex disabled: no xcind.apex.host" "xcind.apex.host" "$noapex_yaml"
  assert_not_contains "apex disabled: no xcind.apex.url" "xcind.apex.url" "$noapex_yaml"
  assert_contains "apex disabled: still has export hostname" "myapp-web.localhost" "$noapex_yaml"

  # Test: apex URL — workspace mode
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACE="dev"
  export XCIND_WORKSPACE_ROOT="/workspaces/dev"
  export XCIND_WORKSPACELESS=0
  export XCIND_APP_URL_TEMPLATE='{workspace}-{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{workspace}-{app}-{export}-{protocol}'
  export XCIND_APP_APEX_URL_TEMPLATE='{workspace}-{app}.{domain}'
  export XCIND_APEX_ROUTER_TEMPLATE='{workspace}-{app}-{protocol}'

  XCIND_PROXY_EXPORTS=("web")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  ws_apex_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")

  assert_contains "apex ws: has dev-myapp.localhost" "dev-myapp.localhost" "$ws_apex_yaml"
  assert_contains "apex ws: has xcind.apex.host" "xcind.apex.host=dev-myapp.localhost" "$ws_apex_yaml"
  assert_not_contains "apex ws: no workspace.name (moved to ws hook)" "xcind.workspace.name" "$ws_apex_yaml"

  # Test: grouped exports with apex — two exports on same compose service
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACELESS=1
  export XCIND_WORKSPACE=""
  export XCIND_WORKSPACE_ROOT=""
  export XCIND_APP_URL_TEMPLATE='{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{app}-{export}-{protocol}'
  export XCIND_APP_APEX_URL_TEMPLATE='{app}.{domain}'
  export XCIND_APEX_ROUTER_TEMPLATE='{app}-{protocol}'

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  nginx:
    image: nginx
    ports:
      - target: 80
        published: "8080"
      - target: 443
        published: "8443"
YAML

  XCIND_PROXY_EXPORTS=("web=nginx:80" "admin=nginx:443")
  xcind-proxy-hook "$HOOK_APP" >/dev/null
  grouped_apex_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")

  nginx_count=$(echo "$grouped_apex_yaml" | grep -c '  nginx:' || true)
  assert_eq "apex grouped: single nginx block" "1" "$nginx_count"
  assert_contains "apex grouped: has web hostname" "myapp-web.localhost" "$grouped_apex_yaml"
  assert_contains "apex grouped: has admin hostname" "myapp-admin.localhost" "$grouped_apex_yaml"
  assert_contains "apex grouped: has apex hostname" "xcind.apex.host=myapp.localhost" "$grouped_apex_yaml"

  # Restore resolved-config for remaining tests
  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    ports:
      - target: 80
        published: "8080"
  api:
    image: node
    ports:
      - target: 3000
        published: "3001"
  postgres:
    image: postgres
    ports:
      - target: 5432
        published: "5433"
YAML

  # Test: service validation error
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  XCIND_PROXY_EXPORTS=("nonexistent")
  result=$(xcind-proxy-hook "$HOOK_APP" 2>&1) && status=0 || status=$?
  assert_eq "missing service exits non-zero" "1" "$status"
  assert_contains "missing service error message" "not found" "$result"

  # Test: XCIND_PROXY_AUTO_START=0 skips ensure-running but still generates YAML
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACELESS=1
  export XCIND_WORKSPACE=""
  export XCIND_WORKSPACE_ROOT=""
  export XCIND_APP_URL_TEMPLATE='{app}-{export}.{domain}'
  export XCIND_ROUTER_TEMPLATE='{app}-{export}-{protocol}'
  unset XCIND_APP_APEX_URL_TEMPLATE 2>/dev/null || true
  unset XCIND_APEX_ROUTER_TEMPLATE 2>/dev/null || true

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
    ports:
      - target: 80
        published: "8080"
YAML

  XCIND_PROXY_EXPORTS=("web")
  XCIND_PROXY_AUTO_START=0 xcind-proxy-hook "$HOOK_APP" >/dev/null
  assert_file_exists "auto-start=0: compose.proxy.yaml still created" "$XCIND_GENERATED_DIR/compose.proxy.yaml"
  auto_start_off_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
  assert_contains "auto-start=0: yaml has web service" "web:" "$auto_start_off_yaml"
  assert_contains "auto-start=0: yaml has traefik labels" "traefik.enable=true" "$auto_start_off_yaml"

  unset -f docker
  rm -rf "$HOOK_APP" "$HOME"
  HOME="$_orig_HOME"
  unset XCIND_PROXY_CONFIG_DIR XCIND_PROXY_STATE_DIR XCIND_PROXY_DIR XCIND_PROXY_COMPOSE _orig_HOME
else
  echo "  (skipped proxy hook tests: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-workspace-hook ==="

if command -v yq &>/dev/null; then
  WS_HOOK_APP=$(mktemp -d)
  echo '# ws hook test' >"$WS_HOOK_APP/.xcind.sh"

  export XCIND_APP="frontend"
  export XCIND_WORKSPACE="dev"
  export XCIND_WORKSPACE_ROOT="/workspaces/dev"
  export XCIND_WORKSPACELESS=0
  export XCIND_WORKSPACE_SERVICE_TEMPLATE='{app}-{service}'
  export XCIND_SHA="wshooktest"
  export XCIND_CACHE_DIR="$WS_HOOK_APP/.xcind/cache/$XCIND_SHA"
  export XCIND_GENERATED_DIR="$WS_HOOK_APP/.xcind/generated/$XCIND_SHA"
  mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

  cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  web:
    image: nginx
  worker:
    image: node
  postgres:
    image: postgres
YAML

  # Mock docker
  # shellcheck disable=SC2317  # invoked indirectly via xcind-workspace-hook
  docker() {
    if [ "${1:-}" = "network" ]; then
      return 0
    fi
    command docker "$@"
  }

  ws_output=$(xcind-workspace-hook "$WS_HOOK_APP")

  assert_contains "ws hook prints -f flag" "-f" "$ws_output"
  assert_file_exists "compose.workspace.yaml created" "$XCIND_GENERATED_DIR/compose.workspace.yaml"

  ws_yaml=$(<"$XCIND_GENERATED_DIR/compose.workspace.yaml")
  assert_contains "ws yaml has web service" "web:" "$ws_yaml"
  assert_contains "ws yaml has worker service" "worker:" "$ws_yaml"
  assert_contains "ws yaml has postgres service" "postgres:" "$ws_yaml"
  assert_contains "ws yaml has frontend-web alias" "frontend-web" "$ws_yaml"
  assert_contains "ws yaml has frontend-worker alias" "frontend-worker" "$ws_yaml"
  assert_contains "ws yaml has frontend-postgres alias" "frontend-postgres" "$ws_yaml"
  assert_contains "ws yaml has dev-internal network" "dev-internal:" "$ws_yaml"
  assert_contains "ws yaml has external network" "external: true" "$ws_yaml"
  assert_contains "ws yaml has xcind.workspace.name label" "xcind.workspace.name=dev" "$ws_yaml"
  assert_contains "ws yaml has xcind.workspace.path label" "xcind.workspace.path=/workspaces/dev" "$ws_yaml"

  # Test: custom service template
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACE_SERVICE_TEMPLATE='{workspace}-{app}-{service}'
  xcind-workspace-hook "$WS_HOOK_APP" >/dev/null
  ws_yaml_custom=$(<"$XCIND_GENERATED_DIR/compose.workspace.yaml")
  assert_contains "custom template: dev-frontend-web alias" "dev-frontend-web" "$ws_yaml_custom"

  # Test: skip when workspaceless
  rm -rf "$XCIND_GENERATED_DIR"
  mkdir -p "$XCIND_GENERATED_DIR"
  export XCIND_WORKSPACELESS=1
  skip_output=$(xcind-workspace-hook "$WS_HOOK_APP")
  assert_eq "skip when workspaceless" "" "$skip_output"

  unset -f docker
  rm -rf "$WS_HOOK_APP"
else
  echo "  (skipped workspace hook tests: yq not installed)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-workspace init ==="

WS_INIT_DIR=$(mktemp -d)

# Test: init creates directory and .xcind.sh
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/newws" >/dev/null
assert_file_exists "ws init creates .xcind.sh" "$WS_INIT_DIR/newws/.xcind.sh"
ws_config=$(<"$WS_INIT_DIR/newws/.xcind.sh")
assert_contains "ws init has XCIND_IS_WORKSPACE=1" "XCIND_IS_WORKSPACE=1" "$ws_config"

# Test: init with --proxy-domain
rm -rf "$WS_INIT_DIR/flagws"
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/flagws" --proxy-domain xcind.localhost >/dev/null
ws_config2=$(<"$WS_INIT_DIR/flagws/.xcind.sh")
assert_contains "ws init --proxy-domain" 'XCIND_PROXY_DOMAIN="xcind.localhost"' "$ws_config2"

# Test: init with --name
rm -rf "$WS_INIT_DIR/namews"
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/namews" --name myws >/dev/null
ws_config3=$(<"$WS_INIT_DIR/namews/.xcind.sh")
assert_contains "ws init --name" 'XCIND_WORKSPACE="myws"' "$ws_config3"

# Test: re-run with no flags prints "already initialized"
ws_reinit_out=$("$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/newws")
assert_contains "ws reinit no flags" "already initialized" "$ws_reinit_out"

# Test: re-run with --proxy-domain updates the file
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/newws" --proxy-domain new.localhost >/dev/null
ws_config4=$(<"$WS_INIT_DIR/newws/.xcind.sh")
assert_contains "ws reinit updates domain" 'XCIND_PROXY_DOMAIN="new.localhost"' "$ws_config4"

# Test: running from an app directory produces error
mkdir -p "$WS_INIT_DIR/appdir"
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$WS_INIT_DIR/appdir/.xcind.sh"
ws_app_err=$("$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/appdir" 2>&1 || true)
assert_contains "ws init from app dir: error" "app configuration" "$ws_app_err"

# Test: running from app inside workspace reports already initialized
mkdir -p "$WS_INIT_DIR/existingws/myapp"
echo 'XCIND_IS_WORKSPACE=1' >"$WS_INIT_DIR/existingws/.xcind.sh"
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$WS_INIT_DIR/existingws/myapp/.xcind.sh"
ws_nested_err=$("$XCIND_ROOT/bin/xcind-workspace" init "$WS_INIT_DIR/existingws/myapp" 2>&1 || true)
assert_contains "ws init from app in workspace: mentions workspace" "already initialized" "$ws_nested_err"

# Test: version flag
ws_ver=$("$XCIND_ROOT/bin/xcind-workspace" --version)
assert_contains "ws version output" "xcind-workspace" "$ws_ver"

# Test: help flag
ws_help=$("$XCIND_ROOT/bin/xcind-workspace" --help)
assert_contains "ws help mentions init" "init" "$ws_help"

# Test: unknown subcommand
ws_unknown=$("$XCIND_ROOT/bin/xcind-workspace" badcmd 2>&1 || true)
assert_contains "ws unknown subcommand error" "Unknown command" "$ws_unknown"

rm -rf "$WS_INIT_DIR"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace status ==="

WS_STATUS_DIR=$(mktemp -d)
REAL_PATH_STATUS="$PATH"

# Create a workspace with two apps
mkdir -p "$WS_STATUS_DIR/myws/app1" "$WS_STATUS_DIR/myws/app2" "$WS_STATUS_DIR/myws/notanapp"
echo 'XCIND_IS_WORKSPACE=1' >"$WS_STATUS_DIR/myws/.xcind.sh"
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$WS_STATUS_DIR/myws/app1/.xcind.sh"
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$WS_STATUS_DIR/myws/app2/.xcind.sh"

# Mock docker to return no containers
mkdir -p "$WS_STATUS_DIR/bin"
cat >"$WS_STATUS_DIR/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker — return empty for all queries
exit 0
MOCKEOF
chmod +x "$WS_STATUS_DIR/bin/docker"
export PATH="$WS_STATUS_DIR/bin:$REAL_PATH_STATUS"

# Test: status from workspace root
ws_status_out=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS_DIR/myws")
assert_contains "ws status: shows workspace name" "Workspace: myws" "$ws_status_out"
assert_contains "ws status: shows root" "Root:" "$ws_status_out"
assert_contains "ws status: lists app1" "app1/" "$ws_status_out"
assert_contains "ws status: lists app2" "app2/" "$ws_status_out"
assert_not_contains "ws status: excludes non-app dir" "notanapp" "$ws_status_out"
assert_contains "ws status: shows network" "myws-internal" "$ws_status_out"
assert_contains "ws status: shows proxy" "Proxy:" "$ws_status_out"

# Test: status from app directory discovers workspace
ws_status_from_app=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS_DIR/myws/app1")
assert_contains "ws status from app: shows workspace" "Workspace: myws" "$ws_status_from_app"

# Test: status with --json
if command -v jq &>/dev/null; then
  ws_json=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS_DIR/myws" --json)
  ws_name_json=$(echo "$ws_json" | jq -r '.workspace')
  assert_eq "ws status json: workspace name" "myws" "$ws_name_json"
  ws_apps_count=$(echo "$ws_json" | jq '.apps | length')
  assert_eq "ws status json: apps count" "2" "$ws_apps_count"
  ws_net_name=$(echo "$ws_json" | jq -r '.network.name')
  assert_eq "ws status json: network name" "myws-internal" "$ws_net_name"
else
  echo "  (skipped json tests: jq not installed)"
fi

# Test: error when not in a workspace
ws_no_ws_err=$("$XCIND_ROOT/bin/xcind-workspace" status /tmp 2>&1 || true)
assert_contains "ws status: error when not in workspace" "Not inside a workspace" "$ws_no_ws_err"

export PATH="$REAL_PATH_STATUS"
rm -rf "$WS_STATUS_DIR"

# ======================================================================
echo ""
echo "=== Test: XCIND_HOOKS_EXECUTE registration ==="

# Check registration before any test overrides the array
HOOKS_STR="${XCIND_HOOKS_EXECUTE[*]}"
assert_contains "proxy execute hook registered" "__xcind-proxy-execute-hook" "$HOOKS_STR"
assert_contains "workspace execute hook registered" "__xcind-workspace-execute-hook" "$HOOKS_STR"

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-execute-hook ==="

# Should call ensure-running when XCIND_PROXY_EXPORTS is set
PROXY_EXEC_CALLED=""
__xcind-proxy-ensure-running() { PROXY_EXEC_CALLED="yes"; }
XCIND_PROXY_EXPORTS=("web")
__xcind-proxy-execute-hook "/tmp/test-app"
assert_eq "execute hook: calls ensure-running" "yes" "$PROXY_EXEC_CALLED"

# Should skip when XCIND_PROXY_EXPORTS is empty
PROXY_EXEC_CALLED=""
XCIND_PROXY_EXPORTS=()
__xcind-proxy-execute-hook "/tmp/test-app"
assert_eq "execute hook: skips when exports empty" "" "$PROXY_EXEC_CALLED"

# Should skip when XCIND_PROXY_EXPORTS is unset
PROXY_EXEC_CALLED=""
unset XCIND_PROXY_EXPORTS
__xcind-proxy-execute-hook "/tmp/test-app"
assert_eq "execute hook: skips when exports unset" "" "$PROXY_EXEC_CALLED"

# ======================================================================
echo ""
echo "=== Test: __xcind-workspace-execute-hook ==="

# Should create network when in workspace mode
DOCKER_CMDS=""
# shellcheck disable=SC2317
docker() { DOCKER_CMDS+="$* "; }
export -f docker
XCIND_WORKSPACELESS="0"
XCIND_WORKSPACE="dev"
__xcind-workspace-execute-hook "/tmp/test-app"
assert_contains "workspace execute hook: creates network" "network create dev-internal" "$DOCKER_CMDS"

# Should skip when workspaceless
DOCKER_CMDS=""
XCIND_WORKSPACELESS="1"
__xcind-workspace-execute-hook "/tmp/test-app"
assert_eq "workspace execute hook: skips when workspaceless" "" "$DOCKER_CMDS"
unset -f docker

# ======================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
