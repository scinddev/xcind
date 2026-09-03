#!/usr/bin/env bash
# test-xcind-completion.sh — Behavioral tests for the shell completion functions
#
# Drives the completion functions the way an interactive shell does — by
# setting COMP_WORDS/COMP_CWORD (bash) or words/CURRENT (zsh) and inspecting
# what the function offers — rather than grepping the completion scripts.
#
# The load-bearing claim under test is in docs/guides/tools-ide-integration.md:
# "xcind-compose delegates to Docker's own completion, so you get the full
# `docker compose` UX." That is verified here by asserting that completions
# include subcommands and flags which the hardcoded fallback does NOT know.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
SKIP=0
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/assert.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/setup.sh"

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

# Source the completion script through the real distribution path — the same
# bytes a user gets from `. <(xcind-config completion bash)`.
COMPLETION_TMP=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-config" completion bash >"$COMPLETION_TMP/xcind.bash"

_source_rc=0
# shellcheck disable=SC1091
source "$COMPLETION_TMP/xcind.bash" || _source_rc=$?
assert_eq "bash completion script sources cleanly" "0" "$_source_rc"

# comp_run MODE FUNC WORD... — invoke a completion function and print each
# COMPREPLY entry on its own line.
#
#   MODE=fresh   cursor sits after a trailing space (current word is empty);
#                bash leaves COMP_WORDS[COMP_CWORD] unset, so COMP_CWORD == $#
#   MODE=partial the last WORD is the partial word under the cursor
#
# Runs in a subshell with errexit/nounset off, because interactive completion
# runs that way: the functions read unset array slots and call `compopt`,
# which fails outside a real completion context.
comp_run() {
  local mode="$1" func="$2"
  shift 2
  (
    set +e +u
    COMP_WORDS=("$@")
    if [ "$mode" = "fresh" ]; then
      COMP_CWORD=$#
    else
      COMP_CWORD=$(($# - 1))
    fi
    COMPREPLY=()
    "$func" >/dev/null 2>&1
    printf '%s\n' "${COMPREPLY[@]}"
  )
}

# ======================================================================
echo "=== Test: xcind-compose — delegated docker compose completion ==="

if ! command -v docker >/dev/null 2>&1 ||
  ! docker __complete compose "" >/dev/null 2>&1; then
  echo "  … SKIP: docker with __complete support not available"
  SKIP=$((SKIP + 1))
else
  out=$(comp_run fresh _xcind_compose_completions xcind-compose)
  assert_line "subcommand 'up' offered" "up" "$out"
  assert_line "subcommand 'down' offered" "down" "$out"
  assert_line "subcommand 'ps' offered" "ps" "$out"

  # The proof of delegation: these exist in `docker compose` but are absent
  # from __xcind_compose_fallback's hardcoded list. If the fallback fired
  # instead, these lines would be missing.
  assert_line "delegation: 'ls' offered (not in fallback list)" "ls" "$out"
  assert_line "delegation: 'watch' offered (not in fallback list)" "watch" "$out"
  assert_line "delegation: 'cp' offered (not in fallback list)" "cp" "$out"

  # Docker's own descriptions must be stripped; only the value is completed.
  assert_no_line "descriptions stripped from completions" \
    "logs	View output from containers" "$out"

  out=$(comp_run partial _xcind_compose_completions xcind-compose lo)
  assert_line "partial word 'lo' completes to 'logs'" "logs" "$out"
  assert_no_line "partial word 'lo' excludes 'up'" "up" "$out"

  # Flag completion for a subcommand — the fallback offers nothing at all
  # past word 1, so any result here can only come from Docker.
  out=$(comp_run partial _xcind_compose_completions xcind-compose up --)
  assert_line "delegation: 'up --' offers --detach" "--detach" "$out"
  assert_line "delegation: 'up --' offers --build" "--build" "$out"

  out=$(comp_run partial _xcind_compose_completions xcind-compose logs --)
  assert_line "delegation: 'logs --' offers --follow" "--follow" "$out"

  # The strongest evidence for the "full docker compose UX" claim: Docker
  # reads the project's compose file and completes SERVICE NAMES, which no
  # hardcoded list could ever produce. Runs in a throwaway project so the
  # expected names cannot come from anywhere else.
  COMPOSE_PROJECT=$(mktemp_d)
  cat >"$COMPOSE_PROJECT/compose.yaml" <<'PROJEOF'
services:
  xcindtestweb:
    image: nginx
  xcindtestdb:
    image: postgres
PROJEOF

  out=$(cd "$COMPOSE_PROJECT" && comp_run fresh _xcind_compose_completions xcind-compose logs)
  assert_line "delegation: 'logs ' completes service xcindtestweb" "xcindtestweb" "$out"
  assert_line "delegation: 'logs ' completes service xcindtestdb" "xcindtestdb" "$out"

  out=$(cd "$COMPOSE_PROJECT" && comp_run partial _xcind_compose_completions xcind-compose exec xcindtestw)
  assert_line "delegation: partial service name completes" "xcindtestweb" "$out"
  assert_no_line "delegation: partial service name filters" "xcindtestdb" "$out"
fi

# ======================================================================
echo "=== Test: xcind-compose — fallback when docker is unavailable ==="

# Shadow docker with a stub that produces no completion output, so the
# __complete call fails and the hardcoded fallback must carry the
# completion. Shadowing (rather than emptying PATH) keeps grep and the rest
# of the harness working.
NO_DOCKER_BIN=$(mktemp_d)
cat >"$NO_DOCKER_BIN/docker" <<'STUBEOF'
#!/bin/sh
# Stub docker without Cobra __complete support
exit 127
STUBEOF
chmod +x "$NO_DOCKER_BIN/docker"
SAVED_PATH="$PATH"
export PATH="$NO_DOCKER_BIN:$PATH"

out=$(comp_run fresh _xcind_compose_completions xcind-compose)
assert_line "fallback offers 'up'" "up" "$out"
assert_line "fallback offers 'logs'" "logs" "$out"
assert_no_line "fallback does not invent 'watch'" "watch" "$out"

out=$(comp_run partial _xcind_compose_completions xcind-compose lo)
assert_line "fallback filters by partial word" "logs" "$out"
assert_no_line "fallback partial word excludes 'up'" "up" "$out"

out=$(comp_run partial _xcind_compose_completions xcind-compose up --)
assert_eq "fallback offers nothing past word 1" "" "$out"

export PATH="$SAVED_PATH"

# ======================================================================
echo "=== Test: xcind-config completion ==="

out=$(comp_run fresh _xcind_config_completions xcind-config)
assert_line "top level offers 'resolve'" "resolve" "$out"
assert_line "top level offers 'doctor'" "doctor" "$out"
assert_line "top level offers 'completion'" "completion" "$out"
assert_line "top level offers --json" "--json" "$out"
assert_line "top level offers --generate-starship" "--generate-starship" "$out"

out=$(comp_run partial _xcind_config_completions xcind-config --generate-d)
assert_line "partial --generate-d offers docker wrapper" \
  "--generate-docker-wrapper" "$out"
assert_line "partial --generate-d offers compose wrapper" \
  "--generate-docker-compose-wrapper" "$out"
assert_no_line "partial --generate-d excludes --generate-starship" \
  "--generate-starship" "$out"

out=$(comp_run fresh _xcind_config_completions xcind-config completion)
assert_line "'completion ' offers bash" "bash" "$out"
assert_line "'completion ' offers zsh" "zsh" "$out"
assert_no_line "'completion ' offers no subcommands" "resolve" "$out"

out=$(comp_run fresh _xcind_config_completions xcind-config doctor)
assert_eq "'doctor ' offers only --json" "--json" "$out"

out=$(comp_run fresh _xcind_config_completions xcind-config resolve)
assert_line "'resolve ' offers metadata" "metadata" "$out"
assert_line "'resolve ' offers composeFiles" "composeFiles" "$out"
assert_line "'resolve ' offers apex" "apex" "$out"
assert_line "'resolve ' offers bins" "bins" "$out"
assert_line "'resolve ' offers scripts" "scripts" "$out"
assert_line "'resolve ' offers compose. prefix" "compose." "$out"

out=$(comp_run fresh _xcind_config_completions xcind-config resolve metadata)
assert_line "'resolve KEY ' offers --cached" "--cached" "$out"
assert_line "'resolve KEY ' offers --hooks-ttl=" "--hooks-ttl=" "$out"
assert_no_line "'resolve KEY ' stops offering keys" "metadata" "$out"

out=$(comp_run fresh _xcind_config_completions xcind-config --generate-starship --format)
assert_line "'--format ' offers toml" "toml" "$out"
assert_line "'--format ' offers nix" "nix" "$out"

# The offered resolve keys must match the keys bin/xcind-config documents.
# A key that only completion knows about is a lie to the user.
resolve_help=$("$XCIND_ROOT/bin/xcind-config" resolve --help 2>&1 || true)
keys=$(comp_run fresh _xcind_config_completions xcind-config resolve)
missing=""
while IFS= read -r key; do
  [ -z "$key" ] && continue
  case "$key" in --help) continue ;; esac
  case "$resolve_help" in
  *"$key"*) ;;
  *) missing="$missing $key" ;;
  esac
done <<<"$keys"
assert_eq "every completed resolve key appears in 'resolve --help'" "" "$missing"

# ======================================================================
echo "=== Test: xcind-proxy completion ==="

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy)
for sub in init up down dispose status logs release prune; do
  assert_line "top level offers '$sub'" "$sub" "$out"
done
assert_line "top level offers --version" "--version" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy init)
assert_line "'init ' offers --mode" "--mode" "$out"
assert_line "'init ' offers --tls-mode" "--tls-mode" "$out"
assert_line "'init ' offers --proxy-domain" "--proxy-domain" "$out"

out=$(comp_run partial _xcind_proxy_completions xcind-proxy init --tls)
assert_line "partial '--tls' offers --tls-mode" "--tls-mode" "$out"
assert_line "partial '--tls' offers --tls-cert-file" "--tls-cert-file" "$out"
assert_no_line "partial '--tls' excludes --mode" "--mode" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy init --mode)
assert_line "'--mode ' offers managed" "managed" "$out"
assert_line "'--mode ' offers external" "external" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy init --tls-mode)
assert_line "'--tls-mode ' offers auto" "auto" "$out"
assert_line "'--tls-mode ' offers custom" "custom" "$out"
assert_line "'--tls-mode ' offers disabled" "disabled" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy init --dashboard)
assert_line "'--dashboard ' offers true" "true" "$out"
assert_line "'--dashboard ' offers false" "false" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy up)
assert_eq "'up ' offers only --force" "--force" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy dispose)
assert_line "'dispose ' offers --purge" "--purge" "$out"
assert_line "'dispose ' offers --yes" "--yes" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy status)
assert_eq "'status ' offers only --json" "--json" "$out"

out=$(comp_run fresh _xcind_proxy_completions xcind-proxy logs)
assert_line "'logs ' offers --follow" "--follow" "$out"
assert_line "'logs ' offers --tail" "--tail" "$out"

# Free-text flag values must not fall back to the subcommand list.
out=$(comp_run fresh _xcind_proxy_completions xcind-proxy init --network)
assert_eq "'--network ' offers nothing" "" "$out"

# Every completed top-level subcommand must be one xcind-proxy accepts.
proxy_help=$("$XCIND_ROOT/bin/xcind-proxy" --help 2>&1 || true)
subs=$(comp_run fresh _xcind_proxy_completions xcind-proxy)
missing=""
while IFS= read -r sub; do
  [ -z "$sub" ] && continue
  case "$sub" in -*) continue ;; esac
  case "$proxy_help" in
  *"$sub"*) ;;
  *) missing="$missing $sub" ;;
  esac
done <<<"$subs"
assert_eq "every completed proxy subcommand appears in --help" "" "$missing"

# ======================================================================
echo "=== Test: xcind-workspace completion ==="

# Both functions mix flag words with `compgen -d`, so the directory-completing
# cases run inside a throwaway tree with known subdirectory names.
DIR_FIXTURE=$(mktemp_d)
mkdir -p "$DIR_FIXTURE/svc-alpha" "$DIR_FIXTURE/svc-beta"

out=$(comp_run fresh _xcind_workspace_completions xcind-workspace)
for sub in init up down restart dispose status list register forget; do
  assert_line "top level offers '$sub'" "$sub" "$out"
done
assert_line "top level offers --version" "--version" "$out"

out=$(comp_run fresh _xcind_workspace_completions xcind-workspace init)
assert_line "'init ' offers --name" "--name" "$out"
assert_line "'init ' offers --proxy-domain" "--proxy-domain" "$out"
assert_no_line "'init ' excludes --json" "--json" "$out"

# A flag typed after the target directory still resolves against "init".
out=$(comp_run partial _xcind_workspace_completions \
  xcind-workspace init ./project --n)
assert_eq "'init DIR --n' offers only --name" "--name" "$out"

out=$(comp_run fresh _xcind_workspace_completions xcind-workspace init --name)
assert_eq "'--name ' offers nothing" "" "$out"

out=$(comp_run fresh _xcind_workspace_completions xcind-workspace status)
assert_eq "'status ' offers only --json" "--json" "$out"

out=$(comp_run fresh _xcind_workspace_completions xcind-workspace list)
assert_line "'list ' offers --json" "--json" "$out"
assert_line "'list ' offers --prune" "--prune" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace up)
assert_line "'up ' offers a directory" "svc-alpha" "$out"
assert_no_line "'up ' excludes --yes" "--yes" "$out"
assert_line "'up ' offers -a" "-a" "$out"
assert_line "'up ' offers --app" "--app" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace down)
assert_line "'down ' offers --yes" "--yes" "$out"
assert_line "'down ' offers a directory" "svc-alpha" "$out"
assert_line "'down ' offers --volumes" "--volumes" "$out"
assert_line "'down ' offers -a" "-a" "$out"
assert_line "'down ' offers --app" "--app" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_workspace_completions \
  xcind-workspace down --)
assert_line "'down --' offers --yes" "--yes" "$out"
assert_line "'down --' offers --volumes" "--volumes" "$out"
assert_no_line "'down --' drops directories" "svc-alpha" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace restart)
assert_line "'restart ' offers --yes" "--yes" "$out"
assert_line "'restart ' offers a directory" "svc-alpha" "$out"
assert_line "'restart ' offers -a" "-a" "$out"
assert_line "'restart ' offers --app" "--app" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_workspace_completions \
  xcind-workspace restart --)
assert_line "'restart --' offers --yes" "--yes" "$out"
assert_no_line "'restart --' drops directories" "svc-alpha" "$out"

# `-a`/`--app` after up/down/restart completes app-directory basenames when
# $PWD is inside a workspace (heuristic: grep for XCIND_IS_WORKSPACE=1,
# not a full source — the completion scripts must stay self-contained).
WS_FIXTURE=$(mktemp_d)
mkdir -p "$WS_FIXTURE/api" "$WS_FIXTURE/web"
printf 'XCIND_IS_WORKSPACE=1\n' >"$WS_FIXTURE/.xcind.sh"
printf 'XCIND_COMPOSE_FILES=("compose.yaml")\n' >"$WS_FIXTURE/api/.xcind.sh"
printf 'XCIND_COMPOSE_FILES=("compose.yaml")\n' >"$WS_FIXTURE/web/.xcind.sh"

out=$(cd "$WS_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace down -a)
assert_line "'down -a ' offers an app-directory basename" "api" "$out"
assert_line "'down -a ' offers the other app-directory basename" "web" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace up -a)
assert_eq "'up -a ' offers nothing outside a workspace" "" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace dispose)
assert_line "'dispose ' offers --volumes" "--volumes" "$out"
assert_line "'dispose ' offers a directory" "svc-alpha" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_workspace_completions \
  xcind-workspace dispose --)
assert_line "'dispose --' offers --rm" "--rm" "$out"
assert_no_line "'dispose --' drops directories" "svc-alpha" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace register)
assert_line "'register ' offers a directory" "svc-beta" "$out"
assert_no_line "'register ' stops offering subcommands" "init" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_workspace_completions \
  xcind-workspace forget)
assert_line "'forget ' offers a directory" "svc-beta" "$out"

# Every completed top-level subcommand must be one xcind-workspace accepts.
workspace_help=$("$XCIND_ROOT/bin/xcind-workspace" --help 2>&1 || true)
subs=$(comp_run fresh _xcind_workspace_completions xcind-workspace)
missing=""
while IFS= read -r sub; do
  [ -z "$sub" ] && continue
  case "$sub" in -*) continue ;; esac
  case "$workspace_help" in
  *"$sub"*) ;;
  *) missing="$missing $sub" ;;
  esac
done <<<"$subs"
assert_eq "every completed workspace subcommand appears in --help" "" "$missing"

# ======================================================================
echo "=== Test: xcind-application completion ==="

out=$(comp_run fresh _xcind_application_completions xcind-application)
for sub in init dispose status list ports urls exports; do
  assert_line "top level offers '$sub'" "$sub" "$out"
done
assert_line "top level offers --help" "--help" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_application_completions \
  xcind-application init)
assert_line "'init ' offers --name" "--name" "$out"
assert_line "'init ' offers a directory" "svc-alpha" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_application_completions \
  xcind-application init --)
assert_eq "'init --' offers only --name" "--name" "$out"

out=$(comp_run fresh _xcind_application_completions \
  xcind-application init --name)
assert_eq "'--name ' offers nothing" "" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_application_completions \
  xcind-application dispose)
assert_line "'dispose ' offers --yes" "--yes" "$out"
assert_line "'dispose ' offers a directory" "svc-beta" "$out"

out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_application_completions \
  xcind-application dispose --v)
assert_eq "'dispose --v' offers only --volumes" "--volumes" "$out"

for sub in status list ports urls exports; do
  out=$(cd "$DIR_FIXTURE" && comp_run partial _xcind_application_completions \
    xcind-application "$sub" --)
  assert_eq "'$sub --' offers only --json" "--json" "$out"
done

out=$(cd "$DIR_FIXTURE" && comp_run fresh _xcind_application_completions \
  xcind-application status)
assert_line "'status ' offers a directory" "svc-alpha" "$out"

# Every completed top-level subcommand must be one xcind-application accepts.
application_help=$("$XCIND_ROOT/bin/xcind-application" --help 2>&1 || true)
subs=$(comp_run fresh _xcind_application_completions xcind-application)
missing=""
while IFS= read -r sub; do
  [ -z "$sub" ] && continue
  case "$sub" in -*) continue ;; esac
  case "$application_help" in
  *"$sub"*) ;;
  *) missing="$missing $sub" ;;
  esac
done <<<"$subs"
assert_eq "every completed application subcommand appears in --help" "" "$missing"

# ======================================================================
echo "=== Test: xcind-run completion ==="

out=$(comp_run partial _xcind_run_completions xcind-run --)
assert_line "xcind-run '--' offers --list" "--list" "$out"
assert_line "xcind-run '--' offers --names" "--names" "$out"
assert_line "xcind-run '--' offers --init-shell" "--init-shell" "$out"
assert_line "xcind-run '--' offers --prefix" "--prefix" "$out"
assert_line "xcind-run '--' offers --no-tty" "--no-tty" "$out"

out=$(comp_run partial _xcind_run_completions xcind-run -)
assert_line "xcind-run '-' offers -T" "-T" "$out"

out=$(comp_run fresh _xcind_run_completions xcind-run --prefix)
assert_eq "xcind-run '--prefix ' offers nothing" "" "$out"

out=$(comp_run fresh _xcind_run_completions xcind-run somename)
assert_eq "xcind-run offers nothing after a name" "" "$out"

out=$(comp_run fresh _xcind_run_completions xcind-run --list somename)
assert_eq "xcind-run offers nothing after a name (with flags)" "" "$out"

# Name completion shells out to `xcind-run --list --names`, which needs the
# real pipeline: an app fixture and docker.
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  RUN_FIXTURE=$(mktemp_d)
  cat >"$RUN_FIXTURE/.xcind.sh" <<'RUNEOF'
XCIND_APP="comp-run-app"
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_BINS=("xcnpm:app")
XCIND_SCRIPTS=("xcfresh:echo ok")
RUNEOF
  cat >"$RUN_FIXTURE/compose.yaml" <<'RUNEOF'
services:
  app:
    image: nginx
RUNEOF

  out=$(cd "$RUN_FIXTURE" && PATH="$XCIND_ROOT/bin:$PATH" \
    comp_run fresh _xcind_run_completions xcind-run)
  assert_line "xcind-run completes a bin name" "xcnpm" "$out"
  assert_line "xcind-run completes a script name" "xcfresh" "$out"

  out=$(cd "$RUN_FIXTURE" && PATH="$XCIND_ROOT/bin:$PATH" \
    comp_run partial _xcind_run_completions xcind-run xcn)
  assert_line "xcind-run partial name completes" "xcnpm" "$out"
  assert_no_line "xcind-run partial name filters" "xcfresh" "$out"

  rm -rf "$RUN_FIXTURE"
else
  echo "  … SKIP: docker compose not available for xcind-run name completion"
  SKIP=$((SKIP + 1))
fi

# ======================================================================
echo "=== Test: zsh completion functions ==="

if ! command -v zsh >/dev/null 2>&1; then
  echo "  … SKIP: zsh not installed"
  SKIP=$((SKIP + 1))
else
  ZSH_DRIVER="$COMPLETION_TMP/zsh-driver.zsh"
  cat >"$ZSH_DRIVER" <<'ZSHEOF'
# Drive one zsh completion function outside compsys.
# Usage: zsh driver.zsh <completion-file> <func> <CURRENT> <word>...
#
# _describe/_files/_arguments are stubbed to print what the function would
# have offered. _describe's last argument is always the name of an array
# holding "value:description" entries; zsh's dynamic scoping makes the
# caller's local array visible via ${(P)...}.
local completion_file=$1 func=$2
CURRENT=$3
shift 3
words=("$@")

compdef() { : }
_describe() {
  local arr=${@[-1]}
  print -rl -- ${(P)arr}
  return 0
}
_files() { print -r -- '<files>' }
_arguments() { print -r -- '<files>' }
compadd() {
  local arg
  for arg in "$@"; do
    [[ $arg == "--" ]] && continue
    print -r -- "$arg"
  done
}

source $completion_file
$func
ZSHEOF

  ZSH_COMPLETION="$COMPLETION_TMP/xcind.zsh"
  "$XCIND_ROOT/bin/xcind-config" completion zsh >"$ZSH_COMPLETION"

  # zcomp_run FUNC CURRENT WORD... — print offered "value:description" lines.
  zcomp_run() {
    zsh "$ZSH_DRIVER" "$ZSH_COMPLETION" "$@" 2>/dev/null || true
  }

  out=$(zcomp_run _xcind-config 2 xcind-config)
  assert_line "zsh: top level offers resolve" \
    "resolve:Get one resolved configuration value" "$out"

  out=$(zcomp_run _xcind-config 3 xcind-config completion)
  assert_line "zsh: 'completion ' offers bash" "bash:Bash shell completions" "$out"
  assert_line "zsh: 'completion ' offers zsh" "zsh:Zsh shell completions" "$out"

  out=$(zcomp_run _xcind-config 3 xcind-config resolve)
  assert_line "zsh: 'resolve ' offers apex" \
    "apex:Apex hostname, URL and scheme" "$out"
  assert_line "zsh: 'resolve ' offers bins" \
    "bins:Declared bin commands and services" "$out"
  assert_line "zsh: 'resolve ' offers scripts" \
    "scripts:Declared script step lists" "$out"

  out=$(zcomp_run _xcind-run 2 xcind-run -)
  assert_line "zsh: xcind-run '-' offers --list" \
    "--list:List runnable bins and scripts" "$out"
  assert_line "zsh: xcind-run '-' offers --init-shell" \
    "--init-shell:Print shell wrapper functions for eval" "$out"

  out=$(zcomp_run _xcind-run 3 xcind-run somename)
  assert_eq "zsh: xcind-run offers nothing after a name" "" "$out"

  out=$(zcomp_run _xcind-run 3 xcind-run --prefix)
  assert_eq "zsh: xcind-run '--prefix ' offers nothing" "" "$out"

  out=$(zcomp_run _xcind-proxy 2 xcind-proxy)
  assert_line "zsh: top level offers init" \
    "init:Create proxy infrastructure files" "$out"

  out=$(zcomp_run _xcind-workspace 2 xcind-workspace)
  assert_line "zsh: workspace top level offers register" \
    "register:Add an existing workspace to the registry" "$out"

  out=$(zcomp_run _xcind-workspace 3 xcind-workspace list)
  assert_line "zsh: workspace 'list ' offers --prune" \
    "--prune:Remove stale registry entries" "$out"
  assert_no_line "zsh: workspace 'list ' offers no files" "<files>" "$out"

  out=$(zcomp_run _xcind-workspace 3 xcind-workspace register)
  assert_line "zsh: workspace 'register ' completes directories" \
    "<files>" "$out"

  out=$(zcomp_run _xcind-workspace 3 xcind-workspace restart)
  assert_line "zsh: workspace 'restart ' offers --yes" \
    "--yes:Skip confirmation prompt" "$out"
  assert_line "zsh: workspace 'restart ' offers -a" \
    "-a:Limit to the named application (repeatable)" "$out"
  assert_line "zsh: workspace 'restart ' completes directories" \
    "<files>" "$out"

  out=$(zcomp_run _xcind-workspace 3 xcind-workspace up)
  assert_line "zsh: workspace 'up ' offers -a" \
    "-a:Limit to the named application (repeatable)" "$out"
  assert_line "zsh: workspace 'up ' completes directories" \
    "<files>" "$out"

  out=$(zcomp_run _xcind-workspace 3 xcind-workspace down)
  assert_line "zsh: workspace 'down ' offers --volumes" \
    "--volumes:Also remove Docker volumes" "$out"
  assert_line "zsh: workspace 'down ' offers -a" \
    "-a:Limit to the named application (repeatable)" "$out"
  assert_line "zsh: workspace 'down ' completes directories" \
    "<files>" "$out"

  # `-a`/`--app` after up/down/restart completes app-directory basenames
  # when $PWD is inside a workspace (same heuristic as the bash function).
  ZSH_WS_FIXTURE=$(mktemp_d)
  mkdir -p "$ZSH_WS_FIXTURE/api" "$ZSH_WS_FIXTURE/web"
  printf 'XCIND_IS_WORKSPACE=1\n' >"$ZSH_WS_FIXTURE/.xcind.sh"
  printf 'XCIND_COMPOSE_FILES=("compose.yaml")\n' >"$ZSH_WS_FIXTURE/api/.xcind.sh"
  printf 'XCIND_COMPOSE_FILES=("compose.yaml")\n' >"$ZSH_WS_FIXTURE/web/.xcind.sh"

  out=$(cd "$ZSH_WS_FIXTURE" && zcomp_run _xcind-workspace 4 xcind-workspace down -a)
  assert_line "zsh: workspace 'down -a ' offers an app-directory basename" \
    "api" "$out"
  assert_line "zsh: workspace 'down -a ' offers the other app-directory basename" \
    "web" "$out"

  out=$(zcomp_run _xcind-application 2 xcind-application)
  assert_line "zsh: application top level offers ports" \
    "ports:Show assigned host ports" "$out"

  out=$(zcomp_run _xcind-application 3 xcind-application dispose)
  assert_line "zsh: application 'dispose ' offers --volumes" \
    "--volumes:Also remove Docker volumes" "$out"
  assert_line "zsh: application 'dispose ' completes directories" \
    "<files>" "$out"

  out=$(zcomp_run _xcind-application 3 xcind-application exports)
  assert_line "zsh: application 'exports ' offers --json" \
    "--json:Output structured JSON" "$out"

  if command -v docker >/dev/null 2>&1 &&
    docker __complete compose "" >/dev/null 2>&1; then
    out=$(zcomp_run _xcind-compose 2 xcind-compose)
    assert_line "zsh: compose delegation offers 'up'" \
      "up:Create and start containers" "$out"
    # Present in docker compose, absent from the zsh fallback list.
    if printf '%s\n' "$out" | grep -q '^watch:'; then
      echo "  ✓ zsh: delegation offers 'watch' (not in fallback list)"
      PASS=$((PASS + 1))
    else
      echo "  ✗ zsh: delegation offers 'watch' (not in fallback list)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  … SKIP: docker with __complete support not available (zsh)"
    SKIP=$((SKIP + 1))
  fi

  # Fallback path: no docker on PATH.
  SAVED_PATH="$PATH"
  export PATH="$NO_DOCKER_BIN:$PATH"
  out=$(zcomp_run _xcind-compose 2 xcind-compose)
  export PATH="$SAVED_PATH"
  assert_line "zsh: fallback offers 'up'" "up:Create and start containers" "$out"
  assert_no_line "zsh: fallback does not invent 'watch'" \
    "watch:Watch build context" "$out"
fi

# ======================================================================
echo ""
echo "=== Results ==="
echo "  Passed:  $PASS"
echo "  Failed:  $FAIL"
if [ "$SKIP" -gt 0 ]; then
  echo "  Skipped: $SKIP"
fi

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
