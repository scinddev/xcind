# shellcheck shell=bash
# shellcheck disable=SC2034
# .xcind.sh — Xcind application configuration for backend
#
# This app lives inside the "dev" workspace. The workspace .xcind.sh
# is sourced first, providing proxy/workspace hooks automatically.

# --- Compose Files ---
XCIND_COMPOSE_FILES=(
  "compose.yaml"
)

# --- Environment Files ---
XCIND_ENV_FILES=(
  ".env"
)

# --- Proxy Exports ---
# Expose the app service as "api" through the reverse proxy.
# Port is inferred from compose.yaml (single port mapping → 3000).
# Resulting hostname: dev-backend-api.xcind.localhost
XCIND_PROXY_EXPORTS=(
  "api=app:3000"
)
