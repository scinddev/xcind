#!/usr/bin/env bash
# test/lib/setup.sh — Shared setup / teardown helpers.
#
# Source after test/lib/assert.sh.

# All tempdirs created via mktemp_d live under a single root, so a single
# EXIT trap can clean them all up. This is important because mktemp_d is
# typically called as `VAR=$(mktemp_d)`, which runs the helper in a
# subshell — a subshell-local array would be discarded before the parent's
# trap ran, leaking every tempdir. Using a fixed root dir set once at
# source time sidesteps that.
_XCIND_TEST_TMPROOT=$(mktemp -d)
export _XCIND_TEST_TMPROOT

# Isolate the workspace registry. Workspace discovery auto-registers
# every workspace it finds, so without this each test run appends its
# tempdir fixtures to the developer's real
# ~/.local/state/xcind/workspaces.tsv. Exporting XDG_STATE_HOME covers
# child bin/xcind-* processes; the registry globals are rebound because
# xcind-lib.bash is sourced (and computes them) before this file. Tests
# that need their own registry still override XDG_STATE_HOME per call.
export XDG_STATE_HOME="$_XCIND_TEST_TMPROOT/state"
XCIND_REGISTRY_DIR="$XDG_STATE_HOME/xcind"
XCIND_REGISTRY_FILE="$XCIND_REGISTRY_DIR/workspaces.tsv"
XCIND_REGISTRY_LOCK="$XCIND_REGISTRY_DIR/workspaces.lock"
export XCIND_REGISTRY_DIR XCIND_REGISTRY_FILE XCIND_REGISTRY_LOCK

mktemp_d() {
  # Use the explicit-template form so we work on BSD mktemp (macOS) as
  # well as GNU coreutils; BSD mktemp has no `-p` / `--tmpdir` flag.
  mktemp -d "$_XCIND_TEST_TMPROOT/tmp.XXXXXX"
}

# shellcheck disable=SC2317 # registered as a trap
_xcind_cleanup_tmpdirs() {
  if [ -n "${_XCIND_TEST_TMPROOT:-}" ] && [ -d "$_XCIND_TEST_TMPROOT" ]; then
    rm -rf "$_XCIND_TEST_TMPROOT"
  fi
}
trap _xcind_cleanup_tmpdirs EXIT

# Reset the xcind config state that bleeds between test sections.
# Call at the top of every test block that loads a config, before any
# __xcind-load-config / __xcind-prepare-app invocation.
reset_xcind_state() {
  unset \
    XCIND_COMPOSE_FILES \
    XCIND_COMPOSE_DIR \
    XCIND_COMPOSE_ENV_FILES \
    XCIND_APP_ENV_FILES \
    XCIND_BAKE_FILES \
    XCIND_BINS \
    XCIND_SCRIPTS \
    XCIND_ADDITIONAL_CONFIG_FILES \
    XCIND_ENV_FILES \
    XCIND_APP \
    XCIND_WORKSPACE \
    XCIND_WORKSPACE_ROOT \
    XCIND_WORKSPACELESS \
    XCIND_IS_WORKSPACE
  __XCIND_SOURCED_CONFIG_FILES=()
  unset __XCIND_RUNNER_LOADED 2>/dev/null || true
  unset __XCIND_RUNNER_BIN_NAMES __XCIND_RUNNER_BIN_SERVICES \
    __XCIND_RUNNER_BIN_USES __XCIND_RUNNER_BIN_CMDS __XCIND_RUNNER_BIN_DESCS \
    __XCIND_RUNNER_SCRIPT_NAMES __XCIND_RUNNER_SCRIPT_DESCS \
    __XCIND_RUNNER_SCRIPT_STEPS 2>/dev/null || true
  # shellcheck disable=SC2034 # read by code-under-test via __xcind-build-compose-opts
  XCIND_DOCKER_COMPOSE_OPTS=()
}
