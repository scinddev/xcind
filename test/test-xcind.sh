#!/usr/bin/env bash
# shellcheck disable=SC2016
# test-xcind.sh — Verify xcind resolution logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$XCIND_ROOT/lib/xcind/xcind-lib.sh"

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

# ======================================================================
echo ""
echo "=== Test: __xcind-app-root ==="

# Set up a mock project
MOCK_PROJECT=$(mktemp -d)
mkdir -p "$MOCK_PROJECT/src/deep/nested"
echo '# test config' >"$MOCK_PROJECT/.xcind.sh"

# Test: find from project root
result=$(__xcind-app-root "$MOCK_PROJECT")
assert_eq "finds root from root" "$MOCK_PROJECT" "$result"

# Test: find from nested dir
result=$(__xcind-app-root "$MOCK_PROJECT/src/deep/nested")
assert_eq "finds root from nested" "$MOCK_PROJECT" "$result"

# Test: explicit XCIND_APP_ROOT overrides detection
# shellcheck disable=SC2034
XCIND_APP_ROOT="/explicit/path" result=$(__xcind-app-root "$MOCK_PROJECT/src")
assert_eq "XCIND_APP_ROOT override" "/explicit/path" "$result"
unset XCIND_APP_ROOT

# Test: fails when no .xcind.sh found
EMPTY_DIR=$(mktemp -d)
result=$(__xcind-app-root "$EMPTY_DIR" 2>/dev/null) && status=0 || status=$?
assert_eq "fails without .xcind.sh" "1" "$status"

rm -rf "$MOCK_PROJECT" "$EMPTY_DIR"

# ======================================================================
echo ""
echo "=== Test: __xcind-resolve-files ==="

# Set up a mock project with files
MOCK_PROJECT=$(mktemp -d)
mkdir -p "$MOCK_PROJECT/docker"

# Create some compose files
touch "$MOCK_PROJECT/docker/compose.yaml"
touch "$MOCK_PROJECT/docker/compose.override.yaml"
touch "$MOCK_PROJECT/docker/compose.common.yaml"
touch "$MOCK_PROJECT/docker/compose.dev.yaml"
touch "$MOCK_PROJECT/docker/compose.dev.override.yaml"
# compose.traefik.yaml does NOT exist (should be skipped)
# compose.common.override.yaml does NOT exist (should be skipped)

# Create env files
touch "$MOCK_PROJECT/.env"
touch "$MOCK_PROJECT/.env.local"
# .env.override does NOT exist

resolved=$(
  __xcind-resolve-files "$MOCK_PROJECT/docker" \
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
env_resolved=$(__xcind-resolve-files "$MOCK_PROJECT" ".env" ".env.local")

assert_contains "includes .env" "$MOCK_PROJECT/.env" "$env_resolved"
assert_contains "includes .env.local" "$MOCK_PROJECT/.env.local" "$env_resolved"
assert_not_contains "skips .env.override (doesn't exist)" \
  ".env.override" "$env_resolved"

# ======================================================================
echo ""
echo "=== Test: Variable expansion in file patterns ==="

export APP_ENV="dev"
var_resolved=$(
  __xcind-resolve-files "$MOCK_PROJECT/docker" \
    'compose.${APP_ENV}.yaml'
)

assert_contains 'expands ${APP_ENV} to dev' \
  "compose.dev.yaml" "$var_resolved"

assert_contains "derives override for expanded pattern" \
  "compose.dev.override.yaml" "$var_resolved"

# Test with a different APP_ENV value where file doesn't exist
export APP_ENV="prod"
prod_resolved=$(
  __xcind-resolve-files "$MOCK_PROJECT/docker" \
    'compose.${APP_ENV}.yaml'
)

assert_not_contains "skips compose.prod.yaml (doesn't exist)" \
  "compose.prod" "$prod_resolved"

unset APP_ENV

# ======================================================================
echo ""
echo "=== Test: __xcind-load-config + full resolution ==="

cat >"$MOCK_PROJECT/.xcind.sh" <<'EOF'
XCIND_COMPOSE_DIR="docker"
XCIND_COMPOSE_FILES=(
    "compose.yaml"
    "compose.common.yaml"
    "compose.dev.yaml"
)
XCIND_ENV_FILES=(
    ".env"
    ".env.local"
)
XCIND_BAKE_FILES=()
EOF

__xcind-load-config "$MOCK_PROJECT"

assert_eq "loads XCIND_COMPOSE_DIR" "docker" "$XCIND_COMPOSE_DIR"
assert_eq "loads 3 compose files" "3" "${#XCIND_COMPOSE_FILES[@]}"
assert_eq "loads 2 env files" "2" "${#XCIND_ENV_FILES[@]}"

# Test full compose opts build
__xcind-build-compose-opts "$MOCK_PROJECT"
opts="${XCIND_DOCKER_COMPOSE_OPTS[*]}"

assert_contains "opts include --env-file" "--env-file" "$opts"
assert_contains "opts include -f" "-f" "$opts"
assert_contains "opts include --project-directory" "--project-directory" "$opts"
assert_contains "opts include compose.override.yaml" "compose.override.yaml" "$opts"

# ======================================================================
echo ""
echo "=== Test: JSON output ==="

if command -v jq &>/dev/null; then
  json=$(__xcind-resolve-json "$MOCK_PROJECT")

  json_root=$(echo "$json" | jq -r '.projectRoot')
  assert_eq "JSON projectRoot" "$MOCK_PROJECT" "$json_root"

  json_compose_count=$(echo "$json" | jq '.composeFiles | length')
  # compose.yaml + compose.override.yaml + compose.common.yaml + compose.dev.yaml + compose.dev.override.yaml = 5
  assert_eq "JSON compose file count" "5" "$json_compose_count"

  json_env_count=$(echo "$json" | jq '.envFiles | length')
  # .env + .env.local = 2 (no overrides exist)
  assert_eq "JSON env file count" "2" "$json_env_count"
else
  echo "  (skipped: jq not installed)"
fi

# ======================================================================
# Cleanup
rm -rf "$MOCK_PROJECT"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
