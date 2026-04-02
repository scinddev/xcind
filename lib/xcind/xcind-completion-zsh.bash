# shellcheck shell=bash disable=all
# xcind shell completions for zsh
# Source via: . <(xcind-config completion zsh)

# -----------------------------------------------------------------------------
# xcind-compose: completions via Docker's Cobra __complete mechanism
# -----------------------------------------------------------------------------

# Calls `docker __complete compose ...` directly as a subprocess, which is
# the same mechanism Docker's own _docker completion uses internally.
# This avoids calling _docker (which causes infinite recursion due to
# Cobra's zsh autoload self-call pattern).

_xcind-compose() {
  local out directive lastLine comp
  local -a completions

  # Build the completion request as if the user typed "docker compose ..."
  # words[1] is "xcind-compose"; words[2..] are the user's arguments
  local -a args
  args=(docker __complete compose)
  args+=("${words[@]:1}")

  # If completing a new word (cursor after a space), add an empty arg
  if [[ ${words[CURRENT]} == "" ]]; then
    args+=("")
  fi

  # Get completions from Docker's Cobra mechanism
  out=$("${args[@]}" 2>/dev/null)

  if [[ -z $out ]]; then
    # docker __complete not available — use hardcoded fallback
    __xcind_compose_fallback
    return
  fi

  # Extract the directive integer from the last line (format ":N")
  directive=0
  while IFS='\n' read -r line; do
    lastLine=${line}
  done < <(printf "%s\n" "${out[@]}")

  if [[ ${lastLine[1]} == ":" ]]; then
    directive=${lastLine[2, -1]}
    local suffix
    ((suffix = ${#lastLine} + 2))
    out=${out[1, -$suffix]}
  fi

  # Directive bit 1 = error
  if ((directive & 1)); then
    __xcind_compose_fallback
    return
  fi

  # Parse completions (format: "value\tdescription" per line)
  while IFS='\n' read -r comp; do
    if [[ -n $comp ]]; then
      # Escape colons in the value (zsh _describe uses : as separator)
      comp=${comp//:/\\:}
      # Replace tab with : for _describe format
      local tab="$(printf '\t')"
      comp=${comp//$tab/:}
      completions+=${comp}
    fi
  done < <(printf "%s\n" "${out[@]}")

  if ((${#completions})); then
    local -a desc_args
    # Directive bit 32 = keep order
    ((directive & 32)) && desc_args+=(-V)
    # Directive bit 2 = no space after completion
    ((directive & 2)) && desc_args+=(-S '')
    if _describe "${desc_args[@]}" 'docker compose' completions; then
      return
    fi
  fi

  # No completions from Docker; check if file completion is allowed
  # Directive bit 4 = no file completion
  if ((directive & 4)); then
    return
  fi

  # Fall through to file completion
  _arguments '*:filename:_files'
}

__xcind_compose_fallback() {
  local -a subcommands=(
    'build:Build or rebuild services'
    'config:Validate and view the Compose file'
    'create:Create services'
    'down:Stop and remove containers and networks'
    'events:Receive real-time events from containers'
    'exec:Execute a command in a running container'
    'images:List images used by created containers'
    'kill:Force stop service containers'
    'logs:View output from containers'
    'pause:Pause services'
    'port:Print the public port for a port binding'
    'ps:List containers'
    'pull:Pull service images'
    'push:Push service images'
    'restart:Restart service containers'
    'rm:Remove stopped service containers'
    'run:Run a one-off command on a service'
    'start:Start services'
    'stop:Stop services'
    'top:Display the running processes'
    'unpause:Unpause services'
    'up:Create and start containers'
    'version:Show the Docker Compose version'
  )
  _describe 'docker compose command' subcommands
}

# -----------------------------------------------------------------------------
# xcind-config: native completion
# -----------------------------------------------------------------------------

_xcind-config() {
  local -a main_options=(
    '--help:Show help'
    '-h:Show help'
    '--version:Show version'
    '-V:Show version'
    '--check:Check required/optional dependencies'
    '--json:Output resolved config as JSON'
    '--preview:Show docker compose command'
    '--generate-docker-wrapper:Generate docker wrapper script'
    '--generate-docker-compose-wrapper:Generate docker-compose wrapper script'
    '--generate-docker-compose-configuration:Generate resolved compose config'
    'completion:Output shell completion script'
  )

  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  completion)
    local -a shells=('bash:Bash shell completions' 'zsh:Zsh shell completions')
    _describe 'shell' shells
    return
    ;;
  --generate-docker-wrapper | --generate-docker-compose-wrapper | --generate-docker-compose-configuration)
    _files
    return
    ;;
  esac

  _describe 'xcind-config option' main_options
}

# -----------------------------------------------------------------------------
# xcind-proxy: native completion
# -----------------------------------------------------------------------------

_xcind-proxy() {
  local -a main_commands=(
    'init:Create proxy infrastructure files'
    'up:Start the shared Traefik proxy'
    'down:Stop the shared Traefik proxy'
    'status:Show proxy state and configuration'
    'logs:Show Traefik proxy logs'
    '--help:Show help'
    '-h:Show help'
    '--version:Show version'
    '-V:Show version'
  )

  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  up)
    local -a up_opts=('--force:Tear down and recreate')
    _describe 'up option' up_opts
    return
    ;;
  logs)
    local -a log_opts=(
      '-f:Follow log output'
      '--follow:Follow log output'
      '--tail:Number of lines to show'
      '--timestamps:Show timestamps'
      '-t:Show timestamps'
      '--no-color:Produce monochrome output'
      '--since:Show logs since timestamp'
      '--until:Show logs until timestamp'
    )
    _describe 'logs option' log_opts
    return
    ;;
  esac

  _describe 'xcind-proxy command' main_commands
}

# -----------------------------------------------------------------------------
# Register completions
# -----------------------------------------------------------------------------

compdef _xcind-compose xcind-compose
compdef _xcind-config xcind-config
compdef _xcind-proxy xcind-proxy
