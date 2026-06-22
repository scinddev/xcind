#!/usr/bin/env bash
# shellcheck disable=SC2016
# test-xcind-prompt.sh — Verify the bin/xcind-prompt executable's output contract.
set -euo pipefail

# yq and jq are required runtime dependencies across the xcind test suites. The
# prompt helper's trimmed prepare is itself jq/yq-free, but this preflight is
# kept for harness consistency with test-xcind.sh / test-xcind-proxy.sh.
for _xcind_required in yq jq; do
  if ! command -v "$_xcind_required" >/dev/null 2>&1; then
    echo "ERROR: $_xcind_required is required to run the xcind test suite." >&2
    echo "  Install it (e.g. 'apt-get install $_xcind_required' or 'nix-shell -p $_xcind_required-go')." >&2
    exit 1
  fi
done
unset _xcind_required

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# NOTE: unlike test-xcind.sh, this suite does NOT source xcind-lib.bash. The
# prompt output contract is a binary-level contract, so every case exercises
# bin/xcind-prompt as a black-box subprocess. Sourcing the lib here would risk
# env bleed into those subprocesses.

PASS=0
FAIL=0
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/assert.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/setup.sh"

# ======================================================================
# Harness for the prompt subprocess
# ======================================================================

# Real "anchor" fixtures (user-facing examples/ docs); everything else is built
# per-test under mktemp_d.
PROMPT_WS_APP="$XCIND_ROOT/examples/workspaces/dev/frontend"
PROMPT_WS_SUB="$PROMPT_WS_APP/src"
PROMPT_WSLESS_APP="$XCIND_ROOT/examples/workspaceless/acmeapps"

# OSC 8 needles, built with printf so the terminal never interprets them and
# matched as RAW BYTES against captured stdout. The hyperlink intro is
# ESC ] 8 ; ; and the terminator is ST (ESC \, bytes 1b 5c) — NOT BEL (07).
PROMPT_OSC8=$(printf '\033]8;;')
# SC1003 misreads the literal-backslash escape; the format string is correct
# (ESC + backslash = the OSC 8 ST terminator), matching bin/xcind-prompt:138.
# shellcheck disable=SC1003
PROMPT_ST=$(printf '\033\\')

# Shared hermetic home: an empty mktemp_d so no machine-global proxy config.sh
# ($XDG_CONFIG_HOME/xcind/proxy/config.sh) can override a fixture's domain and
# no real workspace registry ($XDG_STATE_HOME/xcind/workspaces.tsv) leaks in.
PROMPT_HOME=$(mktemp_d)
PROMPT_ERR_FILE="$(mktemp_d)/stderr"

# Extra "VAR=value" assignments exported into the next subprocess only. The
# caller sets this before run_prompt; run_prompt resets it after each call so it
# never leaks to the following invocation.
PROMPT_EXTRA_ENV=()

# Drop identity vars a leaked environment may carry, so the prompt subprocess
# re-resolves them from its cwd. __xcind-app-root trusts a pre-set
# XCIND_APP_ROOT and __xcind-resolve-app trusts a pre-set XCIND_APP, so a leaked
# value would defeat directory-based detection and the override cases.
prompt_clear_env() {
  unset XCIND_APP_ROOT XCIND_APP XCIND_WORKSPACE XCIND_WORKSPACE_ROOT XCIND_WORKSPACELESS
}

# run_prompt <cwd> [args...] — sets prompt_out (stdout), prompt_rc (exit),
# prompt_err (stderr text). `|| prompt_rc=$?` keeps set -e from aborting on the
# expected non-zero exits (e.g. --detect outside an app, unknown option).
run_prompt() {
  local dir="$1"
  shift
  prompt_rc=0
  prompt_out=$(
    cd "$dir" || exit 99
    prompt_clear_env
    if [[ ${#PROMPT_EXTRA_ENV[@]} -gt 0 ]]; then
      export "${PROMPT_EXTRA_ENV[@]}"
    fi
    HOME="$PROMPT_HOME" XDG_STATE_HOME="$PROMPT_HOME/state" \
      XDG_CONFIG_HOME="$PROMPT_HOME/config" \
      "$XCIND_ROOT/bin/xcind-prompt" "$@" 2>"$PROMPT_ERR_FILE"
  ) || prompt_rc=$?
  prompt_err=$(<"$PROMPT_ERR_FILE")
  PROMPT_EXTRA_ENV=()
}

# run_prompt_sentinel <cwd> [args...] — like run_prompt but appends an '@'
# sentinel inside the subshell so a trailing newline survives $()'s strip: a
# trailing newline would leave "display\n@" (≠ "display@"). Sets prompt_sentinel.
# Only used on exit-0 display rows.
run_prompt_sentinel() {
  local dir="$1"
  shift
  prompt_sentinel=$(
    cd "$dir" || exit 99
    prompt_clear_env
    HOME="$PROMPT_HOME" XDG_STATE_HOME="$PROMPT_HOME/state" \
      XDG_CONFIG_HOME="$PROMPT_HOME/config" \
      "$XCIND_ROOT/bin/xcind-prompt" "$@"
    printf '@'
  )
}

# --- Fixture builders (Bash-3.2-safe; mirror the real examples/ layout) ------

# make_ws_app <wsdir> <appdir> <ws_extra> <app_body> — build a workspace app
# under a fresh mktemp_d. The workspace marker gets XCIND_IS_WORKSPACE=1 plus
# <ws_extra> (domain, optional XCIND_WORKSPACE override, optional apex template
# disable). The app .xcind.sh gets <app_body> (exports, optional XCIND_APP
# override). Echoes the app directory path (cwd to run from).
make_ws_app() {
  local wsdir="$1" appdir="$2" ws_extra="$3" app_body="$4"
  local root
  root=$(mktemp_d)
  mkdir -p "$root/$wsdir/$appdir"
  {
    printf '%s\n' 'XCIND_IS_WORKSPACE=1'
    printf '%s\n' "$ws_extra"
  } >"$root/$wsdir/.xcind.sh"
  printf '%s\n' "$app_body" >"$root/$wsdir/$appdir/.xcind.sh"
  printf '%s' "$root/$wsdir/$appdir"
}

# make_wsless_app <appdir> <app_body> — build a workspaceless app under a fresh
# mktemp_d (parent has no workspace marker). Echoes the app directory path.
make_wsless_app() {
  local appdir="$1" app_body="$2"
  local root
  root=$(mktemp_d)
  mkdir -p "$root/$appdir"
  printf '%s\n' "$app_body" >"$root/$appdir/.xcind.sh"
  printf '%s' "$root/$appdir"
}

# assert_scheme <label> <http|https> <host> <stdout> — assert the apex URL uses
# the expected scheme. Clean discriminator (D5): "http://<host>" is NOT a
# substring of "https://<host>" (the 's' sits before '://'), so each row both
# asserts its own scheme present AND the other absent.
assert_scheme() {
  local label="$1" want="$2" host="$3" out="$4"
  if [[ $want == https ]]; then
    assert_contains "$label: https://$host present" "https://$host" "$out"
    assert_not_contains "$label: http://$host absent" "http://$host" "$out"
  else
    assert_contains "$label: http://$host present" "http://$host" "$out"
    assert_not_contains "$label: https://$host absent" "https://$host" "$out"
  fi
}

# ======================================================================
echo "=== Test: xcind-prompt — A. Display contract ==="

# A1 — workspace app: "<workspace>/<app>", exit 0, stderr empty, no trailing \n.
run_prompt_sentinel "$PROMPT_WS_APP"
assert_eq "A1 workspace display + no trailing newline" "dev/frontend@" "$prompt_sentinel"
run_prompt "$PROMPT_WS_APP"
assert_eq "A1 workspace display stdout" "dev/frontend" "$prompt_out"
assert_eq "A1 workspace display exit 0" "0" "$prompt_rc"
assert_eq "A1 workspace display stderr empty" "" "$prompt_err"

# A2 — workspaceless app: "<app>", exit 0, stderr empty, no trailing \n.
run_prompt_sentinel "$PROMPT_WSLESS_APP"
assert_eq "A2 workspaceless display + no trailing newline" "acmeapps@" "$prompt_sentinel"
run_prompt "$PROMPT_WSLESS_APP"
assert_eq "A2 workspaceless display stdout" "acmeapps" "$prompt_out"
assert_eq "A2 workspaceless display exit 0" "0" "$prompt_rc"
assert_eq "A2 workspaceless display stderr empty" "" "$prompt_err"

# A3 — outside any app: empty stdout, exit 0, stderr empty.
prompt_a3_dir=$(mktemp_d)
run_prompt "$prompt_a3_dir"
assert_eq "A3 outside stdout empty" "" "$prompt_out"
assert_eq "A3 outside exit 0" "0" "$prompt_rc"
assert_eq "A3 outside stderr empty" "" "$prompt_err"

# A4 — override (workspace): .xcind.sh sets XCIND_WORKSPACE/XCIND_APP that differ
# from the directory basenames. Display must reflect the overrides, and the
# override must flow into the apex hostname.
prompt_a4_app=$(make_ws_app "realws" "realapp" \
  'XCIND_PROXY_DOMAIN="ovr.localhost"
XCIND_WORKSPACE="ovrws"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")
XCIND_APP="ovrapp"')
run_prompt_sentinel "$prompt_a4_app"
assert_eq "A4 override display (not dir basenames) + no trailing newline" "ovrws/ovrapp@" "$prompt_sentinel"
run_prompt "$prompt_a4_app"
assert_eq "A4 override display stdout" "ovrws/ovrapp" "$prompt_out"
assert_eq "A4 override display exit 0" "0" "$prompt_rc"
assert_eq "A4 override display stderr empty" "" "$prompt_err"
run_prompt "$prompt_a4_app" --apex
assert_contains "A4 override flows into apex host" "ovrws-ovrapp.ovr.localhost" "$prompt_out"

# A5 — override (workspaceless): app .xcind.sh sets XCIND_APP ≠ dir basename.
prompt_a5_app=$(make_wsless_app "realsolo" \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")
XCIND_APP="ovrsolo"')
run_prompt_sentinel "$prompt_a5_app"
assert_eq "A5 override display (not dir basename) + no trailing newline" "ovrsolo@" "$prompt_sentinel"
run_prompt "$prompt_a5_app"
assert_eq "A5 override display stdout" "ovrsolo" "$prompt_out"
assert_eq "A5 override display exit 0" "0" "$prompt_rc"
assert_eq "A5 override display stderr empty" "" "$prompt_err"

# ======================================================================
echo "=== Test: xcind-prompt — B. --detect ==="

# B1 — in app: empty stdout, exit 0, stderr empty.
run_prompt "$PROMPT_WS_APP" --detect
assert_eq "B1 --detect in-app stdout empty" "" "$prompt_out"
assert_eq "B1 --detect in-app exit 0" "0" "$prompt_rc"
assert_eq "B1 --detect in-app stderr empty" "" "$prompt_err"

# B2 — from a subdirectory: empty stdout, exit 0, stderr empty.
run_prompt "$PROMPT_WS_SUB" --detect
assert_eq "B2 --detect subdir stdout empty" "" "$prompt_out"
assert_eq "B2 --detect subdir exit 0" "0" "$prompt_rc"
assert_eq "B2 --detect subdir stderr empty" "" "$prompt_err"

# B3 — outside: empty stdout, NON-ZERO exit, stderr empty.
prompt_b3_dir=$(mktemp_d)
run_prompt "$prompt_b3_dir" --detect
assert_eq "B3 --detect outside stdout empty" "" "$prompt_out"
assert_not_contains "B3 --detect outside non-zero exit" "0" "$prompt_rc"
assert_eq "B3 --detect outside stderr empty" "" "$prompt_err"

# B4 — minimal detection, no trimmed-prepare (behavioral proof via SOURCE COUNT,
# D7). --detect does NOT source zero config: __xcind-app-root classifies every
# candidate .xcind.sh by sourcing it in a throwaway subshell (via
# __xcind-is-workspace-dir, xcind-lib.bash:161-166) to read XCIND_IS_WORKSPACE —
# that single workspace-probe source is the ONLY sourcing --detect performs. A
# plain run sources TWICE: the same probe PLUS the full __xcind-load-config
# trimmed-prepare. The fixture's .xcind.sh appends one byte per source, so the
# counts are observable: --detect → 1, plain → 2. This proves --detect skips the
# expensive config-load / apex stage (the real budget intent), not that it
# sources nothing.
prompt_b4_marker="$(mktemp_d)/sources"
prompt_b4_app=$(make_wsless_app "b4app" \
  "XCIND_PROXY_EXPORTS=(\"web=nginx:80\")
printf x >>\"$prompt_b4_marker\"")
rm -f "$prompt_b4_marker"
run_prompt "$prompt_b4_app" --detect
assert_eq "B4 --detect exit 0" "0" "$prompt_rc"
prompt_b4_detect_count=$(wc -c <"$prompt_b4_marker" | tr -d '[:space:]')
assert_eq "B4 --detect does only the 1 workspace-probe source (no config-load)" "1" "$prompt_b4_detect_count"
rm -f "$prompt_b4_marker"
run_prompt "$prompt_b4_app"
prompt_b4_plain_count=$(wc -c <"$prompt_b4_marker" | tr -d '[:space:]')
assert_eq "B4 plain run sources twice: probe + full config-load (control)" "2" "$prompt_b4_plain_count"

# ======================================================================
echo "=== Test: xcind-prompt — C. Apex presence / absence + permutations ==="

# C1 — --apex apex available: hostname substring + OSC 8 intro bytes + ST
# terminator (raw bytes), NOT BEL.
run_prompt "$PROMPT_WS_APP" --apex
assert_contains "C1 --apex contains apex hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_contains "C1 --apex emits OSC 8 intro bytes (ESC ] 8 ; ;)" "$PROMPT_OSC8" "$prompt_out"
assert_contains 'C1 --apex emits ST terminator (ESC \)' "$PROMPT_ST" "$prompt_out"
assert_eq "C1 --apex exit 0" "0" "$prompt_rc"
assert_eq "C1 --apex stderr empty" "" "$prompt_err"

# C2 — --apex with no proxied export: display only, no escape bytes.
run_prompt "$PROMPT_WSLESS_APP" --apex
assert_eq "C2 --apex no export yields display only" "acmeapps" "$prompt_out"
assert_not_contains "C2 --apex no export emits no OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# C3 — --apex with explicit-disable apex template (D6): a proxied export is
# present, but XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE="" disables apex.
prompt_c3_app=$(make_ws_app "c3ws" "c3app" \
  'XCIND_PROXY_DOMAIN="c3.localhost"
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_c3_app" --apex
assert_eq "C3 explicit-disable template yields display only" "c3ws/c3app" "$prompt_out"
assert_not_contains "C3 explicit-disable emits no OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"
assert_not_contains "C3 explicit-disable emits no apex host" "c3.localhost" "$prompt_out"

# C4 — --apex with an assigned-only export (D6): no proxied export to anchor the
# apex → no apex, even though the apex template is non-empty.
prompt_c4_app=$(make_wsless_app "c4app" \
  'XCIND_PROXY_DOMAIN="c4.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80;type=assigned")')
run_prompt "$prompt_c4_app" --apex
assert_eq "C4 assigned-only export yields display only" "c4app" "$prompt_out"
assert_not_contains "C4 assigned-only emits no OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"
assert_not_contains "C4 assigned-only emits no apex host" "c4.localhost" "$prompt_out"

# C5 — --apex --no-hyperlink: bare hostname, no OSC 8 bytes, no ST.
run_prompt "$PROMPT_WS_APP" --apex --no-hyperlink
assert_contains "C5 --no-hyperlink contains bare hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_not_contains "C5 --no-hyperlink omits OSC 8 intro bytes" "$PROMPT_OSC8" "$prompt_out"
assert_not_contains "C5 --no-hyperlink omits ST terminator" "$PROMPT_ST" "$prompt_out"

# C6 — XCIND_PROMPT_HYPERLINKS=0 --apex: equivalent to --no-hyperlink.
PROMPT_EXTRA_ENV=("XCIND_PROMPT_HYPERLINKS=0")
run_prompt "$PROMPT_WS_APP" --apex
assert_contains "C6 XCIND_PROMPT_HYPERLINKS=0 contains bare hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_not_contains "C6 XCIND_PROMPT_HYPERLINKS=0 omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# Scheme / TLS matrix (D5). Host is deterministic so http/https needles are
# unambiguous. All under the shared hermetic home (no machine TLS mode leaks in).
prompt_scheme_host="schemews-schemeapp.scheme.localhost"

# C7 — export tls=auto (default), proxy mode auto (default) → https.
prompt_c7_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_c7_app" --apex
assert_scheme "C7 tls=auto/mode=auto" "https" "$prompt_scheme_host" "$prompt_out"

# C8 — export tls=require → https.
prompt_c8_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80;tls=require")')
run_prompt "$prompt_c8_app" --apex
assert_scheme "C8 tls=require" "https" "$prompt_scheme_host" "$prompt_out"

# C9 — export tls=disable → http.
prompt_c9_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80;tls=disable")')
run_prompt "$prompt_c9_app" --apex
assert_scheme "C9 tls=disable" "http" "$prompt_scheme_host" "$prompt_out"

# C10 — proxy XCIND_PROXY_TLS_MODE=disabled overrides the export → http.
prompt_c10_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
PROMPT_EXTRA_ENV=("XCIND_PROXY_TLS_MODE=disabled")
run_prompt "$prompt_c10_app" --apex
assert_scheme "C10 proxy mode=disabled overrides export" "http" "$prompt_scheme_host" "$prompt_out"

# ======================================================================
echo "=== Test: xcind-prompt — D. Registry guard (hermetic) ==="

# D1 — a fresh hermetic home must contain no registry file after a workspace run
# (XCIND_NO_REGISTRY=1 is set before discovery).
prompt_d1_home=$(mktemp_d)
(
  cd "$PROMPT_WS_APP" || exit 99
  prompt_clear_env
  HOME="$prompt_d1_home" XDG_STATE_HOME="$prompt_d1_home/state" \
    XDG_CONFIG_HOME="$prompt_d1_home/config" \
    "$XCIND_ROOT/bin/xcind-prompt" >/dev/null 2>&1
) || true
assert_file_missing "D1 no workspace registry file created" "$prompt_d1_home/state/xcind/workspaces.tsv"

# D2 — a pre-seeded registry is byte-identical after the run (no in-place mutation).
prompt_d2_home=$(mktemp_d)
prompt_d2_reg="$prompt_d2_home/state/xcind/workspaces.tsv"
mkdir -p "$(dirname "$prompt_d2_reg")"
printf 'sentinel\tdo-not-touch\n' >"$prompt_d2_reg"
prompt_d2_before=$(cat "$prompt_d2_reg")
(
  cd "$PROMPT_WS_APP" || exit 99
  prompt_clear_env
  HOME="$prompt_d2_home" XDG_STATE_HOME="$prompt_d2_home/state" \
    XDG_CONFIG_HOME="$prompt_d2_home/config" \
    "$XCIND_ROOT/bin/xcind-prompt" >/dev/null 2>&1
) || true
prompt_d2_after=$(cat "$prompt_d2_reg")
assert_eq "D2 pre-seeded registry is byte-identical after run" "$prompt_d2_before" "$prompt_d2_after"

# ======================================================================
echo "=== Test: xcind-prompt — E. --print field selectors ==="

# E1 — --print both == default (workspace mode), byte-identical to A1.
run_prompt "$PROMPT_WS_APP" --print both
assert_eq "E1 --print both (workspace) stdout" "dev/frontend" "$prompt_out"
assert_eq "E1 --print both (workspace) exit 0" "0" "$prompt_rc"
assert_eq "E1 --print both (workspace) stderr empty" "" "$prompt_err"

# E2 — --print both == default (workspaceless).
run_prompt "$PROMPT_WSLESS_APP" --print both
assert_eq "E2 --print both (workspaceless) stdout" "acmeapps" "$prompt_out"
assert_eq "E2 --print both (workspaceless) exit 0" "0" "$prompt_rc"

# E3 — --print app (workspace): the app field only.
run_prompt "$PROMPT_WS_APP" --print app
assert_eq "E3 --print app (workspace) stdout" "frontend" "$prompt_out"
assert_eq "E3 --print app (workspace) stderr empty" "" "$prompt_err"

# E4 — --print app (workspaceless): the app field equals the display.
run_prompt "$PROMPT_WSLESS_APP" --print app
assert_eq "E4 --print app (workspaceless) stdout" "acmeapps" "$prompt_out"

# E5 — --print workspace (workspace): the workspace field only.
run_prompt "$PROMPT_WS_APP" --print workspace
assert_eq "E5 --print workspace (workspace) stdout" "dev" "$prompt_out"
assert_eq "E5 --print workspace (workspace) stderr empty" "" "$prompt_err"

# E6 — --print workspace (workspaceless): empty, exit 0.
run_prompt "$PROMPT_WSLESS_APP" --print workspace
assert_eq "E6 --print workspace (workspaceless) stdout empty" "" "$prompt_out"
assert_eq "E6 --print workspace (workspaceless) exit 0" "0" "$prompt_rc"
assert_eq "E6 --print workspace (workspaceless) stderr empty" "" "$prompt_err"

# E7 — --print workspace honors XCIND_WORKSPACE override (mirror A4).
prompt_e7_app=$(make_ws_app "realws" "realapp" \
  'XCIND_PROXY_DOMAIN="ovr.localhost"
XCIND_WORKSPACE="ovrws"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")
XCIND_APP="ovrapp"')
run_prompt "$prompt_e7_app" --print workspace
assert_eq "E7 --print workspace honors override" "ovrws" "$prompt_out"

# E8 — --print app honors XCIND_APP override (mirror A5).
prompt_e8_app=$(make_wsless_app "realsolo" \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")
XCIND_APP="ovrsolo"')
run_prompt "$prompt_e8_app" --print app
assert_eq "E8 --print app honors override" "ovrsolo" "$prompt_out"

# E9 — --print apex linked: apex host + OSC 8 intro + ST terminator, exit 0.
run_prompt "$PROMPT_WS_APP" --print apex
assert_contains "E9 --print apex contains apex hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_contains "E9 --print apex emits OSC 8 intro bytes" "$PROMPT_OSC8" "$prompt_out"
assert_contains 'E9 --print apex emits ST terminator (ESC \)' "$PROMPT_ST" "$prompt_out"
assert_eq "E9 --print apex exit 0" "0" "$prompt_rc"
assert_eq "E9 --print apex stderr empty" "" "$prompt_err"
prompt_e9_out="$prompt_out"

# E10 — --print apex --no-hyperlink: bare hostname, no OSC 8 bytes.
run_prompt "$PROMPT_WS_APP" --print apex --no-hyperlink
assert_contains "E10 --print apex --no-hyperlink bare hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_not_contains "E10 --print apex --no-hyperlink omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"
assert_not_contains "E10 --print apex --no-hyperlink omits ST terminator" "$PROMPT_ST" "$prompt_out"

# E11 — --print apex with XCIND_PROMPT_HYPERLINKS=0: bare hostname, no OSC 8.
PROMPT_EXTRA_ENV=("XCIND_PROMPT_HYPERLINKS=0")
run_prompt "$PROMPT_WS_APP" --print apex
assert_contains "E11 XCIND_PROMPT_HYPERLINKS=0 bare hostname" "dev-frontend.xcind.localhost" "$prompt_out"
assert_not_contains "E11 XCIND_PROMPT_HYPERLINKS=0 omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# E12 — --print apex no proxied export: empty, exit 0, no OSC 8.
run_prompt "$PROMPT_WSLESS_APP" --print apex
assert_eq "E12 --print apex no export stdout empty" "" "$prompt_out"
assert_eq "E12 --print apex no export exit 0" "0" "$prompt_rc"
assert_not_contains "E12 --print apex no export omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# E13 — --print apex with explicit-disable template (mirror C3): empty.
prompt_e13_app=$(make_ws_app "e13ws" "e13app" \
  'XCIND_PROXY_DOMAIN="e13.localhost"
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_e13_app" --print apex
assert_eq "E13 --print apex explicit-disable template empty" "" "$prompt_out"
assert_not_contains "E13 --print apex explicit-disable omits apex host" "e13.localhost" "$prompt_out"

# E14 — --print apex with assigned-only export (mirror C4): empty.
prompt_e14_app=$(make_wsless_app "e14app" \
  'XCIND_PROXY_DOMAIN="e14.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80;type=assigned")')
run_prompt "$prompt_e14_app" --print apex
assert_eq "E14 --print apex assigned-only empty" "" "$prompt_out"
assert_not_contains "E14 --print apex assigned-only omits apex host" "e14.localhost" "$prompt_out"

# E15 — --print app --apex: "<app> <linked apex>".
run_prompt "$PROMPT_WS_APP" --print app --apex
assert_eq "E15 --print app --apex starts with app + space" "frontend " "${prompt_out:0:9}"
assert_contains "E15 --print app --apex contains apex host" "dev-frontend.xcind.localhost" "$prompt_out"
assert_contains "E15 --print app --apex emits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# E16 — --print workspace --apex (workspace mode): "<workspace> <linked apex>".
run_prompt "$PROMPT_WS_APP" --print workspace --apex
assert_eq "E16 --print workspace --apex starts with workspace + space" "dev " "${prompt_out:0:4}"
assert_contains "E16 --print workspace --apex contains apex host" "dev-frontend.xcind.localhost" "$prompt_out"

# E17 — --print workspace --apex (workspaceless, apex present): apex link ONLY,
# NO leading space (HUMAN-1). The base workspace field is empty, so the first
# emitted byte must be the OSC 8 intro's ESC, never a space.
prompt_e17_app=$(make_wsless_app "e17app" \
  'XCIND_PROXY_DOMAIN="e17.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_e17_app" --print workspace --apex
assert_eq "E17 --print workspace --apex (workspaceless) no leading space" "$(printf '\033')" "${prompt_out:0:1}"
assert_contains "E17 --print workspace --apex (workspaceless) contains apex host" "e17.localhost" "$prompt_out"
assert_contains "E17 --print workspace --apex (workspaceless) emits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# E18 — --print apex --apex == --print apex (--apex ignored, no dup, no error).
run_prompt "$PROMPT_WS_APP" --print apex --apex
assert_eq "E18 --print apex --apex equals --print apex" "$prompt_e9_out" "$prompt_out"
assert_eq "E18 --print apex --apex exit 0" "0" "$prompt_rc"

# E19 — no trailing newline on every selector (sentinel '@' must abut the value).
run_prompt_sentinel "$PROMPT_WS_APP" --print app
assert_eq "E19 --print app no trailing newline" "frontend@" "$prompt_sentinel"
run_prompt_sentinel "$PROMPT_WS_APP" --print workspace
assert_eq "E19 --print workspace no trailing newline" "dev@" "$prompt_sentinel"
run_prompt_sentinel "$PROMPT_WS_APP" --print both
assert_eq "E19 --print both no trailing newline" "dev/frontend@" "$prompt_sentinel"
prompt_e19_nl_at=$(printf '\n@')
run_prompt_sentinel "$PROMPT_WS_APP" --print apex
assert_not_contains "E19 --print apex no trailing newline (no LF before @)" "$prompt_e19_nl_at" "$prompt_sentinel"
assert_eq "E19 --print apex sentinel ends with @" "@" "${prompt_sentinel: -1}"

# E20 — invalid --print value: exit 2, stdout empty, stderr names the error.
prompt_e20_dir=$(mktemp_d)
run_prompt "$prompt_e20_dir" --print bogus
assert_eq "E20 invalid --print value exit 2" "2" "$prompt_rc"
assert_eq "E20 invalid --print value stdout empty" "" "$prompt_out"
assert_contains "E20 invalid --print value stderr message" "invalid --print value" "$prompt_err"

# E21 — --print with no value: exit 2, stdout empty, stderr non-empty.
prompt_e21_dir=$(mktemp_d)
run_prompt "$prompt_e21_dir" --print
assert_eq "E21 --print missing value exit 2" "2" "$prompt_rc"
assert_eq "E21 --print missing value stdout empty" "" "$prompt_out"
assert_contains "E21 --print missing value stderr message" "--print requires a value" "$prompt_err"

# E22 — backward-compat: --print both --apex is byte-identical to today's --apex.
run_prompt "$PROMPT_WS_APP" --apex
prompt_e22_legacy="$prompt_out"
run_prompt "$PROMPT_WS_APP" --print both --apex
assert_eq "E22 --print both --apex byte-identical to --apex" "$prompt_e22_legacy" "$prompt_out"

# ======================================================================
echo "=== Test: xcind-prompt — F. Field-aware --detect ==="

# F1 — --detect in-app: exit 0, stdout+stderr empty (regression of B1).
run_prompt "$PROMPT_WS_APP" --detect
assert_eq "F1 --detect in-app exit 0" "0" "$prompt_rc"
assert_eq "F1 --detect in-app stdout empty" "" "$prompt_out"
assert_eq "F1 --detect in-app stderr empty" "" "$prompt_err"

# F2 — --detect --print both in-app: exit 0 (cheap path).
run_prompt "$PROMPT_WS_APP" --detect --print both
assert_eq "F2 --detect --print both exit 0" "0" "$prompt_rc"
assert_eq "F2 --detect --print both stderr empty" "" "$prompt_err"

# F3 — --detect --print app in-app + from subdir: exit 0 both.
run_prompt "$PROMPT_WS_APP" --detect --print app
assert_eq "F3 --detect --print app in-app exit 0" "0" "$prompt_rc"
run_prompt "$PROMPT_WS_SUB" --detect --print app
assert_eq "F3 --detect --print app subdir exit 0" "0" "$prompt_rc"

# F4 — --detect --print app outside: non-zero, stderr empty.
prompt_f4_dir=$(mktemp_d)
run_prompt "$prompt_f4_dir" --detect --print app
assert_not_contains "F4 --detect --print app outside non-zero" "0" "$prompt_rc"
assert_eq "F4 --detect --print app outside stderr empty" "" "$prompt_err"

# F5 — --detect --print workspace (workspace mode): exit 0.
run_prompt "$PROMPT_WS_APP" --detect --print workspace
assert_eq "F5 --detect --print workspace (workspace) exit 0" "0" "$prompt_rc"
assert_eq "F5 --detect --print workspace (workspace) stderr empty" "" "$prompt_err"

# F6 — --detect --print workspace (workspaceless): non-zero, stderr empty.
run_prompt "$PROMPT_WSLESS_APP" --detect --print workspace
assert_not_contains "F6 --detect --print workspace (workspaceless) non-zero" "0" "$prompt_rc"
assert_eq "F6 --detect --print workspace (workspaceless) stderr empty" "" "$prompt_err"

# F7 — --detect --print workspace outside: non-zero, stderr empty.
prompt_f7_dir=$(mktemp_d)
run_prompt "$prompt_f7_dir" --detect --print workspace
assert_not_contains "F7 --detect --print workspace outside non-zero" "0" "$prompt_rc"
assert_eq "F7 --detect --print workspace outside stderr empty" "" "$prompt_err"

# F8 — --detect --print apex with apex present: exit 0.
run_prompt "$PROMPT_WS_APP" --detect --print apex
assert_eq "F8 --detect --print apex (apex present) exit 0" "0" "$prompt_rc"
assert_eq "F8 --detect --print apex (apex present) stderr empty" "" "$prompt_err"

# F9 — --detect --print apex no proxied export: non-zero, stderr empty.
run_prompt "$PROMPT_WSLESS_APP" --detect --print apex
assert_not_contains "F9 --detect --print apex (no export) non-zero" "0" "$prompt_rc"
assert_eq "F9 --detect --print apex (no export) stderr empty" "" "$prompt_err"

# F10 — --detect --print apex explicit-disable template (mirror C3): non-zero.
prompt_f10_app=$(make_ws_app "f10ws" "f10app" \
  'XCIND_PROXY_DOMAIN="f10.localhost"
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_f10_app" --detect --print apex
assert_not_contains "F10 --detect --print apex (explicit-disable) non-zero" "0" "$prompt_rc"
assert_eq "F10 --detect --print apex (explicit-disable) stderr empty" "" "$prompt_err"

# F11 — --detect --print apex assigned-only export (mirror C4): non-zero.
prompt_f11_app=$(make_wsless_app "f11app" \
  'XCIND_PROXY_DOMAIN="f11.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80;type=assigned")')
run_prompt "$prompt_f11_app" --detect --print apex
assert_not_contains "F11 --detect --print apex (assigned-only) non-zero" "0" "$prompt_rc"
assert_eq "F11 --detect --print apex (assigned-only) stderr empty" "" "$prompt_err"

# F12 — --detect --print apex outside: non-zero, stderr empty.
prompt_f12_dir=$(mktemp_d)
run_prompt "$prompt_f12_dir" --detect --print apex
assert_not_contains "F12 --detect --print apex outside non-zero" "0" "$prompt_rc"
assert_eq "F12 --detect --print apex outside stderr empty" "" "$prompt_err"

# F13 — cost asymmetry via SOURCE COUNT (load-bearing; extends B4). A workspace
# fixture (so workspace-mode detect is exercisable) with a proxied export (so
# apex resolves). The app .xcind.sh appends one byte per source. The cheap
# arms (--detect, --detect --print app) do ONLY the 1 workspace-probe source;
# the field arms (--detect --print workspace|apex) run the trimmed prepare =
# 2 sources, matching a plain run. This proves the cheap path is preserved for
# both|app and that workspace|apex must source config to know availability.
prompt_f13_marker="$(mktemp_d)/sources"
prompt_f13_app=$(make_ws_app "f13ws" "f13app" \
  'XCIND_PROXY_DOMAIN="f13.localhost"' \
  "XCIND_PROXY_EXPORTS=(\"web=nginx:80\")
printf x >>\"$prompt_f13_marker\"")

rm -f "$prompt_f13_marker"
run_prompt "$prompt_f13_app" --detect
prompt_f13_detect=$(wc -c <"$prompt_f13_marker" | tr -d '[:space:]')
assert_eq "F13 --detect = 1 probe source (cheap path)" "1" "$prompt_f13_detect"

rm -f "$prompt_f13_marker"
run_prompt "$prompt_f13_app" --detect --print app
prompt_f13_app_cnt=$(wc -c <"$prompt_f13_marker" | tr -d '[:space:]')
assert_eq "F13 --detect --print app = 1 probe source (cheap path)" "1" "$prompt_f13_app_cnt"

rm -f "$prompt_f13_marker"
run_prompt "$prompt_f13_app" --detect --print workspace
prompt_f13_ws_cnt=$(wc -c <"$prompt_f13_marker" | tr -d '[:space:]')
assert_eq "F13 --detect --print workspace = 2 sources (trimmed prepare)" "2" "$prompt_f13_ws_cnt"

rm -f "$prompt_f13_marker"
run_prompt "$prompt_f13_app" --detect --print apex
prompt_f13_apex_cnt=$(wc -c <"$prompt_f13_marker" | tr -d '[:space:]')
assert_eq "F13 --detect --print apex = 2 sources (trimmed prepare)" "2" "$prompt_f13_apex_cnt"

rm -f "$prompt_f13_marker"
run_prompt "$prompt_f13_app"
prompt_f13_plain_cnt=$(wc -c <"$prompt_f13_marker" | tr -d '[:space:]')
assert_eq "F13 plain run = 2 sources (control: probe + config load)" "2" "$prompt_f13_plain_cnt"

# ======================================================================
echo "=== Test: xcind-prompt — G. --print apex-url (plain URL, no OSC 8) ==="

# apex-url emits field 1 of the apex TSV (the URL, "<scheme>://<hostname>"),
# always as PLAIN TEXT — no OSC 8 hyperlink, independent of --no-hyperlink /
# XCIND_PROMPT_HYPERLINKS. That no-escape-ever behavior is the differentiator
# from --print apex (which emits the OSC 8-linked hostname), proven by G4/G10.

# G1 — apex present, EXACT URL (mirror C7's https fixture: tls=auto/mode=auto).
# assert_eq on the full URL proves apex-url reads field 1 (the URL), not field 2
# (the bare host) — and that the scheme is rendered as plain text.
prompt_g1_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_g1_app" --print apex-url
assert_eq "G1 --print apex-url exact URL (https)" "https://schemews-schemeapp.scheme.localhost" "$prompt_out"
assert_eq "G1 --print apex-url exit 0" "0" "$prompt_rc"
assert_eq "G1 --print apex-url stderr empty" "" "$prompt_err"

# G2 — http variant (mirror C9's tls=disable fixture): proves both schemes render
# as plain text.
prompt_g2_app=$(make_ws_app "schemews" "schemeapp" \
  'XCIND_PROXY_DOMAIN="scheme.localhost"' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80;tls=disable")')
run_prompt "$prompt_g2_app" --print apex-url
assert_eq "G2 --print apex-url exact URL (http)" "http://schemews-schemeapp.scheme.localhost" "$prompt_out"

# G3 — apex present on the real anchor fixture (mirror E9): the URL contains the
# apex host preceded by "://"; exit 0, stderr empty.
run_prompt "$PROMPT_WS_APP" --print apex-url
assert_contains "G3 --print apex-url contains ://apex-host" "://dev-frontend.xcind.localhost" "$prompt_out"
assert_eq "G3 --print apex-url exit 0" "0" "$prompt_rc"
assert_eq "G3 --print apex-url stderr empty" "" "$prompt_err"
prompt_g3_out="$prompt_out"

# G4 — NO OSC 8 bytes EVEN WITHOUT --no-hyperlink (the differentiator vs apex,
# whose plain --print apex DOES emit OSC 8 per E9). apex-url never escapes.
assert_not_contains "G4 --print apex-url omits OSC 8 intro bytes (no flag)" "$PROMPT_OSC8" "$prompt_g3_out"
assert_not_contains "G4 --print apex-url omits ST terminator (no flag)" "$PROMPT_ST" "$prompt_g3_out"

# G5 — --no-hyperlink is a no-op: byte-identical to G3, still no OSC 8 (mirror E10).
run_prompt "$PROMPT_WS_APP" --print apex-url --no-hyperlink
assert_eq "G5 --print apex-url --no-hyperlink byte-identical to plain" "$prompt_g3_out" "$prompt_out"
assert_not_contains "G5 --print apex-url --no-hyperlink omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# G6 — XCIND_PROMPT_HYPERLINKS=0 is a no-op: same URL, no OSC 8 (mirror E11).
PROMPT_EXTRA_ENV=("XCIND_PROMPT_HYPERLINKS=0")
run_prompt "$PROMPT_WS_APP" --print apex-url
assert_eq "G6 XCIND_PROMPT_HYPERLINKS=0 byte-identical to plain" "$prompt_g3_out" "$prompt_out"
assert_not_contains "G6 XCIND_PROMPT_HYPERLINKS=0 omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# G7 — no proxied export: empty, exit 0, no OSC 8 (mirror E12).
run_prompt "$PROMPT_WSLESS_APP" --print apex-url
assert_eq "G7 --print apex-url no export stdout empty" "" "$prompt_out"
assert_eq "G7 --print apex-url no export exit 0" "0" "$prompt_rc"
assert_not_contains "G7 --print apex-url no export omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# G8 — explicit-disable apex template: empty (mirror E13/C3).
prompt_g8_app=$(make_ws_app "g8ws" "g8app" \
  'XCIND_PROXY_DOMAIN="g8.localhost"
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_g8_app" --print apex-url
assert_eq "G8 --print apex-url explicit-disable template empty" "" "$prompt_out"
assert_not_contains "G8 --print apex-url explicit-disable omits apex host" "g8.localhost" "$prompt_out"

# G9 — assigned-only export: empty (mirror E14/C4).
prompt_g9_app=$(make_wsless_app "g9app" \
  'XCIND_PROXY_DOMAIN="g9.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80;type=assigned")')
run_prompt "$prompt_g9_app" --print apex-url
assert_eq "G9 --print apex-url assigned-only empty" "" "$prompt_out"
assert_not_contains "G9 --print apex-url assigned-only omits apex host" "g9.localhost" "$prompt_out"

# G10 — --print apex-url --apex == --print apex-url (--apex ignored, no dup, no
# error, no OSC 8 appended) (mirror E18).
run_prompt "$PROMPT_WS_APP" --print apex-url --apex
assert_eq "G10 --print apex-url --apex equals --print apex-url" "$prompt_g3_out" "$prompt_out"
assert_eq "G10 --print apex-url --apex exit 0" "0" "$prompt_rc"
assert_not_contains "G10 --print apex-url --apex omits OSC 8 bytes" "$PROMPT_OSC8" "$prompt_out"

# G11 — no trailing newline (mirror E19): the sentinel '@' must abut the URL.
prompt_g11_nl_at=$(printf '\n@')
run_prompt_sentinel "$PROMPT_WS_APP" --print apex-url
assert_not_contains "G11 --print apex-url no trailing newline (no LF before @)" "$prompt_g11_nl_at" "$prompt_sentinel"
assert_eq "G11 --print apex-url sentinel ends with @" "@" "${prompt_sentinel: -1}"

# G12 — invalid --print value still exit 2; the new error string enumerates
# apex-url (regression guard + positive coverage of the updated validator).
prompt_g12_dir=$(mktemp_d)
run_prompt "$prompt_g12_dir" --print bogus
assert_eq "G12 invalid --print value exit 2" "2" "$prompt_rc"
assert_eq "G12 invalid --print value stdout empty" "" "$prompt_out"
assert_contains "G12 invalid --print value stderr lists apex-url" "apex-url" "$prompt_err"

# G13 — --detect --print apex-url with apex present: exit 0, stderr empty (F8).
run_prompt "$PROMPT_WS_APP" --detect --print apex-url
assert_eq "G13 --detect --print apex-url (apex present) exit 0" "0" "$prompt_rc"
assert_eq "G13 --detect --print apex-url (apex present) stderr empty" "" "$prompt_err"

# G14 — --detect --print apex-url no proxied export: non-zero, stderr empty (F9).
run_prompt "$PROMPT_WSLESS_APP" --detect --print apex-url
assert_not_contains "G14 --detect --print apex-url (no export) non-zero" "0" "$prompt_rc"
assert_eq "G14 --detect --print apex-url (no export) stderr empty" "" "$prompt_err"

# G15 — --detect --print apex-url explicit-disable template: non-zero (F10).
prompt_g15_app=$(make_ws_app "g15ws" "g15app" \
  'XCIND_PROXY_DOMAIN="g15.localhost"
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""' \
  'XCIND_PROXY_EXPORTS=("web=nginx:80")')
run_prompt "$prompt_g15_app" --detect --print apex-url
assert_not_contains "G15 --detect --print apex-url (explicit-disable) non-zero" "0" "$prompt_rc"
assert_eq "G15 --detect --print apex-url (explicit-disable) stderr empty" "" "$prompt_err"

# G16 — --detect --print apex-url assigned-only export: non-zero (F11).
prompt_g16_app=$(make_wsless_app "g16app" \
  'XCIND_PROXY_DOMAIN="g16.localhost"
XCIND_PROXY_EXPORTS=("web=nginx:80;type=assigned")')
run_prompt "$prompt_g16_app" --detect --print apex-url
assert_not_contains "G16 --detect --print apex-url (assigned-only) non-zero" "0" "$prompt_rc"
assert_eq "G16 --detect --print apex-url (assigned-only) stderr empty" "" "$prompt_err"

# G17 — --detect --print apex-url outside an app: non-zero, stderr empty (F12).
prompt_g17_dir=$(mktemp_d)
run_prompt "$prompt_g17_dir" --detect --print apex-url
assert_not_contains "G17 --detect --print apex-url outside non-zero" "0" "$prompt_rc"
assert_eq "G17 --detect --print apex-url outside stderr empty" "" "$prompt_err"

# G18 — detect cost: --detect --print apex-url runs the SAME trimmed prepare as
# apex = 2 sources (mirror F13's apex line). Proves apex-url wires into the
# trimmed-prepare arm, not a cheap stat-walk arm.
prompt_g18_marker="$(mktemp_d)/sources"
prompt_g18_app=$(make_ws_app "g18ws" "g18app" \
  'XCIND_PROXY_DOMAIN="g18.localhost"' \
  "XCIND_PROXY_EXPORTS=(\"web=nginx:80\")
printf x >>\"$prompt_g18_marker\"")
rm -f "$prompt_g18_marker"
run_prompt "$prompt_g18_app" --detect --print apex-url
prompt_g18_cnt=$(wc -c <"$prompt_g18_marker" | tr -d '[:space:]')
assert_eq "G18 --detect --print apex-url = 2 sources (trimmed prepare)" "2" "$prompt_g18_cnt"

# ======================================================================
echo "=== Test: xcind-prompt — usage / unknown option (stderr path) ==="

# --help: exit 0, usage on stdout, stderr empty.
run_prompt "$PROMPT_WS_APP" --help
assert_eq "--help exit 0" "0" "$prompt_rc"
assert_contains "--help prints usage to stdout" "Usage: xcind-prompt" "$prompt_out"
assert_eq "--help stderr empty" "" "$prompt_err"

# unknown option: exit 2, message on stderr, stdout empty.
prompt_unknown_dir=$(mktemp_d)
run_prompt "$prompt_unknown_dir" --bogus
assert_eq "unknown option exit 2" "2" "$prompt_rc"
assert_eq "unknown option stdout empty" "" "$prompt_out"
assert_contains "unknown option writes message to stderr" "unknown option" "$prompt_err"

# ======================================================================
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
