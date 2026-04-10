#!/usr/bin/env bash
# xcind-bootstrap.bash — Shared startup for bin/ scripts
#
# Each bin/ script sources this file after setting `set -euo pipefail`.
# Bootstrap exports XCIND_ROOT and sources xcind-lib.bash, so the calling
# script gets the full xcind environment in one step.
#
# Each bin/ script cannot source this file by absolute path because
# XCIND_ROOT is not known until bootstrap computes it. Every caller
# therefore carries a minimal symlink-resolving stub that follows the
# chain of symlinks of its own BASH_SOURCE[0], then sources this file
# via "$(dirname <resolved>)/../lib/xcind/xcind-bootstrap.bash".
#
# macOS lacks `readlink -f`, so the resolver must be a manual loop.

# Follow the chain of symlinks to resolve <target> to its real path.
# Mirrors the inline stub in each bin/ script. Kept here so future
# pipeline setup code in bootstrap can reuse it.
__xcind_resolve_link() {
  local target="$1"
  while [ -L "$target" ]; do
    local dir
    dir=$(cd "$(dirname "$target")" && pwd)
    target=$(readlink "$target")
    [[ $target != /* ]] && target="$dir/$target"
  done
  printf '%s\n' "$(cd "$(dirname "$target")" && pwd)/$(basename "$target")"
}

# BASH_SOURCE[1] is the bin/ script that sourced this file. Resolving
# its symlinks and walking two levels up gives the xcind install root
# (.../bin/xcind-compose → .../).
XCIND_ROOT="$(cd "$(dirname "$(__xcind_resolve_link "${BASH_SOURCE[1]}")")" && cd .. && pwd)"

# shellcheck disable=SC1091
source "$XCIND_ROOT/lib/xcind/xcind-lib.bash"
