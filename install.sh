#!/usr/bin/env bash
# install.sh — Install xcind to a PREFIX directory
set -euo pipefail

XCIND_ROOT="${0%/*}"
PREFIX="${1:-/usr/local}"

echo "Installing xcind to $PREFIX ..."

install -d "$PREFIX/bin"
install -d "$PREFIX/lib/xcind"

install -m 755 "$XCIND_ROOT/bin/xcind-compose" "$PREFIX/bin/xcind-compose"
install -m 755 "$XCIND_ROOT/bin/xcind-config" "$PREFIX/bin/xcind-config"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-lib.bash" "$PREFIX/lib/xcind/xcind-lib.bash"

echo "Done."
