#!/usr/bin/env bash
# xcind-registry-lib.bash — Workspace discovery registry
#
# Persists the set of workspace directories the user has interacted with,
# so `xcind-workspace list` can answer "which workspaces do I have?"
# without a filesystem scan.
#
# The registry is a flat TSV under the XDG state directory. Rows carry an
# absolute workspace path plus the timestamp it was first registered.
# Workspace metadata (name, proxy domain, app count) is resolved at list
# time by sourcing `.xcind.sh` in a subshell, mirroring how
# __xcind-is-workspace-dir already works — no cached fields means no drift.
#
# Writes are serialized with flock(1) when available, matching the
# assigned-ports lib's pattern. All registry writes MUST be invoked in a
# silent, failure-tolerant way from hook points (e.g.,
# __xcind-discover-workspace) so that a readonly state home can never
# break `xcind-compose up`.
#
# This file is auto-sourced by xcind-lib.bash.

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

XCIND_REGISTRY_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/xcind"
XCIND_REGISTRY_FILE="${XCIND_REGISTRY_DIR}/workspaces.tsv"
XCIND_REGISTRY_LOCK="${XCIND_REGISTRY_DIR}/workspaces.lock"

# TSV header written to new state files for human readability.
XCIND_REGISTRY_HEADER=$'# path\tregistered_at'

# --------------------------------------------------------------------------
# State file initialization
# --------------------------------------------------------------------------

# Ensure the state directory and file exist. Writes the TSV header to a
# newly created file. Safe to call unlocked — only creates missing files.
__xcind-registry-ensure-state-file() {
  mkdir -p "$XCIND_REGISTRY_DIR"
  if [[ ! -f $XCIND_REGISTRY_FILE ]]; then
    printf '%s\n' "$XCIND_REGISTRY_HEADER" >"$XCIND_REGISTRY_FILE"
  fi
}

# --------------------------------------------------------------------------
# Row parsing + shared read/rewrite helpers
# --------------------------------------------------------------------------

# Split a tab-separated line into two named fields, preserving empties.
# Consumes one line argument; sets L_path and L_reg_ts in the caller's
# scope. The caller must declare them `local`.
__xcind-registry-split-row() {
  local line="$1"
  L_path="${line%%$'\t'*}"
  L_reg_ts="${line#*$'\t'}"
  # When the line has no tab, L_reg_ts would equal L_path after the above
  # suffix-strip. Normalize to empty so the header/truncated row case is
  # handled cleanly.
  if [[ $L_reg_ts == "$L_path" ]]; then
    L_reg_ts=""
  fi
  return 0
}

# Iterate data rows of the registry, invoking $callback with the two TSV
# fields followed by any extra arguments.
#
# Callback signature: L_path L_reg_ts "$@"
#
# Iteration stops as soon as the callback returns non-zero. A missing state
# file is treated as empty; iter returns 0 and the callback is not invoked.
__xcind-registry-iter() {
  local callback="$1"
  shift
  [[ -f $XCIND_REGISTRY_FILE ]] || return 0
  local L_path L_reg_ts
  local __row
  while IFS= read -r __row; do
    [[ -z $__row ]] && continue
    [[ ${__row:0:1} == "#" ]] && continue
    __xcind-registry-split-row "$__row"
    "$callback" "$L_path" "$L_reg_ts" "$@" || return $?
  done <"$XCIND_REGISTRY_FILE"
  return 0
}

# Rewrite the registry in place, keeping only rows for which $predicate
# returns 0. Callers MUST already hold the registry lock
# (__xcind-with-registry-lock).
__xcind-registry-rewrite() {
  local predicate="$1"
  shift
  __xcind-registry-ensure-state-file

  local tmp="${XCIND_REGISTRY_FILE}.tmp"
  printf '%s\n' "$XCIND_REGISTRY_HEADER" >"$tmp"

  local L_path L_reg_ts
  local __row
  while IFS= read -r __row; do
    [[ -z $__row ]] && continue
    [[ ${__row:0:1} == "#" ]] && continue
    __xcind-registry-split-row "$__row"
    if "$predicate" "$L_path" "$L_reg_ts" "$@"; then
      printf '%s\t%s\n' "$L_path" "$L_reg_ts" >>"$tmp"
    fi
  done <"$XCIND_REGISTRY_FILE"

  mv -- "$tmp" "$XCIND_REGISTRY_FILE"
}

# --------------------------------------------------------------------------
# Critical section helper
# --------------------------------------------------------------------------

# Run the given command holding an exclusive lock on the registry lock
# file. When flock(1) is unavailable (e.g., stock macOS) the command still
# runs, unlocked — mirrors __xcind-with-assigned-lock.
__xcind-with-registry-lock() {
  __xcind-registry-ensure-state-file
  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      "$@"
    ) 200>"$XCIND_REGISTRY_LOCK"
  else
    "$@"
  fi
}

# --------------------------------------------------------------------------
# Path helpers
# --------------------------------------------------------------------------

# Canonicalize a directory path. Resolves relative paths via `cd && pwd`,
# matching __xcind-workspace-find-root's resolution (no -P — we don't
# normalize symlinks). Returns 1 without printing if the path is not a
# directory.
__xcind-registry-abs-path() {
  local p="$1"
  if [[ -d $p ]]; then
    (cd "$p" && pwd)
    return 0
  fi
  return 1
}

# --------------------------------------------------------------------------
# Registry mutators (callers MUST hold the registry lock)
# --------------------------------------------------------------------------

# Upsert a workspace path. If the path is already present, this is a no-op
# — we keep the original registered_at timestamp to preserve "first seen"
# semantics. The path must already be absolute.
__xcind-registry-add() {
  local abs_path="$1"
  [[ -n $abs_path ]] || return 1

  __xcind-registry-ensure-state-file

  # Fast path: already present? No-op. The probe callback returns non-zero
  # to short-circuit iteration on a hit — guard the call so set -e doesn't
  # treat that short-circuit as an error.
  __xcind_registry_add_target="$abs_path"
  __xcind_registry_add_found=0
  if ! __xcind-registry-iter __xcind-registry-add-probe; then
    :
  fi
  local found=$__xcind_registry_add_found
  unset __xcind_registry_add_target __xcind_registry_add_found
  [[ $found -eq 1 ]] && return 0

  local ts
  ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")
  printf '%s\t%s\n' "$abs_path" "$ts" >>"$XCIND_REGISTRY_FILE"
}

__xcind-registry-add-probe() {
  local L_path="$1"
  if [[ $L_path == "$__xcind_registry_add_target" ]]; then
    __xcind_registry_add_found=1
    return 1
  fi
  return 0
}

# Remove any entry matching the exact absolute path. No-op if not found.
__xcind-registry-remove() {
  local abs_path="$1"
  [[ -n $abs_path ]] || return 1
  [[ -f $XCIND_REGISTRY_FILE ]] || return 0
  __xcind-registry-rewrite __xcind-registry-keep-not-path "$abs_path"
}

__xcind-registry-keep-not-path() {
  local L_path="$1"
  local target_path="$3"
  [[ $L_path == "$target_path" ]] && return 1
  return 0
}

# Remove rows whose path is no longer a workspace directory (either the
# directory is gone, or .xcind.sh no longer has XCIND_IS_WORKSPACE=1).
# Prints the number of entries pruned.
__xcind-registry-prune() {
  __xcind_registry_prune_count=0
  __xcind-registry-rewrite __xcind-registry-keep-if-workspace
  printf '%s\n' "$__xcind_registry_prune_count"
  unset __xcind_registry_prune_count
}

__xcind-registry-keep-if-workspace() {
  local L_path="$1"
  if [[ ! -d $L_path ]] || ! __xcind-is-workspace-dir "$L_path"; then
    __xcind_registry_prune_count=$((__xcind_registry_prune_count + 1))
    return 1
  fi
  return 0
}
