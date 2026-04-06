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
install -m 755 "$XCIND_ROOT/bin/xcind-proxy" "$PREFIX/bin/xcind-proxy"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-lib.bash" "$PREFIX/lib/xcind/xcind-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-naming-lib.bash" "$PREFIX/lib/xcind/xcind-naming-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-proxy-lib.bash" "$PREFIX/lib/xcind/xcind-proxy-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-workspace-lib.bash" "$PREFIX/lib/xcind/xcind-workspace-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-app-env-lib.bash" "$PREFIX/lib/xcind/xcind-app-env-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-host-gateway-lib.bash" "$PREFIX/lib/xcind/xcind-host-gateway-lib.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-completion-bash.bash" "$PREFIX/lib/xcind/xcind-completion-bash.bash"
install -m 644 "$XCIND_ROOT/lib/xcind/xcind-completion-zsh.bash" "$PREFIX/lib/xcind/xcind-completion-zsh.bash"

echo "Done."
echo ""
"$PREFIX/bin/xcind-config" --check || true
