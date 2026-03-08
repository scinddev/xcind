#!/usr/bin/env bash
# install.sh — Install xcind to a PREFIX directory
set -euo pipefail

PREFIX="${1:-/usr/local}"

echo "Installing xcind to $PREFIX ..."

install -d "$PREFIX/bin"
install -d "$PREFIX/lib/xcind"

install -m 755 bin/xcind-compose "$PREFIX/bin/xcind-compose"
install -m 755 bin/xcind-config "$PREFIX/bin/xcind-config"
install -m 644 lib/xcind/xcind-lib.sh "$PREFIX/lib/xcind/xcind-lib.sh"

echo "Done."
