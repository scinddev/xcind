# shellcheck shell=bash
# shellcheck disable=SC2034
# .xcind.sh — Xcind application configuration for frontend
#
# This app lives inside the "dev" workspace. The workspace .xcind.sh
# is sourced first, providing proxy/workspace hooks automatically.

# --- Compose Files ---
XCIND_COMPOSE_FILES=(
  "compose.yaml"
)

# --- Environment Files ---
XCIND_COMPOSE_ENV_FILES=(
  ".env"
)

# --- Proxy Exports ---
# Expose the nginx service as "web" through the reverse proxy.
# Format: export_name=compose_service:port
# Resulting hostname: dev-frontend-web.xcind.localhost
XCIND_PROXY_EXPORTS=(
  "web=nginx:80"
)
