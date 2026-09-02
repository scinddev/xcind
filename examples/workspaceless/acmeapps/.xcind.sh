# shellcheck shell=bash
# shellcheck disable=SC2034
# .xcind.sh — Xcind application configuration for acmeapps
#
# This file is sourced by xcind-compose to determine which Docker Compose
# files, environment files, and other settings apply to this application.
#
# It is also the marker file that xcind uses to detect the app root:
# xcind walks upward from $PWD until it finds a directory containing .xcind.sh.
#
# Shell variable expansion is supported in file patterns. For example,
# "compose.\${APP_ENV}.yaml" will expand at runtime based on the current
# value of APP_ENV.

# --- Environment Files ---
# Listed in load order. For each entry, xcind also checks for an .override
# variant (e.g., .env → .env.override) and includes it if present.
XCIND_COMPOSE_ENV_FILES=(
  ".env"
  ".env.local"
)

# --- Compose Files ---
# Subdirectory where compose files live (relative to app root).
# If set, file patterns below are resolved relative to this directory.
# If unset, they're resolved relative to the app root.
XCIND_COMPOSE_DIR="docker"

# Listed in load order. For each entry, xcind also checks for an .override
# variant (e.g., compose.common.yaml → compose.common.override.yaml).
# Files that don't exist on disk are silently skipped.
XCIND_COMPOSE_FILES=(
  "compose.yaml"
  "compose.dev.yaml"
)

# --- Bake Files (reserved for future use) ---
# XCIND_BAKE_FILES=(
#     "docker-bake.hcl"
# )

# --- Bins ---
# Declare which bins are available in which Compose service.
# Format: name:service[;key=value…]
# Keys: cmd (default = name), use = exec|run, desc
XCIND_BINS=(
  "node:app"
  "npm:app"
)

# --- Scripts ---
# Declarative step lists run by xcind-run. Steps go one per line and stop
# at the first failure; a leading '-' ignores that step's failure. The
# first '#' comment is the script's description. '@name' runs a bin or
# another script; other lines run on the host.
XCIND_SCRIPTS=(
  "fresh:
    # Reinstall node modules from scratch
    -rm -rf node_modules
    @npm install"
)
