# shellcheck shell=bash
# shellcheck disable=SC2034
# .xcind.sh — Workspace configuration for "dev"
#
# This file marks the directory as a workspace root. When xcind discovers
# an app inside this directory, it sources this file first to set up
# workspace-level settings (proxy domain, hooks, templates).

XCIND_IS_WORKSPACE=1

# --- Proxy Configuration ---
XCIND_PROXY_DOMAIN="xcind.localhost"

# --- Hook Libraries ---
# Source the proxy and workspace hook libraries so apps in this workspace
# can declare XCIND_PROXY_EXPORTS and get automatic Traefik + networking config.

# Resolve the lib directory relative to the xcind binary on $PATH.
# In a real install, xcind-compose is on $PATH and the libs live alongside it.
# For this example we resolve relative to the repo root.
_XCIND_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/lib/xcind"

if [[ -f "$_XCIND_LIB_DIR/xcind-proxy-lib.bash" ]]; then
  # shellcheck disable=SC1091
  source "$_XCIND_LIB_DIR/xcind-proxy-lib.bash"
fi

if [[ -f "$_XCIND_LIB_DIR/xcind-workspace-lib.bash" ]]; then
  # shellcheck disable=SC1091
  source "$_XCIND_LIB_DIR/xcind-workspace-lib.bash"
fi

# --- Hooks ---
XCIND_HOOKS_POST_RESOLVE_GENERATE=(
  "xcind-proxy-hook"
  "xcind-workspace-hook"
)
