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

mktemp_d() {
  mktemp -d -p "$_XCIND_TEST_TMPROOT"
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
    XCIND_TOOLS \
    XCIND_ADDITIONAL_CONFIG_FILES \
    XCIND_ENV_FILES \
    XCIND_APP \
    XCIND_WORKSPACE \
    XCIND_WORKSPACE_ROOT \
    XCIND_WORKSPACELESS \
    XCIND_IS_WORKSPACE
  __XCIND_SOURCED_CONFIG_FILES=()
  # shellcheck disable=SC2034 # read by code-under-test via __xcind-build-compose-opts
  XCIND_DOCKER_COMPOSE_OPTS=()
}
