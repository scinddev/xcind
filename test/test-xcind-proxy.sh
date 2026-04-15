#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034,SC2154,SC2329
# test-xcind-proxy.sh — Verify xcind-proxy CLI and hook libraries
set -euo pipefail

# yq and jq are required runtime dependencies (e9319cd promoted yq). The
# proxy hook tests generate compose overlays via yq, so fail loudly here
# rather than silently skipping blocks when yq is missing.
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
echo "=== Test: xcind-proxy init (mock HOME) ==="

# Unset XDG_* so xcind-proxy-lib and xcind-assigned-lib fall back to the
# mock HOME-derived paths. Without this, a developer with XDG_CONFIG_HOME
# set in their environment (common on Nix/systemd setups) would see tests
# write to the real ~/.config/xcind/proxy, clobbering live state.
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_DATA_HOME

# Use a temp dir as HOME to avoid touching real config
REAL_HOME="$HOME"
MOCK_HOME=$(mktemp_d)
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
# TLS config vars (ADR-0009)
assert_contains "config has XCIND_PROXY_TLS_MODE" "XCIND_PROXY_TLS_MODE" "$config_content"
assert_contains "config TLS defaults to auto" 'XCIND_PROXY_TLS_MODE="auto"' "$config_content"
assert_contains "config has XCIND_PROXY_HTTPS_PORT" 'XCIND_PROXY_HTTPS_PORT="443"' "$config_content"
assert_contains "config has XCIND_PROXY_TLS_CERT_FILE" "XCIND_PROXY_TLS_CERT_FILE" "$config_content"
assert_contains "config has XCIND_PROXY_TLS_KEY_FILE" "XCIND_PROXY_TLS_KEY_FILE" "$config_content"

# Verify docker-compose.yaml contents
compose_content=$(<"$PROXY_STATE_DIR/docker-compose.yaml")
assert_contains "compose has traefik service" "traefik:" "$compose_content"
assert_contains "compose has xcind-proxy network" "xcind-proxy:" "$compose_content"
assert_contains "compose has external network" "external: true" "$compose_content"
assert_contains "compose has docker socket volume" "/var/run/docker.sock" "$compose_content"

# Verify traefik.yaml contents — TLS defaults to auto, so expect websecure + file provider
traefik_content=$(<"$PROXY_STATE_DIR/traefik.yaml")
assert_contains "traefik has web entrypoint" "web:" "$traefik_content"
assert_contains "traefik has docker provider" "docker:" "$traefik_content"
assert_contains "traefik has exposedByDefault false" "exposedByDefault: false" "$traefik_content"
assert_contains "traefik has websecure entrypoint (TLS auto)" "websecure:" "$traefik_content"
assert_contains "traefik has file provider (TLS auto)" "file:" "$traefik_content"
assert_contains "traefik file provider watches dynamic dir" "/etc/traefik/dynamic" "$traefik_content"

# Compose file should expose :443 and mount dynamic/ + certs/ by default
assert_contains "compose exposes 443:443 (TLS auto)" "443:443" "$compose_content"
assert_contains "compose mounts dynamic (TLS auto)" "./dynamic:/etc/traefik/dynamic:ro" "$compose_content"
assert_contains "compose mounts certs (TLS auto)" "./certs:/etc/traefik/certs:ro" "$compose_content"

# dynamic/tls.yaml and certs/ dir should exist
assert_file_exists "dynamic/tls.yaml created (TLS auto)" "$PROXY_STATE_DIR/dynamic/tls.yaml"
tls_dynamic=$(<"$PROXY_STATE_DIR/dynamic/tls.yaml")
assert_contains "dynamic/tls.yaml points at wildcard cert" "wildcard.crt" "$tls_dynamic"
assert_contains "dynamic/tls.yaml has default store" "defaultCertificate:" "$tls_dynamic"
assert_eq "certs dir created" "true" "$([ -d "$PROXY_STATE_DIR/certs" ] && echo true || echo false)"

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

MOCK_HOME2=$(mktemp_d)
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

# --tls-mode disabled drops HTTPS entrypoint, cert mounts, and dynamic TLS config
"$XCIND_ROOT/bin/xcind-proxy" init --tls-mode disabled
config_tls_disabled=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "flag: tls-mode disabled recorded" 'XCIND_PROXY_TLS_MODE="disabled"' "$config_tls_disabled"
compose_disabled=$(<"$PROXY_STATE_DIR2/docker-compose.yaml")
assert_not_contains "compose has no :443 when TLS disabled" "443:443" "$compose_disabled"
assert_not_contains "compose has no dynamic mount when TLS disabled" "/etc/traefik/dynamic" "$compose_disabled"
assert_not_contains "compose has no certs mount when TLS disabled" "/etc/traefik/certs" "$compose_disabled"
traefik_disabled=$(<"$PROXY_STATE_DIR2/traefik.yaml")
assert_not_contains "traefik has no websecure when TLS disabled" "websecure:" "$traefik_disabled"
assert_not_contains "traefik has no file provider when TLS disabled" "file:" "$traefik_disabled"
assert_eq "no dynamic/tls.yaml when TLS disabled" "false" \
  "$([ -f "$PROXY_STATE_DIR2/dynamic/tls.yaml" ] && echo true || echo false)"

# Re-enable TLS via init --tls-mode auto
"$XCIND_ROOT/bin/xcind-proxy" init --tls-mode auto --https-port 8443
config_tls_auto=$(<"$PROXY_CONFIG_DIR2/config.sh")
assert_contains "flag: tls-mode auto recorded" 'XCIND_PROXY_TLS_MODE="auto"' "$config_tls_auto"
assert_contains "flag: https-port 8443 recorded" 'XCIND_PROXY_HTTPS_PORT="8443"' "$config_tls_auto"
compose_auto=$(<"$PROXY_STATE_DIR2/docker-compose.yaml")
assert_contains "compose reflects 8443:443" "8443:443" "$compose_auto"
assert_file_exists "dynamic/tls.yaml regenerated for auto" "$PROXY_STATE_DIR2/dynamic/tls.yaml"

# Invalid --tls-mode value is rejected
invalid_tls_mode=$("$XCIND_ROOT/bin/xcind-proxy" init --tls-mode weird 2>&1) && itm_rc=0 || itm_rc=$?
assert_eq "--tls-mode invalid exits non-zero" "1" "$itm_rc"
assert_contains "--tls-mode invalid mentions auto/custom/disabled" "auto" "$invalid_tls_mode"

export HOME="$REAL_HOME"
export PATH="$REAL_PATH"
rm -rf "$MOCK_HOME2"

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-ensure-running ==="

MOCK_HOME2=$(mktemp_d)
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

MOCK_HOME_JSON=$(mktemp_d)
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

MOCK_HOME_JSON2=$(mktemp_d)
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
echo "=== Test: xcind-proxy status --json with unusual image name ==="

MOCK_HOME_JSON3=$(mktemp_d)
REAL_HOME_JSON3="$HOME"
export HOME="$MOCK_HOME_JSON3"
# Re-derive proxy paths from new HOME so we can write into the config
XCIND_PROXY_CONFIG_DIR="${HOME}/.config/xcind/proxy"

REAL_PATH_JSON3="$PATH"
export PATH="$MOCK_HOME_JSON3/bin:$PATH"
mkdir -p "$MOCK_HOME_JSON3/bin"
cat >"$MOCK_HOME_JSON3/bin/docker" <<'MOCKEOF'
#!/bin/sh
# Mock docker — simulate running container for ps, accept network inspect
case "$1" in
  compose) echo '{"Name":"traefik"}' ;;
  network) exit 0 ;;
  *) exit 0 ;;
esac
MOCKEOF
chmod +x "$MOCK_HOME_JSON3/bin/docker"

"$XCIND_ROOT/bin/xcind-proxy" init >/dev/null

# Set an image name that would break a hand-rolled printf template
printf 'XCIND_PROXY_IMAGE='\''my-registry/traefik:"tag with quote"'\''\n' \
  >"$XCIND_PROXY_CONFIG_DIR/config.sh"

json_out=$("$XCIND_ROOT/bin/xcind-proxy" status --json 2>/dev/null)

# Parse it — if the JSON is broken, jq exits non-zero and we fail
if printf '%s' "$json_out" | jq -e . >/dev/null 2>&1; then
  assert_eq "status --json parses as valid JSON" "0" "0"
else
  assert_eq "status --json parses as valid JSON" "0" "1"
fi

# Confirm the image field round-trips correctly
echoed=$(printf '%s' "$json_out" | jq -r '.image')
assert_eq "image field round-trips through JSON" \
  'my-registry/traefik:"tag with quote"' "$echoed"

export HOME="$REAL_HOME_JSON3"
export PATH="$REAL_PATH_JSON3"
rm -rf "$MOCK_HOME_JSON3"

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-parse-entry ==="

# Format: "web" (export=service, no port)
__xcind-proxy-parse-entry "web"
assert_eq "parse 'web' export" "web" "$_export_name"
assert_eq "parse 'web' service" "web" "$_compose_service"
assert_eq "parse 'web' port" "" "$_port"
assert_eq "parse 'web' type defaults to proxied" "proxied" "$_type"

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

# Metadata: type=assigned
__xcind-proxy-parse-entry "worker:9000;type=assigned"
assert_eq "parse type=assigned export" "worker" "$_export_name"
assert_eq "parse type=assigned service" "worker" "$_compose_service"
assert_eq "parse type=assigned port" "9000" "$_port"
assert_eq "parse type=assigned type" "assigned" "$_type"

# Metadata with explicit type=proxied
__xcind-proxy-parse-entry "web;type=proxied"
assert_eq "parse explicit type=proxied" "proxied" "$_type"

# Metadata with full syntax
__xcind-proxy-parse-entry "database=db:3306;type=assigned"
assert_eq "parse full syntax export" "database" "$_export_name"
assert_eq "parse full syntax service" "db" "$_compose_service"
assert_eq "parse full syntax port" "3306" "$_port"
assert_eq "parse full syntax type" "assigned" "$_type"

# Sentinel reset: _type must not leak across calls. Seed $_type=assigned,
# then parse an entry without metadata — it should come back as proxied.
_type="assigned"
__xcind-proxy-parse-entry "web"
assert_eq "parse sentinel reset (no metadata)" "proxied" "$_type"

# Unknown attribute produces an error and non-zero status
unknown_err=$(__xcind-proxy-parse-entry "web;visibility=public" 2>&1) && unknown_rc=0 || unknown_rc=$?
assert_eq "parse unknown attribute returns non-zero" "1" "$unknown_rc"
assert_contains "parse unknown attribute error text" "unknown XCIND_PROXY_EXPORTS attribute 'visibility'" "$unknown_err"

# Invalid type value rejected
invalid_err=$(__xcind-proxy-parse-entry "web;type=bogus" 2>&1) && invalid_rc=0 || invalid_rc=$?
assert_eq "parse invalid type returns non-zero" "1" "$invalid_rc"
assert_contains "parse invalid type error text" "invalid XCIND_PROXY_EXPORTS type 'bogus'" "$invalid_err"

# tls= metadata — defaults to "auto"
__xcind-proxy-parse-entry "web"
assert_eq "parse 'web' tls defaults to auto" "auto" "$_tls"

# tls=require accepted
__xcind-proxy-parse-entry "web;tls=require"
assert_eq "parse tls=require" "require" "$_tls"

# tls=disable accepted
__xcind-proxy-parse-entry "web;tls=disable"
assert_eq "parse tls=disable" "disable" "$_tls"

# tls=auto explicit
__xcind-proxy-parse-entry "web;tls=auto"
assert_eq "parse tls=auto explicit" "auto" "$_tls"

# type + tls combined
__xcind-proxy-parse-entry "api=app:3000;type=proxied;tls=require"
assert_eq "parse type+tls: export" "api" "$_export_name"
assert_eq "parse type+tls: service" "app" "$_compose_service"
assert_eq "parse type+tls: port" "3000" "$_port"
assert_eq "parse type+tls: type" "proxied" "$_type"
assert_eq "parse type+tls: tls" "require" "$_tls"

# _tls sentinel must reset between calls — seed with "require" then parse plain entry
_tls="require"
__xcind-proxy-parse-entry "web"
assert_eq "parse sentinel reset (tls)" "auto" "$_tls"

# Invalid tls value rejected
bad_tls_err=$(__xcind-proxy-parse-entry "web;tls=maybe" 2>&1) && bad_tls_rc=0 || bad_tls_rc=$?
assert_eq "parse invalid tls returns non-zero" "1" "$bad_tls_rc"
assert_contains "parse invalid tls error text" "invalid XCIND_PROXY_EXPORTS tls 'maybe'" "$bad_tls_err"

# ======================================================================
echo ""
echo "=== Test: xcind-proxy-hook (YAML generation) ==="

# These tests require yq
HOOK_APP=$(mktemp_d)
echo '# hook test' >"$HOOK_APP/.xcind.sh"

# Sandbox HOME so __xcind-proxy-ensure-init never writes to the real home dir
_orig_HOME="$HOME"
HOME=$(mktemp_d)
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

# Test: array populated but no type=proxied entries → no output, no file.
# The proxy hook must ignore assigned-only entries entirely (they're owned
# by xcind-assigned-hook).
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("worker:9000;type=assigned" "db=postgres:5432;type=assigned")
noprox_output=$(xcind-proxy-hook "$HOOK_APP")
assert_eq "no proxied entries = no output" "" "$noprox_output"
assert_eq "no proxied entries = no file" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.proxy.yaml" ] && echo true || echo false)"

# Test: mixed array — proxy hook sees only the proxied entries.
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web" "db=postgres:5432;type=assigned" "api:3000")
xcind-proxy-hook "$HOOK_APP" >/dev/null
mixed_proxy_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "mixed: yaml has web service" "  web:" "$mixed_proxy_yaml"
assert_contains "mixed: yaml has api service" "  api:" "$mixed_proxy_yaml"
assert_not_contains "mixed: yaml omits assigned postgres" "postgres:" "$mixed_proxy_yaml"

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
# TLS defaults to auto, so the preferred-scheme URL is https. Per-protocol
# siblings (xcind.apex.http.url / xcind.apex.https.url) cover http readers.
assert_contains "apex: primary has xcind.apex.url (https preferred)" "xcind.apex.url=https://myapp.localhost" "$apex_yaml"
assert_contains "apex: primary has xcind.apex.http.url" "xcind.apex.http.url=http://myapp.localhost" "$apex_yaml"
assert_contains "apex: primary has xcind.apex.https.url" "xcind.apex.https.url=https://myapp.localhost" "$apex_yaml"
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

# ======================================================================
echo ""
echo "=== Test: xcind-proxy-hook TLS modes ==="

# Shared setup for TLS hook tests: workspaceless, apex enabled, yaml with web+api.
XCIND_PROXY_AUTO_START=0
export XCIND_WORKSPACELESS=1
export XCIND_WORKSPACE=""
export XCIND_WORKSPACE_ROOT=""
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

# --- TLS disabled at proxy level → HTTP-only output, no redirect, no https labels
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
export XCIND_PROXY_TLS_MODE="disabled"
XCIND_PROXY_EXPORTS=("web")
xcind-proxy-hook "$HOOK_APP" >/dev/null
tls_off_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "tls disabled: has HTTP router" "myapp-web-http" "$tls_off_yaml"
assert_not_contains "tls disabled: no HTTPS router" "myapp-web-https" "$tls_off_yaml"
assert_not_contains "tls disabled: no redirect middleware" "xcind-redirect-to-https" "$tls_off_yaml"
assert_contains "tls disabled: url label is http" "xcind.export.web.url=http://myapp-web.localhost" "$tls_off_yaml"
assert_not_contains "tls disabled: no https.url label" "xcind.export.web.https.url" "$tls_off_yaml"
assert_contains "tls disabled: apex url is http" "xcind.apex.url=http://myapp.localhost" "$tls_off_yaml"

# --- Default (TLS auto): both routers + preferred https url + per-protocol siblings
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
export XCIND_PROXY_TLS_MODE="auto"
XCIND_PROXY_EXPORTS=("web")
xcind-proxy-hook "$HOOK_APP" >/dev/null
tls_auto_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "tls auto: has HTTP router" "myapp-web-http.rule=" "$tls_auto_yaml"
assert_contains "tls auto: has HTTPS router" "myapp-web-https.rule=" "$tls_auto_yaml"
assert_contains "tls auto: HTTPS router uses websecure" "myapp-web-https.entrypoints=websecure" "$tls_auto_yaml"
assert_contains "tls auto: HTTPS router has tls=true" "myapp-web-https.tls=true" "$tls_auto_yaml"
assert_contains "tls auto: http.url label" "xcind.export.web.http.url=http://myapp-web.localhost" "$tls_auto_yaml"
assert_contains "tls auto: https.url label" "xcind.export.web.https.url=https://myapp-web.localhost" "$tls_auto_yaml"
assert_contains "tls auto: preferred url is https" "xcind.export.web.url=https://myapp-web.localhost" "$tls_auto_yaml"
assert_contains "tls auto: apex https router" "myapp-https.entrypoints=websecure" "$tls_auto_yaml"
assert_contains "tls auto: apex preferred url is https" "xcind.apex.url=https://myapp.localhost" "$tls_auto_yaml"
assert_not_contains "tls auto: no redirect middleware (all exports auto)" "xcind-redirect-to-https" "$tls_auto_yaml"

# --- tls=require export → HTTP router becomes redirect, HTTPS router real, middleware emitted once
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web;tls=require")
xcind-proxy-hook "$HOOK_APP" >/dev/null
tls_req_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "tls require: HTTP router attaches redirect middleware" \
  "myapp-web-http.middlewares=xcind-redirect-to-https@docker" "$tls_req_yaml"
assert_not_contains "tls require: HTTP router has no service loadbalancer" \
  "myapp-web-http.service=" "$tls_req_yaml"
assert_contains "tls require: HTTPS router present" "myapp-web-https.entrypoints=websecure" "$tls_req_yaml"
assert_contains "tls require: redirect middleware defined" \
  "traefik.http.middlewares.xcind-redirect-to-https.redirectscheme.scheme=https" "$tls_req_yaml"
assert_contains "tls require: redirect is permanent" \
  "traefik.http.middlewares.xcind-redirect-to-https.redirectscheme.permanent=true" "$tls_req_yaml"
# Middleware must only appear once, even with multiple exports
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web;tls=require" "api:3000;tls=require")
xcind-proxy-hook "$HOOK_APP" >/dev/null
multi_req_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
mw_count=$(echo "$multi_req_yaml" | grep -c 'xcind-redirect-to-https.redirectscheme.scheme=https' || true)
assert_eq "tls require: middleware defined exactly once" "1" "$mw_count"

# --- tls=disable export keeps HTTP-only even when proxy TLS is enabled
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web;tls=disable")
xcind-proxy-hook "$HOOK_APP" >/dev/null
tls_dis_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "tls disable export: HTTP router present" "myapp-web-http.rule=" "$tls_dis_yaml"
assert_not_contains "tls disable export: no HTTPS router" "myapp-web-https" "$tls_dis_yaml"
assert_contains "tls disable export: url label is http" "xcind.export.web.url=http://myapp-web.localhost" "$tls_dis_yaml"
assert_not_contains "tls disable export: no https.url label" "xcind.export.web.https.url" "$tls_dis_yaml"

# --- Mixed per-export TLS on the same app (auto + disable + require)
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web" "api:3000;tls=disable" "admin=api:3000;tls=require")
xcind-proxy-hook "$HOOK_APP" >/dev/null
mix_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "mixed: web has HTTPS router" "myapp-web-https" "$mix_yaml"
assert_not_contains "mixed: api (disable) has no HTTPS router" "myapp-api-https" "$mix_yaml"
assert_contains "mixed: admin (require) has HTTPS router" "myapp-admin-https" "$mix_yaml"
assert_contains "mixed: admin HTTP router redirects" \
  "myapp-admin-http.middlewares=xcind-redirect-to-https@docker" "$mix_yaml"
assert_contains "mixed: redirect middleware emitted once" \
  "traefik.http.middlewares.xcind-redirect-to-https.redirectscheme.scheme=https" "$mix_yaml"

# --- Proxy TLS disabled overrides per-export tls=require (collapse to HTTP)
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
export XCIND_PROXY_TLS_MODE="disabled"
XCIND_PROXY_EXPORTS=("web;tls=require")
xcind-proxy-hook "$HOOK_APP" >/dev/null
override_yaml=$(<"$XCIND_GENERATED_DIR/compose.proxy.yaml")
assert_contains "proxy disabled overrides require: HTTP router present" "myapp-web-http.rule=" "$override_yaml"
assert_not_contains "proxy disabled overrides require: no HTTPS router" "myapp-web-https" "$override_yaml"
assert_not_contains "proxy disabled overrides require: no redirect middleware" "xcind-redirect-to-https" "$override_yaml"

# --- Invalid tls= value in XCIND_PROXY_EXPORTS fails the hook
rm -rf "$XCIND_GENERATED_DIR"
mkdir -p "$XCIND_GENERATED_DIR"
XCIND_PROXY_EXPORTS=("web;tls=bogus")
bogus_err=$(xcind-proxy-hook "$HOOK_APP" 2>&1) && bogus_rc=0 || bogus_rc=$?
assert_eq "hook: invalid tls value fails" "1" "$bogus_rc"
assert_contains "hook: invalid tls message" "invalid XCIND_PROXY_EXPORTS tls 'bogus'" "$bogus_err"

unset XCIND_PROXY_TLS_MODE

unset -f docker
rm -rf "$HOOK_APP" "$HOME"
HOME="$_orig_HOME"
unset XCIND_PROXY_CONFIG_DIR XCIND_PROXY_STATE_DIR XCIND_PROXY_DIR XCIND_PROXY_COMPOSE _orig_HOME

# ======================================================================
echo ""
echo "=== Test: __xcind-proxy-ensure-certs (openssl fallback) ==="

if command -v openssl >/dev/null 2>&1; then
  CERT_HOME=$(mktemp_d)
  _cert_orig_HOME="$HOME"
  export HOME="$CERT_HOME"
  XCIND_PROXY_CONFIG_DIR="$HOME/.config/xcind/proxy"
  XCIND_PROXY_STATE_DIR="$HOME/.local/state/xcind/proxy"
  mkdir -p "$XCIND_PROXY_CONFIG_DIR" "$XCIND_PROXY_STATE_DIR"

  # Force openssl branch by hiding mkcert from PATH.
  _cert_orig_PATH="$PATH"
  CERT_BIN="$CERT_HOME/bin-no-mkcert"
  mkdir -p "$CERT_BIN"
  # Rebuild a PATH that keeps system dirs but excludes any mkcert shim.
  # Restore IFS after the colon-split — `unset IFS` leaves it unbound, which
  # breaks any subsequent `$IFS` reference (including parse-entry's metadata
  # splitter) under the suite's `set -u`.
  _filtered_path=""
  _saved_ifs="$IFS"
  IFS=':'
  for _p in $_cert_orig_PATH; do
    if [[ -x "$_p/mkcert" ]]; then
      continue
    fi
    _filtered_path="${_filtered_path:+$_filtered_path:}$_p"
  done
  IFS="$_saved_ifs"
  unset _saved_ifs
  export PATH="$CERT_BIN:$_filtered_path"

  XCIND_PROXY_TLS_MODE="auto"
  XCIND_PROXY_DOMAIN="test.localhost"
  __xcind-proxy-ensure-certs 2>/dev/null
  assert_file_exists "ensure-certs: wildcard.crt created" "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt"
  assert_file_exists "ensure-certs: wildcard.key created" "$XCIND_PROXY_STATE_DIR/certs/wildcard.key"
  assert_file_exists "ensure-certs: domain marker created" "$XCIND_PROXY_STATE_DIR/certs/domain"
  marker_content=$(<"$XCIND_PROXY_STATE_DIR/certs/domain")
  assert_eq "ensure-certs: marker matches domain" "test.localhost" "$marker_content"
  # Second call should reuse the existing cert (fast path)
  first_mtime=$(stat -c %Y "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt" 2>/dev/null || stat -f %m "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt")
  sleep 1
  __xcind-proxy-ensure-certs 2>/dev/null
  second_mtime=$(stat -c %Y "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt" 2>/dev/null || stat -f %m "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt")
  assert_eq "ensure-certs: reuses existing cert" "$first_mtime" "$second_mtime"
  # Domain change triggers regeneration
  XCIND_PROXY_DOMAIN="other.localhost"
  __xcind-proxy-ensure-certs 2>/dev/null
  new_marker=$(<"$XCIND_PROXY_STATE_DIR/certs/domain")
  assert_eq "ensure-certs: marker updated on domain change" "other.localhost" "$new_marker"
  third_mtime=$(stat -c %Y "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt" 2>/dev/null || stat -f %m "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt")
  # mtime must have advanced when the cert was regenerated for the new domain.
  regenerated="no"
  [[ $third_mtime -gt $second_mtime ]] && regenerated="yes"
  assert_eq "ensure-certs: cert regenerated on domain change" "yes" "$regenerated"

  # disabled mode is a no-op
  rm -rf "$XCIND_PROXY_STATE_DIR/certs"
  XCIND_PROXY_TLS_MODE="disabled"
  __xcind-proxy-ensure-certs
  assert_eq "ensure-certs disabled: no cert created" "false" \
    "$([ -f "$XCIND_PROXY_STATE_DIR/certs/wildcard.crt" ] && echo true || echo false)"

  # custom mode requires both files
  XCIND_PROXY_TLS_MODE="custom"
  XCIND_PROXY_TLS_CERT_FILE=""
  XCIND_PROXY_TLS_KEY_FILE=""
  custom_err=$(__xcind-proxy-ensure-certs 2>&1) && custom_rc=0 || custom_rc=$?
  assert_eq "ensure-certs custom: missing files exits non-zero" "1" "$custom_rc"
  assert_contains "ensure-certs custom: message mentions env vars" "XCIND_PROXY_TLS_CERT_FILE" "$custom_err"

  export PATH="$_cert_orig_PATH"
  export HOME="$_cert_orig_HOME"
  rm -rf "$CERT_HOME"
  XCIND_PROXY_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/xcind/proxy"
  XCIND_PROXY_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
  unset XCIND_PROXY_TLS_MODE XCIND_PROXY_DOMAIN XCIND_PROXY_TLS_CERT_FILE XCIND_PROXY_TLS_KEY_FILE
  unset _cert_orig_HOME _cert_orig_PATH _filtered_path _p
else
  echo "  (skipped — openssl not on PATH)"
fi

# ======================================================================
echo ""
echo "=== Test: xcind-workspace-hook ==="

WS_HOOK_APP=$(mktemp_d)
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

# ======================================================================
echo ""
echo "=== Test: xcind-workspace init ==="

WS_INIT_DIR=$(mktemp_d)

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

WS_STATUS_DIR=$(mktemp_d)
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
ws_json=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_STATUS_DIR/myws" --json)
ws_name_json=$(echo "$ws_json" | jq -r '.workspace')
assert_eq "ws status json: workspace name" "myws" "$ws_name_json"
ws_apps_count=$(echo "$ws_json" | jq '.apps | length')
assert_eq "ws status json: apps count" "2" "$ws_apps_count"
ws_net_name=$(echo "$ws_json" | jq -r '.network.name')
assert_eq "ws status json: network name" "myws-internal" "$ws_net_name"

# Test: error when not in a workspace
ws_no_ws_err=$("$XCIND_ROOT/bin/xcind-workspace" status /tmp 2>&1 || true)
assert_contains "ws status: error when not in workspace" "Not inside a workspace" "$ws_no_ws_err"

export PATH="$REAL_PATH_STATUS"
rm -rf "$WS_STATUS_DIR"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace status defined-services count ==="

WS_COUNT_DIR=$(mktemp_d)
REAL_PATH_COUNT="$PATH"

# Workspace with one app whose compose file defines three services.
# Only one of those services has a running container in the docker mock,
# so the expected status text is "1/3 services running".
mkdir -p "$WS_COUNT_DIR/myws/multiapp"
echo 'XCIND_IS_WORKSPACE=1' >"$WS_COUNT_DIR/myws/.xcind.sh"
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$WS_COUNT_DIR/myws/multiapp/.xcind.sh"
cat >"$WS_COUNT_DIR/myws/multiapp/compose.yaml" <<'COMPOSEEOF'
services:
  web:
    image: nginx:alpine
  database:
    image: postgres:16
  worker:
    image: alpine:3
COMPOSEEOF

# Mock docker:
#   - "docker compose ... config"           → emit the compose.yaml
#   - "docker ps -a ... --format Names..."  → one Up container
#   - everything else                       → exit 0
mkdir -p "$WS_COUNT_DIR/bin"
cat >"$WS_COUNT_DIR/bin/docker" <<MOCKEOF
#!/bin/sh
case "\$*" in
  *compose*config*)
    cat "$WS_COUNT_DIR/myws/multiapp/compose.yaml"
    ;;
  *"ps -a"*Names*)
    printf 'multiapp-database-1\tUp 5 minutes\n'
    ;;
esac
exit 0
MOCKEOF
chmod +x "$WS_COUNT_DIR/bin/docker"
export PATH="$WS_COUNT_DIR/bin:$REAL_PATH_COUNT"

count_status=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_COUNT_DIR/myws")
assert_contains "ws status count: shows X/Y format" "1/3 services running" "$count_status"

count_json=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_COUNT_DIR/myws" --json)
count_total=$(echo "$count_json" | jq '.apps[0].total')
assert_eq "ws status count: json total" "3" "$count_total"
count_running=$(echo "$count_json" | jq '.apps[0].running')
assert_eq "ws status count: json running" "1" "$count_running"
count_defined=$(echo "$count_json" | jq -r '.apps[0].defined_services | sort | join(",")')
assert_eq "ws status count: defined_services lists all three" "database,web,worker" "$count_defined"

export PATH="$REAL_PATH_COUNT"
rm -rf "$WS_COUNT_DIR"

# ======================================================================
echo ""
echo "=== Test: xcind-workspace status workspace mismatch ==="

WS_MISMATCH_DIR=$(mktemp_d)
REAL_PATH_MISMATCH="$PATH"

# Two app subdirs under myws/. One has a normal config; the other declares
# itself as belonging to a different workspace via XCIND_WORKSPACE.
mkdir -p "$WS_MISMATCH_DIR/myws/realapp" "$WS_MISMATCH_DIR/myws/strangerapp"
echo 'XCIND_IS_WORKSPACE=1' >"$WS_MISMATCH_DIR/myws/.xcind.sh"
: >"$WS_MISMATCH_DIR/myws/realapp/.xcind.sh"
echo 'XCIND_WORKSPACE="otherws"' >"$WS_MISMATCH_DIR/myws/strangerapp/.xcind.sh"

mkdir -p "$WS_MISMATCH_DIR/bin"
cat >"$WS_MISMATCH_DIR/bin/docker" <<'MOCKEOF'
#!/bin/sh
exit 0
MOCKEOF
chmod +x "$WS_MISMATCH_DIR/bin/docker"
export PATH="$WS_MISMATCH_DIR/bin:$REAL_PATH_MISMATCH"

mismatch_status=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_MISMATCH_DIR/myws")
assert_contains "ws status mismatch: shows real app" "realapp/" "$mismatch_status"
assert_not_contains "ws status mismatch: skips stranger app" "strangerapp" "$mismatch_status"

mismatch_json=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_MISMATCH_DIR/myws" --json)
mismatch_count=$(echo "$mismatch_json" | jq '.apps | length')
assert_eq "ws status mismatch: json apps count = 1" "1" "$mismatch_count"

export PATH="$REAL_PATH_MISMATCH"
rm -rf "$WS_MISMATCH_DIR"

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

# Should skip when the array contains only type=assigned entries —
# Traefik is not needed for a config that only reserves host ports.
PROXY_EXEC_CALLED=""
XCIND_PROXY_EXPORTS=("worker:9000;type=assigned")
__xcind-proxy-execute-hook "/tmp/test-app"
assert_eq "execute hook: skips when only assigned entries" "" "$PROXY_EXEC_CALLED"

# Should run when the array has at least one proxied entry (mixed)
PROXY_EXEC_CALLED=""
XCIND_PROXY_EXPORTS=("worker:9000;type=assigned" "web")
__xcind-proxy-execute-hook "/tmp/test-app"
assert_eq "execute hook: runs when mixed has proxied entry" "yes" "$PROXY_EXEC_CALLED"

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
echo "=== Test: assigned-ports hook registration ==="

HOOKS_GEN_STR="${XCIND_HOOKS_GENERATE[*]}"
assert_contains "xcind-assigned-hook registered in GENERATE list" "xcind-assigned-hook" "$HOOKS_GEN_STR"

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-* state file helpers ==="

ASSIGNED_HOME=$(mktemp_d)
_orig_assigned_home="$HOME"
_orig_xdg_state="${XDG_STATE_HOME:-}"
export HOME="$ASSIGNED_HOME"
unset XDG_STATE_HOME
# Re-derive paths from new HOME (default XDG_STATE_HOME = $HOME/.local/state)
XCIND_ASSIGNED_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

__xcind-assigned-ensure-state-file
assert_file_exists "state file created with header" "$XCIND_ASSIGNED_PORTS_FILE"

header_line=$(head -1 "$XCIND_ASSIGNED_PORTS_FILE")
assert_contains "state file header has port" "port" "$header_line"
assert_contains "state file header has workspace" "workspace" "$header_line"
assert_contains "state file header has application" "application" "$header_line"
assert_contains "state file header has service" "service" "$header_line"
assert_contains "state file header has app_path" "app_path" "$header_line"

# Insert three entries — mix of workspaceless (empty workspace) and workspace rows
mkdir -p "$ASSIGNED_HOME/foo" "$ASSIGNED_HOME/bar"
__xcind-assigned-upsert 3306 "" foo db 3306 "$ASSIGNED_HOME/foo"
__xcind-assigned-upsert 6379 "" foo cache 6379 "$ASSIGNED_HOME/foo"
__xcind-assigned-upsert 5432 dev bar db 5432 "$ASSIGNED_HOME/bar"

# Lookup
looked=$(__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "db")
assert_eq "lookup foo/db → 3306" "3306" "$looked"
looked=$(__xcind-assigned-lookup "$ASSIGNED_HOME/bar" "db")
assert_eq "lookup bar/db → 5432" "5432" "$looked"
looked=$(__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "cache")
assert_eq "lookup foo/cache → 6379" "6379" "$looked"

# Workspace value persisted to TSV
bar_row=$(awk -F'\t' '$3 == "bar" {print; exit}' "$XCIND_ASSIGNED_PORTS_FILE")
assert_contains "bar row has workspace=dev" $'\tdev\t' "$bar_row"
foo_row=$(awk -F'\t' '$3 == "foo" && $4 == "db" {print; exit}' "$XCIND_ASSIGNED_PORTS_FILE")
assert_contains "foo row has empty workspace" $'\t\tfoo\t' "$foo_row"

# Nonexistent lookup returns 1
__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "nothing" >/dev/null && lookup_rc=0 || lookup_rc=$?
assert_eq "missing lookup exits 1" "1" "$lookup_rc"

# Upsert with same identity (foo/db) replaces the row with the new port
__xcind-assigned-upsert 3307 "" foo db 3306 "$ASSIGNED_HOME/foo"
looked=$(__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "db")
assert_eq "upsert replaces identity" "3307" "$looked"

row_count=$(grep -cv '^#' "$XCIND_ASSIGNED_PORTS_FILE" || true)
assert_eq "upsert keeps three rows" "3" "$row_count"

# Upsert that collides with an existing host port removes the old collider
__xcind-assigned-upsert 6379 dev bar cache 6379 "$ASSIGNED_HOME/bar"
# Now (foo, cache, 6379) should be gone; (bar, cache, 6379) should exist
__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "cache" >/dev/null && collided_rc=0 || collided_rc=$?
assert_eq "collision removes old owner" "1" "$collided_rc"
looked=$(__xcind-assigned-lookup "$ASSIGNED_HOME/bar" "cache")
assert_eq "collision keeps new owner" "6379" "$looked"

# Remove entry
__xcind-assigned-remove-entry "$ASSIGNED_HOME/foo" "db"
__xcind-assigned-lookup "$ASSIGNED_HOME/foo" "db" >/dev/null && removed_rc=0 || removed_rc=$?
assert_eq "remove-entry deletes row" "1" "$removed_rc"

# Remove by port
__xcind-assigned-remove-port 5432
__xcind-assigned-lookup "$ASSIGNED_HOME/bar" "db" >/dev/null && rm_port_rc=0 || rm_port_rc=$?
assert_eq "remove-port deletes row" "1" "$rm_port_rc"

# Remove by port that doesn't exist returns 1
__xcind-assigned-remove-port 9999 && no_port_rc=0 || no_port_rc=$?
assert_eq "remove-port missing → 1" "1" "$no_port_rc"

export HOME="$_orig_assigned_home"
[[ -n $_orig_xdg_state ]] && export XDG_STATE_HOME="$_orig_xdg_state"
rm -rf "$ASSIGNED_HOME"
XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

# ======================================================================
echo ""
echo "=== Test: __xcind-with-assigned-lock serializes concurrent writers ==="

# Concurrent upserts without a lock would trample each other because each
# upsert reads the TSV, filters, then rewrites. This test spawns N parallel
# writers for distinct (app_path, export) identities and asserts that all N
# rows landed in the state file — proving the flock critical section works.
if command -v flock >/dev/null 2>&1; then
  LOCK_HOME=$(mktemp_d)
  _orig_lock_home="$HOME"
  _orig_lock_xdg="${XDG_STATE_HOME:-}"
  export HOME="$LOCK_HOME"
  unset XDG_STATE_HOME
  XCIND_ASSIGNED_DIR="${HOME}/.local/state/xcind/proxy"
  XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
  XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"
  __xcind-assigned-ensure-state-file

  N=10
  for i in $(seq 1 $N); do
    (
      __xcind-with-assigned-lock __xcind-assigned-upsert \
        "$((3300 + i))" "" "app$i" "web" "80" "/tmp/xcind-lock-test/app$i"
    ) &
  done
  wait

  row_count=$(grep -cv '^#' "$XCIND_ASSIGNED_PORTS_FILE" || true)
  assert_eq "all $N concurrent upserts persisted" "$N" "$row_count"

  unique_ports=$(awk -F'\t' '!/^#/ && NF>0 {print $1}' \
    "$XCIND_ASSIGNED_PORTS_FILE" | sort -u | wc -l | tr -d ' ')
  assert_eq "locked: no duplicate ports" "$N" "$unique_ports"

  unique_paths=$(awk -F'\t' '!/^#/ && NF>0 {print $6}' \
    "$XCIND_ASSIGNED_PORTS_FILE" | sort -u | wc -l | tr -d ' ')
  assert_eq "locked: all distinct app_paths persisted" "$N" "$unique_paths"

  malformed=$(awk -F'\t' '!/^#/ && NF>0 && NF!=7 {print}' \
    "$XCIND_ASSIGNED_PORTS_FILE" | wc -l | tr -d ' ')
  assert_eq "locked: no malformed rows" "0" "$malformed"

  export HOME="$_orig_lock_home"
  [[ -n $_orig_lock_xdg ]] && export XDG_STATE_HOME="$_orig_lock_xdg"
  rm -rf "$LOCK_HOME"
  XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
  XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
  XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"
else
  echo "  (skipped: flock not available on this platform)"
fi

# ======================================================================
echo ""
echo "=== Test: __xcind-with-assigned-lock unlocked fallback produces valid TSV ==="

# When flock is missing, upserts run unlocked. Lost writes are acceptable
# (best-effort), but mv(1) is atomic on POSIX filesystems so the state file
# must always contain a valid, well-formed TSV with no partial rows and no
# duplicate ports. This test hides flock from `command -v` via a shell
# function override so the else branch of __xcind-with-assigned-lock runs.
NOLOCK_HOME=$(mktemp_d)
_orig_nolock_home="$HOME"
_orig_nolock_xdg="${XDG_STATE_HOME:-}"
export HOME="$NOLOCK_HOME"
unset XDG_STATE_HOME
XCIND_ASSIGNED_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"
__xcind-assigned-ensure-state-file

# shellcheck disable=SC2317  # invoked indirectly by __xcind-with-assigned-lock
command() {
  if [ "$1" = "-v" ] && [ "$2" = "flock" ]; then
    return 1
  fi
  builtin command "$@"
}

N=10
for i in $(seq 1 $N); do
  (
    __xcind-with-assigned-lock __xcind-assigned-upsert \
      "$((3400 + i))" "" "app$i" "web" "80" "/tmp/xcind-nolock-test/app$i"
  ) &
done
wait

unset -f command

# Unlocked fallback is best-effort: the only guarantee we assert is that
# at least one write reaches the state file. mv(1) keeps each completed
# rewrite atomic, but the read-filter-rewrite sequence inside
# __xcind-assigned-upsert is not serialized, so concurrent writers can
# still lose updates, overwrite one another's rows, or re-order the final
# contents (last-writer-wins). That's the cost of running without a lock;
# the locked test above is the one that enforces the strong invariants.
row_count=$(grep -cv '^#' "$XCIND_ASSIGNED_PORTS_FILE" || true)
assert_eq "unlocked: at least one row persisted" "0" \
  "$([ "$row_count" -ge 1 ] && echo 0 || echo 1)"

export HOME="$_orig_nolock_home"
[[ -n $_orig_nolock_xdg ]] && export XDG_STATE_HOME="$_orig_nolock_xdg"
rm -rf "$NOLOCK_HOME"
XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-prune ==="

PRUNE_HOME=$(mktemp_d)
_orig_prune_home="$HOME"
_orig_prune_xdg="${XDG_STATE_HOME:-}"
export HOME="$PRUNE_HOME"
unset XDG_STATE_HOME
XCIND_ASSIGNED_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

mkdir -p "$PRUNE_HOME/alive"
__xcind-assigned-upsert 3306 "" alive db 3306 "$PRUNE_HOME/alive"
__xcind-assigned-upsert 5432 "" gone db 5432 "$PRUNE_HOME/deleted"
__xcind-assigned-upsert 6379 "" alive cache 6379 "$PRUNE_HOME/alive"

pruned_count=$(__xcind-assigned-prune)
assert_eq "prune removed stale entry" "1" "$pruned_count"

# The alive entries should remain, the gone entry should not
remaining=$(grep -cv '^#' "$XCIND_ASSIGNED_PORTS_FILE" || true)
assert_eq "prune leaves two live entries" "2" "$remaining"
__xcind-assigned-lookup "$PRUNE_HOME/alive" "db" >/dev/null && alive_rc=0 || alive_rc=1
assert_eq "prune keeps alive/db" "0" "$alive_rc"
__xcind-assigned-lookup "$PRUNE_HOME/deleted" "db" >/dev/null && gone_rc=0 || gone_rc=1
assert_eq "prune drops deleted/db" "1" "$gone_rc"

export HOME="$_orig_prune_home"
[[ -n $_orig_prune_xdg ]] && export XDG_STATE_HOME="$_orig_prune_xdg"
rm -rf "$PRUNE_HOME"
XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-port-available ss branch ==="

# Mock ss that always emits a single listener on port 12345. The real
# ss output format is: `LISTEN 0 128 0.0.0.0:PORT 0.0.0.0:*`. We prepend
# $PROBE_BIN to PATH so command -v ss picks up the mock.
PROBE_BIN=$(mktemp_d)
_probe_orig_PATH="$PATH"
cat >"$PROBE_BIN/ss" <<'MOCK_SS'
#!/bin/sh
echo "LISTEN 0 128 0.0.0.0:12345 0.0.0.0:*"
echo "LISTEN 0 128 [::]:12345 [::]:*"
MOCK_SS
chmod +x "$PROBE_BIN/ss"
export PATH="$PROBE_BIN:$_probe_orig_PATH"

__xcind-assigned-port-available 12345 && ss_busy_rc=0 || ss_busy_rc=$?
assert_eq "ss: busy port detected" "1" "$ss_busy_rc"
__xcind-assigned-port-available 12346 && ss_free_rc=0 || ss_free_rc=$?
assert_eq "ss: free port reported free" "0" "$ss_free_rc"

rm -f "$PROBE_BIN/ss"
export PATH="$_probe_orig_PATH"

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-port-available netstat branch ==="

# Hide ss via a command() override so the function falls through to the
# netstat branch. Mock netstat emits a canned Linux net-tools line.
cat >"$PROBE_BIN/netstat" <<'MOCK_NETSTAT'
#!/bin/sh
echo "tcp 0 0 0.0.0.0:12347 0.0.0.0:* LISTEN"
MOCK_NETSTAT
chmod +x "$PROBE_BIN/netstat"
export PATH="$PROBE_BIN:$_probe_orig_PATH"

# shellcheck disable=SC2317  # invoked indirectly via __xcind-assigned-port-available
command() {
  if [ "$1" = "-v" ] && [ "$2" = "ss" ]; then
    return 1
  fi
  builtin command "$@"
}

__xcind-assigned-port-available 12347 && ns_busy_rc=0 || ns_busy_rc=$?
assert_eq "netstat: busy port detected" "1" "$ns_busy_rc"
__xcind-assigned-port-available 12348 && ns_free_rc=0 || ns_free_rc=$?
assert_eq "netstat: free port reported free" "0" "$ns_free_rc"

# netstat that errors (BSD-style refusal) must fall through to /dev/tcp
cat >"$PROBE_BIN/netstat" <<'MOCK_NETSTAT_ERR'
#!/bin/sh
echo "netstat: option not supported" >&2
exit 1
MOCK_NETSTAT_ERR
chmod +x "$PROBE_BIN/netstat"

# Probe a port almost certainly free; failure here would indicate the
# function trusted the empty netstat output instead of falling through.
__xcind-assigned-port-available 65430 && ns_err_rc=0 || ns_err_rc=$?
assert_eq "netstat err: falls through to /dev/tcp (free)" "0" "$ns_err_rc"

unset -f command
rm -f "$PROBE_BIN/netstat"
export PATH="$_probe_orig_PATH"

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-port-available /dev/tcp branch ==="

# Hide both ss and netstat so the function falls through to /dev/tcp.
# Bind a real listener on an ephemeral port; the connect probe must see it.
if command -v python3 >/dev/null 2>&1; then
  # shellcheck disable=SC2317
  command() {
    if [ "$1" = "-v" ] && { [ "$2" = "ss" ] || [ "$2" = "netstat" ]; }; then
      return 1
    fi
    builtin command "$@"
  }

  PORT_FILE=$(mktemp)
  LISTENER_PID=""
  # Always reap the listener even if an assertion fails under set -e.
  # shellcheck disable=SC2317,SC2329  # invoked via trap
  _tcp_listener_cleanup() {
    if [ -n "${LISTENER_PID:-}" ]; then
      kill "$LISTENER_PID" 2>/dev/null || true
      wait "$LISTENER_PID" 2>/dev/null || true
    fi
    rm -f "$PORT_FILE"
  }
  trap _tcp_listener_cleanup EXIT

  # Bind to 127.0.0.1:0 so the kernel picks a free port for us.
  PORT_FILE="$PORT_FILE" python3 -c '
import os, socket, time
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen(1)
with open(os.environ["PORT_FILE"], "w") as f:
    f.write(str(s.getsockname()[1]))
time.sleep(30)
' &
  LISTENER_PID=$!

  # Wait for the listener to publish its port (up to ~1s)
  _waited=0
  while [ ! -s "$PORT_FILE" ] && [ "$_waited" -lt 20 ]; do
    sleep 0.05
    _waited=$((_waited + 1))
  done

  # Guard against a listener that crashed or stalled before publishing:
  # without this, BUSY_PORT would be empty and the probe would silently
  # test port "", giving a confusing failure under set -e.
  if [ ! -s "$PORT_FILE" ]; then
    if ! kill -0 "$LISTENER_PID" 2>/dev/null; then
      echo "ERROR: /dev/tcp test listener exited before publishing its port." >&2
    else
      echo "ERROR: /dev/tcp test listener did not publish its port within the expected time." >&2
    fi
    exit 1
  fi
  BUSY_PORT=$(<"$PORT_FILE")

  __xcind-assigned-port-available "$BUSY_PORT" && tcp_busy_rc=0 || tcp_busy_rc=$?
  assert_eq "/dev/tcp: busy port detected" "1" "$tcp_busy_rc"

  kill "$LISTENER_PID" 2>/dev/null || true
  wait "$LISTENER_PID" 2>/dev/null || true
  LISTENER_PID=""
  rm -f "$PORT_FILE"

  # After killing the listener the port should be free again. TIME_WAIT
  # does not affect a passive-side LISTEN socket teardown, so the probe
  # should immediately see the port as free.
  sleep 0.05
  __xcind-assigned-port-available "$BUSY_PORT" && tcp_free_rc=0 || tcp_free_rc=$?
  assert_eq "/dev/tcp: free port reported free" "0" "$tcp_free_rc"

  unset -f command
  trap - EXIT
  unset -f _tcp_listener_cleanup
else
  echo "  (skipped: python3 not available for /dev/tcp listener setup)"
fi

rm -rf "$PROBE_BIN"
unset _probe_orig_PATH

# ======================================================================
echo ""
echo "=== Test: __xcind-assigned-allocate-new ==="

# Stub port availability so the allocator sees a deterministic view
# instead of whatever ports happen to be in use on the test host.
# shellcheck disable=SC2317  # invoked indirectly via __xcind-assigned-allocate-new
__xcind-assigned-port-available() {
  local port="$1"
  # Simulate 3306 and 3307 taken, 3308 free
  if [ "$port" = "3306" ] || [ "$port" = "3307" ]; then
    return 1
  fi
  return 0
}

allocated=$(__xcind-assigned-allocate-new 3306)
assert_eq "allocate skips taken, finds 3308" "3308" "$allocated"

# All ports taken → error
# shellcheck disable=SC2317  # invoked indirectly via __xcind-assigned-allocate-new
__xcind-assigned-port-available() { return 1; }
XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS_orig="$XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS"
XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS=3
alloc_result=$(__xcind-assigned-allocate-new 4000 2>&1) && alloc_rc=0 || alloc_rc=$?
assert_eq "allocate fails after max attempts" "1" "$alloc_rc"
assert_contains "allocate error mentions ceiling" "no free host port" "$alloc_result"
XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS="$XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS_orig"
unset -f __xcind-assigned-port-available

# ======================================================================
echo ""
echo "=== Test: xcind-assigned-hook (YAML + sticky) ==="

AHOOK_APP=$(mktemp_d)
_orig_ahook_home="$HOME"
_orig_ahook_xdg="${XDG_STATE_HOME:-}"
HOME=$(mktemp_d)
export HOME
unset XDG_STATE_HOME
XCIND_ASSIGNED_DIR="${HOME}/.local/state/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"

export XCIND_APP="myapp"
export XCIND_WORKSPACE=""
export XCIND_SHA="assignedhook123"
export XCIND_CACHE_DIR="$AHOOK_APP/.xcind/cache/$XCIND_SHA"
export XCIND_GENERATED_DIR="$AHOOK_APP/.xcind/generated/$XCIND_SHA"
mkdir -p "$XCIND_CACHE_DIR" "$XCIND_GENERATED_DIR"

cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  mysql:
    image: mysql
    ports:
      - target: 3306
  redis:
    image: redis
    ports:
      - target: 6379
YAML

# Stub port availability: pretend everything is free in tests
# shellcheck disable=SC2317
__xcind-assigned-port-available() { return 0; }

# First run: expected to allocate 3306 and 6379 from clean state
XCIND_PROXY_EXPORTS=("db=mysql:3306;type=assigned" "cache=redis:6379;type=assigned")
hook_out=$(xcind-assigned-hook "$AHOOK_APP")
assert_contains "hook emits -f flag" "-f $XCIND_GENERATED_DIR/compose.assigned.yaml" "$hook_out"
assert_file_exists "compose.assigned.yaml created" "$XCIND_GENERATED_DIR/compose.assigned.yaml"

assigned_yaml=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
assert_contains "yaml has mysql service" "mysql:" "$assigned_yaml"
assert_contains "yaml has redis service" "redis:" "$assigned_yaml"
assert_contains "yaml has 3306:3306 mapping" '"3306:3306"' "$assigned_yaml"
assert_contains "yaml has 6379:6379 mapping" '"6379:6379"' "$assigned_yaml"

# State file reflects assignments
state=$(<"$XCIND_ASSIGNED_PORTS_FILE")
assert_contains "state file has db row" "db" "$state"
assert_contains "state file has cache row" "cache" "$state"
assert_contains "state file has app_path" "$AHOOK_APP" "$state"

# Second run: sticky, same ports should be reused (identity match)
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
xcind-assigned-hook "$AHOOK_APP" >/dev/null
assigned_yaml2=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
assert_contains "sticky: still 3306:3306" '"3306:3306"' "$assigned_yaml2"
assert_contains "sticky: still 6379:6379" '"6379:6379"' "$assigned_yaml2"

# Stale stickiness: pretend sticky port is no longer free so hook must reallocate
# shellcheck disable=SC2317
__xcind-assigned-port-available() {
  local port="$1"
  if [ "$port" = "3306" ]; then return 1; fi
  return 0
}
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
XCIND_PROXY_EXPORTS=("db=mysql:3306;type=assigned")
xcind-assigned-hook "$AHOOK_APP" >/dev/null
reassigned_yaml=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
assert_contains "reallocates away from taken port" '"3307:3306"' "$reassigned_yaml"

# Grouping: two exports on same compose service
# shellcheck disable=SC2317
__xcind-assigned-port-available() { return 0; }
cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  mysql:
    image: mysql
    ports:
      - target: 3306
YAML
# Reset state
: >"$XCIND_ASSIGNED_PORTS_FILE"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
XCIND_PROXY_EXPORTS=("db=mysql:3306;type=assigned" "db-alt=mysql:3307;type=assigned")
xcind-assigned-hook "$AHOOK_APP" >/dev/null
grouped=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
mysql_blocks=$(echo "$grouped" | grep -c '^  mysql:' || true)
assert_eq "single grouped mysql block" "1" "$mysql_blocks"
assert_contains "grouped: has 3306 port" '"3306:3306"' "$grouped"
assert_contains "grouped: has 3307 port" '"3307:3307"' "$grouped"

# Empty exports → no output
XCIND_PROXY_EXPORTS=()
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
empty_out=$(xcind-assigned-hook "$AHOOK_APP")
assert_eq "empty exports → no output" "" "$empty_out"
assert_eq "empty exports → no file" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.assigned.yaml" ] && echo true || echo false)"

# Unset exports → no output (set -u safe)
unset XCIND_PROXY_EXPORTS
unset_out=$(xcind-assigned-hook "$AHOOK_APP")
assert_eq "unset exports → no output" "" "$unset_out"

# Array populated but with no type=assigned entries → no output, no file
XCIND_PROXY_EXPORTS=("web" "api:3000")
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
noassigned_out=$(xcind-assigned-hook "$AHOOK_APP")
assert_eq "no assigned entries → no output" "" "$noassigned_out"
assert_eq "no assigned entries → no file" "false" \
  "$([ -f "$XCIND_GENERATED_DIR/compose.assigned.yaml" ] && echo true || echo false)"

# Mixed array: proxied entries are skipped by the assigned hook
cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  mysql:
    image: mysql
    ports:
      - target: 3306
  web:
    image: nginx
    ports:
      - target: 80
YAML
: >"$XCIND_ASSIGNED_PORTS_FILE"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
rm -f "$XCIND_GENERATED_DIR/compose.assigned.yaml"
XCIND_PROXY_EXPORTS=("web" "db=mysql:3306;type=assigned")
xcind-assigned-hook "$AHOOK_APP" >/dev/null
mixed_yaml=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
assert_contains "mixed: emits mysql entry" '"3306:3306"' "$mixed_yaml"
assert_not_contains "mixed: omits proxied web service" $'\n  web:' "$mixed_yaml"

# Port inference from compose
cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  redis:
    image: redis
    ports:
      - target: 6379
YAML
: >"$XCIND_ASSIGNED_PORTS_FILE"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
XCIND_PROXY_EXPORTS=("redis;type=assigned")
xcind-assigned-hook "$AHOOK_APP" >/dev/null
infer_yaml=$(<"$XCIND_GENERATED_DIR/compose.assigned.yaml")
assert_contains "inferred port 6379 from compose" '"6379:6379"' "$infer_yaml"

# Workspace column persisted when XCIND_WORKSPACE is set
XCIND_WORKSPACE_SAVED="$XCIND_WORKSPACE"
export XCIND_WORKSPACE="dev"
: >"$XCIND_ASSIGNED_PORTS_FILE"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
XCIND_PROXY_EXPORTS=("redis;type=assigned")
xcind-assigned-hook "$AHOOK_APP" >/dev/null
ws_row=$(awk -F'\t' '!/^#/ && NF>0 {print; exit}' "$XCIND_ASSIGNED_PORTS_FILE")
assert_contains "workspace row has dev" $'\tdev\t' "$ws_row"
export XCIND_WORKSPACE="$XCIND_WORKSPACE_SAVED"

# Service validation error
XCIND_PROXY_EXPORTS=("missing=nosuchservice:1234;type=assigned")
missing_result=$(xcind-assigned-hook "$AHOOK_APP" 2>&1) && missing_rc=0 || missing_rc=$?
assert_eq "missing service → error" "1" "$missing_rc"
assert_contains "missing service mentions not found" "not found" "$missing_result"

# Compose conflict warning — user compose already has 3306:3306 mapping
cat >"$XCIND_CACHE_DIR/resolved-config.yaml" <<'YAML'
services:
  mysql:
    image: mysql
    ports:
      - mode: ingress
        target: 3306
        published: "3307"
        protocol: tcp
YAML
: >"$XCIND_ASSIGNED_PORTS_FILE"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$XCIND_ASSIGNED_PORTS_FILE"
XCIND_PROXY_EXPORTS=("db=mysql:3306;type=assigned")
conflict_stderr=$(xcind-assigned-hook "$AHOOK_APP" 2>&1 >/dev/null)
assert_contains "compose conflict: warning emitted" "already maps container port 3306" "$conflict_stderr"
assert_contains "compose conflict: mentions host 3307" "3307" "$conflict_stderr"
# Still generates the overlay
assert_file_exists "compose conflict: overlay still generated" "$XCIND_GENERATED_DIR/compose.assigned.yaml"

unset -f __xcind-assigned-port-available
rm -rf "$AHOOK_APP" "$HOME"
HOME="$_orig_ahook_home"
export HOME
[[ -n $_orig_ahook_xdg ]] && export XDG_STATE_HOME="$_orig_ahook_xdg"
XCIND_ASSIGNED_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"
unset XCIND_PROXY_EXPORTS XCIND_APP XCIND_SHA XCIND_CACHE_DIR XCIND_GENERATED_DIR

# ======================================================================
echo ""
echo "=== Test: xcind-proxy release + prune CLI ==="

CLI_HOME=$(mktemp_d)
REAL_CLI_HOME="$HOME"
REAL_CLI_PATH="$PATH"
export HOME="$CLI_HOME"
export PATH="$CLI_HOME/bin:$PATH"
mkdir -p "$CLI_HOME/bin"
cat >"$CLI_HOME/bin/docker" <<'MOCKEOF'
#!/bin/sh
exit 0
MOCKEOF
chmod +x "$CLI_HOME/bin/docker"

# Seed state directly so release/prune have something to operate on. State
# now lives under $XDG_STATE_HOME/xcind/proxy/; unset it so the default
# $HOME/.local/state path is used.
_orig_cli_xdg="${XDG_STATE_HOME:-}"
unset XDG_STATE_HOME
mkdir -p "$CLI_HOME/.local/state/xcind/proxy" "$CLI_HOME/alive"
cat >"$CLI_HOME/.local/state/xcind/proxy/assigned-ports.tsv" <<EOF
# port	workspace	application	service	container_port	app_path	assigned_at
3306		alive	db	3306	$CLI_HOME/alive	2026-04-10T00:00:00Z
5432		gone	db	5432	$CLI_HOME/missing	2026-04-10T00:00:00Z
6379	dev	alive	cache	6379	$CLI_HOME/alive	2026-04-10T00:00:00Z
EOF

# release an existing port
release_out=$("$XCIND_ROOT/bin/xcind-proxy" release 3306 2>&1) && release_rc=0 || release_rc=$?
assert_eq "release existing exits 0" "0" "$release_rc"
assert_contains "release prints confirmation" "Released assigned port 3306" "$release_out"
state_after_release=$(<"$CLI_HOME/.local/state/xcind/proxy/assigned-ports.tsv")
assert_not_contains "state no longer has 3306 row" $'\n3306\t' "$state_after_release"

# release a port that does not exist → exit 1
release_missing=$("$XCIND_ROOT/bin/xcind-proxy" release 9999 2>&1) && release_missing_rc=0 || release_missing_rc=$?
assert_eq "release missing exits 1" "1" "$release_missing_rc"
assert_contains "release missing prints error" "No assignment found" "$release_missing"

# release requires a port argument
release_noarg=$("$XCIND_ROOT/bin/xcind-proxy" release 2>&1) && release_noarg_rc=0 || release_noarg_rc=$?
assert_eq "release without arg exits 1" "1" "$release_noarg_rc"
assert_contains "release usage message" "Usage: xcind-proxy release" "$release_noarg"

# release rejects non-numeric input
release_bad=$("$XCIND_ROOT/bin/xcind-proxy" release foo 2>&1) && release_bad_rc=0 || release_bad_rc=$?
assert_eq "release non-numeric exits 1" "1" "$release_bad_rc"
assert_contains "release non-numeric error" "must be a positive integer" "$release_bad"

# prune removes the /gone entry
prune_out=$("$XCIND_ROOT/bin/xcind-proxy" prune 2>&1) && prune_rc=0 || prune_rc=$?
assert_eq "prune exits 0" "0" "$prune_rc"
assert_contains "prune reports count" "Pruned 1" "$prune_out"
state_after_prune=$(<"$CLI_HOME/.local/state/xcind/proxy/assigned-ports.tsv")
assert_not_contains "prune removed gone row" "gone" "$state_after_prune"
assert_contains "prune kept alive row" "alive" "$state_after_prune"

# Status (text mode) renders the assigned-ports section with new prefix.
# The workspaceless row (alive/db was 3306, released; but bar-ish-shaped
# remaining workspaceless row was already pruned; the remaining row is
# 6379 with workspace=dev) should show the three-segment prefix.
status_out=$("$XCIND_ROOT/bin/xcind-proxy" status 2>&1)
assert_contains "status text shows Assigned ports header" "Assigned ports:" "$status_out"
assert_contains "status text shows 6379 row" "6379" "$status_out"
assert_contains "status text shows workspace/app/service prefix" "dev/alive/cache" "$status_out"

# Seed another row without workspace to assert the two-segment fallback
cat >>"$CLI_HOME/.local/state/xcind/proxy/assigned-ports.tsv" <<EOF
9000		alive	debug	9000	$CLI_HOME/alive	2026-04-10T00:00:00Z
EOF
status_out2=$("$XCIND_ROOT/bin/xcind-proxy" status 2>&1)
assert_contains "status text shows app/service fallback prefix" "alive/debug" "$status_out2"

# --json includes new column names. Status --json short-circuits when the
# proxy isn't initialized, so lay down a minimal fake compose file to take
# the `initialized: true` branch.
mkdir -p "$CLI_HOME/.local/state/xcind/proxy" "$CLI_HOME/.config/xcind/proxy"
cat >"$CLI_HOME/.local/state/xcind/proxy/docker-compose.yaml" <<'YAML'
name: xcind-proxy
services:
  traefik: { image: traefik:v3 }
YAML
status_json=$("$XCIND_ROOT/bin/xcind-proxy" status --json 2>&1)
assert_contains "status json has application field" '"application":"alive"' "$status_json"
assert_contains "status json has service field" '"service":"cache"' "$status_json"
assert_contains "status json has workspace field" '"workspace":"dev"' "$status_json"

export HOME="$REAL_CLI_HOME"
export PATH="$REAL_CLI_PATH"
[[ -n $_orig_cli_xdg ]] && export XDG_STATE_HOME="$_orig_cli_xdg"
rm -rf "$CLI_HOME"

# ======================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
