#!/usr/bin/env bash
# xcind-bootstrap.bash — Shared startup for bin/ scripts
#
# Each bin/ script sources this file after setting `set -euo pipefail`
# and XCIND_ROOT (computed from its own symlink-resolved BASH_SOURCE).
# Bootstrap then sources xcind-lib.bash, so the calling script gets
# the full xcind shell environment in one step. Keeping this as a
# separate file (rather than inlining the source directly in each bin
# stub) gives us a single place to add shared setup logic in the
# future — hook discovery, env-var defaults, etc. — without touching
# four callers.

if [[ -z ${XCIND_ROOT:-} ]]; then
  echo "xcind-bootstrap: XCIND_ROOT is not set; call from a bin/ stub." >&2
  # shellcheck disable=SC2317 # reachable when bootstrap is sourced
  return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
source "$XCIND_ROOT/lib/xcind/xcind-lib.bash"
