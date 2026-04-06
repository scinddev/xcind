#!/usr/bin/env bash
# uninstall.sh — Remove xcind from a PREFIX directory
set -euo pipefail

PREFIX="${1:-/usr/local}"

echo "Uninstalling xcind from $PREFIX ..."

rm -f "$PREFIX/bin/xcind-compose"
rm -f "$PREFIX/bin/xcind-config"
rm -f "$PREFIX/bin/xcind-proxy"
rm -f "$PREFIX/lib/xcind/xcind-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-naming-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-proxy-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-workspace-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-app-env-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-host-gateway-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-completion-bash.bash"
rm -f "$PREFIX/lib/xcind/xcind-completion-zsh.bash"

# Remove the directory if empty
rmdir "$PREFIX/lib/xcind" 2>/dev/null || true

echo "Done."
