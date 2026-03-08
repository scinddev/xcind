#!/usr/bin/env bash
# uninstall.sh — Remove xcind from a PREFIX directory
set -euo pipefail

PREFIX="${1:-/usr/local}"

echo "Uninstalling xcind from $PREFIX ..."

rm -f "$PREFIX/bin/xcind-compose"
rm -f "$PREFIX/bin/xcind-config"
rm -f "$PREFIX/lib/xcind/xcind-lib.bash"

# Remove the directory if empty
rmdir "$PREFIX/lib/xcind" 2>/dev/null || true

echo "Done."
