# shellcheck shell=bash
# shellcheck disable=SC2034
# .xcind.sh — Workspace configuration for "dev"
#
# This file marks the directory as a workspace root. When xcind discovers
# an app inside this directory, it sources this file first to set up
# workspace-level settings (proxy domain, templates).

XCIND_IS_WORKSPACE=1

# --- Proxy Configuration ---
XCIND_PROXY_DOMAIN="xcind.localhost"
