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
XCIND_ENV_FILES=(
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
