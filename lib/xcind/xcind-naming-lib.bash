#!/usr/bin/env bash
# xcind-naming-lib.bash — Project naming hook for generating compose.naming.yaml
#
# Provides xcind-naming-hook, a post-resolve-generate hook that sets the
# top-level Docker Compose `name:` field to prevent container/volume/network
# name collisions across workspaces with identically-named app directories.
#
# In workspace mode:     name: {workspace}-{instance}-{app}
# In workspaceless mode: name: {app}-{instance}
#
# XCIND_INSTANCE is the per-worktree isolation token (empty on the main
# checkout, so the name is byte-identical to today: {workspace}-{app} / {app}).
#
# This file is auto-sourced by xcind-lib.bash. The hook is registered by
# default and runs for all apps.

# --------------------------------------------------------------------------
# Hook Function
# --------------------------------------------------------------------------

# Main hook function called by the xcind pipeline on cache miss.
# Generates compose.naming.yaml with the top-level project name.
xcind-naming-hook() {
  local app_root="$1" # Hook contract requires this parameter
  : "$app_root"       # Unused in this hook but required by interface

  local app="${XCIND_APP:-$(basename "$app_root")}"
  local instance="${XCIND_INSTANCE:-}"
  local project_name

  # An empty instance leaves the name byte-identical to today; a non-empty one
  # folds in uniformly between workspace and app (see the table in the header).
  if [[ ${XCIND_WORKSPACELESS:-1} == "0" ]] && [[ -n ${XCIND_WORKSPACE:-} ]]; then
    if [[ -n $instance ]]; then
      project_name="${XCIND_WORKSPACE}-${instance}-${app}"
    else
      project_name="${XCIND_WORKSPACE}-${app}"
    fi
  else
    if [[ -n $instance ]]; then
      project_name="${app}-${instance}"
    else
      project_name="${app}"
    fi
  fi

  # Build output
  local output="name: ${project_name}"

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.naming.yaml"

  # Print compose flag to stdout
  echo "-f $XCIND_GENERATED_DIR/compose.naming.yaml"
}
