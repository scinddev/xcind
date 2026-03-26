# shellcheck shell=bash
# shellcheck disable=SC2034,SC2016
# .xcind.sh — Xcind application configuration (advanced example)
#
# This example demonstrates:
#   - Variable expansion in file patterns
#   - Multiple compose files with different concerns
#   - Bake file configuration (future use)

# --- Environment Files ---
XCIND_COMPOSE_ENV_FILES=(
  ".env"
  ".env.local"
  '.env.${APP_ENV}'
)

# --- Compose Files ---
XCIND_COMPOSE_DIR="docker"

# At runtime, if APP_ENV=dev, xcind resolves and checks for:
#   docker/compose.common.yaml
#   docker/compose.common.override.yaml    (auto-derived)
#   docker/compose.dev.yaml                (from ${APP_ENV} expansion)
#   docker/compose.dev.override.yaml       (auto-derived)
#   docker/compose.traefik.yaml
#   docker/compose.traefik.override.yaml   (auto-derived)
#
# Only files that exist on disk are included.
XCIND_COMPOSE_FILES=(
  "compose.common.yaml"
  'compose.${APP_ENV}.yaml'
  "compose.traefik.yaml"
)

# --- Bake Files ---
XCIND_BAKE_FILES=(
  "docker-bake.hcl"
)
