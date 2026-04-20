#!/usr/bin/env bash
# uninstall.sh — Remove xcind from a PREFIX directory
set -euo pipefail

PREFIX="${1:-/usr/local}"

echo "Uninstalling xcind from $PREFIX ..."

rm -f "$PREFIX/bin/xcind-app"
rm -f "$PREFIX/bin/xcind-application"
rm -f "$PREFIX/bin/xcind-compose"
rm -f "$PREFIX/bin/xcind-config"
rm -f "$PREFIX/bin/xcind-proxy"
rm -f "$PREFIX/bin/xcind-workspace"
rm -f "$PREFIX/lib/xcind/xcind-bootstrap.bash"
rm -f "$PREFIX/lib/xcind/xcind-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-naming-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-app-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-assigned-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-proxy-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-registry-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-workspace-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-app-env-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-host-gateway-lib.bash"
rm -f "$PREFIX/lib/xcind/xcind-completion-bash.bash"
rm -f "$PREFIX/lib/xcind/xcind-completion-zsh.bash"

# Remove the directory if empty
rmdir "$PREFIX/lib/xcind" 2>/dev/null || true

echo "Done."
