#!/usr/bin/env bash
# xcind shell completions for bash
# Source via: . <(xcind-config completion bash)
#
# SC2207: COMPREPLY=($(compgen ...)) is the standard bash completion idiom;
#         mapfile alternative requires bash 4+ but completion must work on 3.2.
# SC1091: Sourced docker completion paths are dynamic and cannot be followed.
# shellcheck disable=SC2207,SC1090,SC1091

# -----------------------------------------------------------------------------
# xcind-compose: completions via Docker's Cobra __complete mechanism
# -----------------------------------------------------------------------------

# Calls `docker __complete compose ...` directly as a subprocess, which is
# the same mechanism Docker's own _docker completion uses internally.
# This avoids calling _docker and all issues with loading/autoloading
# Docker's completion functions across different environments.

_xcind_compose_completions() {
  local cur out directive
  cur="${COMP_WORDS[COMP_CWORD]}"

  # Build the completion request as if the user typed "docker compose ..."
  local -a args
  args=(docker __complete compose)
  # Append all words after the command itself, preserving quoting/spacing
  local i
  for i in "${COMP_WORDS[@]:1}"; do
    args+=("$i")
  done

  # If completing a new word (cursor after a space), add an empty arg
  if [[ -z $cur ]]; then
    args+=("")
  fi

  # Get completions from Docker's Cobra mechanism
  out=$("${args[@]}" 2>/dev/null)

  if [[ -z $out ]]; then
    # docker __complete not available — use hardcoded fallback
    __xcind_compose_fallback
    return
  fi

  # Extract the directive from the last line (format ":N")
  directive=0
  local lastLine
  lastLine=$(printf "%s\n" "$out" | tail -1)
  if [[ ${lastLine:0:1} == ":" ]]; then
    directive=${lastLine:1}
    out=$(printf "%s\n" "$out" | sed '$d')
  fi

  # Directive bit 1 = error
  if ((directive & 1)); then
    __xcind_compose_fallback
    return
  fi

  # Parse completions and filter by current word
  local -a completions=()
  while IFS=$'\n' read -r line; do
    [[ -z $line ]] && continue
    # Extract just the completion value (before tab/description)
    local val="${line%%	*}"
    completions+=("$val")
  done <<<"$out"

  if [[ ${#completions[@]} -gt 0 ]]; then
    local noSpace=""
    # Directive bit 2 = no space after completion
    ((directive & 2)) && noSpace="-o nospace"
    COMPREPLY=($(compgen -W "${completions[*]}" -- "$cur"))
    if [[ -n $noSpace ]]; then
      compopt -o nospace 2>/dev/null
    fi
    return
  fi

  # No completions; check if file completion is allowed
  # Directive bit 4 = no file completion
  if ((directive & 4)); then
    return
  fi

  # Fall through to default (file) completion
  COMPREPLY=($(compgen -f -- "$cur"))
}

__xcind_compose_fallback() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  if [[ $COMP_CWORD -eq 1 ]]; then
    local subcommands="build config create down events exec images
      kill logs pause port ps pull push restart rm run
      start stop top unpause up version"
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
  fi
}

# -----------------------------------------------------------------------------
# xcind-config: native completion
# -----------------------------------------------------------------------------

_xcind_config_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # After "completion", offer shell names
  if [[ $prev == "completion" ]]; then
    COMPREPLY=($(compgen -W "bash zsh" -- "$cur"))
    return
  fi

  # After --generate-docker-wrapper, --generate-docker-compose-wrapper, or
  # --generate-docker-compose-configuration, complete files (optional output path)
  if [[ $prev == "--generate-docker-wrapper" ]] ||
    [[ $prev == "--generate-docker-compose-wrapper" ]] ||
    [[ $prev == "--generate-docker-compose-configuration" ]]; then
    COMPREPLY=($(compgen -f -- "$cur"))
    return
  fi

  local opts="--help -h --version -V --check --json --preview
    --generate-docker-wrapper --generate-docker-compose-wrapper
    --generate-docker-compose-configuration completion"
  COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

# -----------------------------------------------------------------------------
# xcind-proxy: native completion
# -----------------------------------------------------------------------------

_xcind_proxy_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # After "init", offer init-specific flags
  if [[ $prev == "init" ]] || [[ " ${COMP_WORDS[*]} " == *" init "* && $cur == -* ]]; then
    COMPREPLY=($(compgen -W "--proxy-domain --http-port --image --dashboard --dashboard-port --tls-mode --https-port --tls-cert-file --tls-key-file --help -h" -- "$cur"))
    return
  fi

  # After init flag names, complete values (directories for some, free text for others)
  if [[ $prev == "--proxy-domain" || $prev == "--http-port" || $prev == "--image" ||
    $prev == "--dashboard-port" || $prev == "--https-port" ||
    $prev == "--tls-cert-file" || $prev == "--tls-key-file" ]]; then
    return
  fi
  if [[ $prev == "--dashboard" ]]; then
    COMPREPLY=($(compgen -W "true false" -- "$cur"))
    return
  fi
  if [[ $prev == "--tls-mode" ]]; then
    COMPREPLY=($(compgen -W "auto custom disabled" -- "$cur"))
    return
  fi

  # After "up", offer --force
  if [[ $prev == "up" ]]; then
    COMPREPLY=($(compgen -W "--force" -- "$cur"))
    return
  fi

  # After "status", offer --json
  if [[ $prev == "status" ]]; then
    COMPREPLY=($(compgen -W "--json" -- "$cur"))
    return
  fi

  # After "logs", offer common docker compose logs flags
  if [[ $prev == "logs" ]]; then
    COMPREPLY=($(compgen -W "-f --follow --tail --timestamps -t --no-color --since --until" -- "$cur"))
    return
  fi

  local opts="init up down status logs release prune --help -h --version -V"
  COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

# -----------------------------------------------------------------------------
# xcind-workspace: native completion
# -----------------------------------------------------------------------------

_xcind_workspace_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"

  # After "init", offer init-specific flags and directory completion
  if [[ $prev == "init" ]] || [[ " ${COMP_WORDS[*]} " == *" init "* && $cur == -* ]]; then
    COMPREPLY=($(compgen -W "--name --proxy-domain" -- "$cur"))
    return
  fi

  # After init flag names, let default completion handle values
  if [[ $prev == "--name" || $prev == "--proxy-domain" ]]; then
    return
  fi

  # After "status", offer --json and directory completion
  if [[ $prev == "status" ]]; then
    COMPREPLY=($(compgen -W "--json" -- "$cur"))
    return
  fi

  # After "list", offer list-specific flags
  if [[ $prev == "list" ]] || [[ " ${COMP_WORDS[*]} " == *" list "* && $cur == -* ]]; then
    COMPREPLY=($(compgen -W "--json --prune" -- "$cur"))
    return
  fi

  # After "register" or "forget", complete directories
  if [[ $prev == "register" || $prev == "forget" ]]; then
    COMPREPLY=($(compgen -d -- "$cur"))
    return
  fi

  local opts="init status list register forget --help -h --version -V"
  COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

# -----------------------------------------------------------------------------
# Register completions
# -----------------------------------------------------------------------------

complete -F _xcind_compose_completions xcind-compose
complete -F _xcind_config_completions xcind-config
complete -F _xcind_proxy_completions xcind-proxy
complete -F _xcind_workspace_completions xcind-workspace
