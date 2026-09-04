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
    'doctor:Diagnose XCIND_PROXY_EXPORTS / assigned-hook state'
    'resolve:Get one resolved configuration value'
    '--json:Output resolved config as JSON'
    '--preview:Show docker compose command'
    '--generate-docker-wrapper:Generate docker wrapper script'
    '--generate-docker-compose-wrapper:Generate docker-compose wrapper script'
    '--generate-docker-compose-configuration:Generate resolved compose config'
    '--generate-starship:Generate Starship [custom.xcind] prompt block'
    '--format:Output format for --generate-starship (toml or nix)'
    'completion:Output shell completion script'
  )

  # The first argument after resolve is the required path, so offer the
  # top-level keys there. After that path, offer only resolve modifiers when
  # the caller starts an option. Keep the key list in step with
  # __xcind_config_resolve_usage in bin/xcind-config and with the bash
  # completion.
  local resolve_seen=false
  local word
  for word in "${words[@]}"; do
    if [[ $word == "resolve" ]]; then
      resolve_seen=true
      break
    fi
  done

  if [[ $resolve_seen == true ]]; then
    if [[ ${words[CURRENT - 1]} == "resolve" ]]; then
      local -a resolve_keys=(
        'metadata:Workspace, app and workspaceless flags'
        'appRoot:Absolute path to the application root'
        'configFiles:Sourced .xcind.sh configuration files'
        'composeFiles:Compose files passed to docker compose'
        'composeEnvFiles:Env files passed to docker compose'
        'appEnvFiles:Env files exported into the app environment'
        'bakeFiles:Bake files passed to docker buildx bake'
        'bins:Declared bin commands and services'
        'scripts:Declared script step lists'
        'assignedExports:Ports assigned to this app'
        'proxiedExports:Proxied exports with computed URLs'
        'apex:Apex hostname, URL and scheme'
        'compose.:Resolved Compose values (needs the cache)'
        '--help:Show resolve paths and path syntax'
      )
      _describe 'resolve path' resolve_keys
    else
      local -a resolve_opts=(
        '--cached:Read current-SHA cache without Docker or hooks'
        '--hooks-ttl=:Set cache-refresh TTL in seconds'
      )
      _describe 'resolve option' resolve_opts
    fi
    return
  fi
  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  completion)
    local -a shells=('bash:Bash shell completions' 'zsh:Zsh shell completions')
    _describe 'shell' shells
    return
    ;;
  doctor)
    local -a doctor_opts=('--json:Emit structured JSON report')
    _describe 'doctor option' doctor_opts
    return
    ;;
  --generate-docker-wrapper | --generate-docker-compose-wrapper | --generate-docker-compose-configuration)
    _files
    return
    ;;
  --generate-starship)
    # Offer the --format modifier alongside an optional output file path.
    local -a starship_opts=('--format:Output format (toml or nix)')
    _describe 'option' starship_opts
    _files
    return
    ;;
  --format)
    local -a formats=(
      'toml:TOML [custom.xcind] block (default)'
      'nix:Nix Home Manager attrset'
    )
    _describe 'format' formats
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
    'dispose:Stop proxy and remove generated state'
    'up:Start the shared Traefik proxy'
    'down:Stop the shared Traefik proxy'
    'status:Show proxy state and configuration'
    'logs:Show Traefik proxy logs'
    'release:Release an assigned host port'
    'prune:Remove stale assigned-port entries'
    '--help:Show help'
    '-h:Show help'
    '--version:Show version'
    '-V:Show version'
  )

  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  init)
    local -a init_opts=(
      '--mode:Proxy mode (managed, external)'
      '--network:Shared proxy Docker network name'
      '--http-entrypoint:HTTP entrypoint name in router labels'
      '--https-entrypoint:HTTPS entrypoint name in router labels'
      '--certresolver:ACME certresolver for HTTPS routers'
      '--proxy-domain:Set domain suffix for hostnames'
      '--http-port:Set HTTP port'
      '--image:Set Traefik Docker image'
      '--dashboard:Enable Traefik dashboard'
      '--dashboard-port:Set dashboard port'
      '--tls-mode:TLS mode (auto, custom, disabled)'
      '--https-port:Set HTTPS port'
      '--tls-cert-file:Custom TLS cert file'
      '--tls-key-file:Custom TLS key file'
      '--help:Show help'
      '-h:Show help'
    )
    _describe 'init option' init_opts
    return
    ;;
  --mode)
    local -a proxy_modes=('managed:xcind runs its own Traefik' 'external:Use an existing host proxy')
    _describe 'proxy mode' proxy_modes
    return
    ;;
  --dashboard)
    local -a bool_vals=('true:Enable' 'false:Disable')
    _describe 'boolean' bool_vals
    return
    ;;
  --tls-mode)
    local -a tls_modes=('auto:Automatic self-signed' 'custom:Use provided cert/key' 'disabled:No TLS')
    _describe 'tls mode' tls_modes
    return
    ;;
  up)
    local -a up_opts=('--force:Tear down and recreate')
    _describe 'up option' up_opts
    return
    ;;
  dispose)
    local -a dispose_opts=(
      '--purge:Also remove proxy configuration'
      '--yes:Skip confirmation prompt'
      '-y:Skip confirmation prompt'
    )
    _describe 'dispose option' dispose_opts
    return
    ;;
  status)
    local -a status_opts=('--json:Output status as JSON')
    _describe 'status option' status_opts
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
# xcind-workspace: native completion
# -----------------------------------------------------------------------------

# Best-effort: walk up from $PWD to find a workspace root (.xcind.sh
# heuristically matching XCIND_IS_WORKSPACE=1), then list immediate
# subdirectories that look like application directories (have their own
# .xcind.sh that does not itself look like a workspace). This is a
# lightweight heuristic (grep, not sourcing) suitable only for completion —
# the completion scripts must stay self-contained and not source workspace
# config.
_xcind_workspace_app_names() {
  local dir="$PWD" root=""
  while :; do
    if [[ -f "$dir/.xcind.sh" ]] && grep -q '^XCIND_IS_WORKSPACE=1' "$dir/.xcind.sh" 2>/dev/null; then
      root="$dir"
      break
    fi
    [[ $dir == "/" ]] && break
    dir="$(dirname "$dir")"
  done
  [[ -n $root ]] || return
  local sub
  for sub in "$root"/*/; do
    [[ -d $sub ]] || continue
    sub="${sub%/}"
    [[ -f "$sub/.xcind.sh" ]] || continue
    grep -q '^XCIND_IS_WORKSPACE=1' "$sub/.xcind.sh" 2>/dev/null && continue
    print -r -- "$(basename "$sub")"
  done
}

_xcind-workspace() {
  local -a main_commands=(
    'init:Initialize a workspace directory'
    'up:Bring up every application in the workspace'
    'down:Bring down every application in the workspace'
    'restart:Restart every application (down, then up)'
    'dispose:Tear down a workspace'
    'status:Show workspace-wide status'
    'list:List all known workspaces'
    'register:Add an existing workspace to the registry'
    'forget:Remove a workspace from the registry'
    '--help:Show help'
    '-h:Show help'
    '--version:Show version'
    '-V:Show version'
  )

  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  init)
    local -a init_opts=(
      '--name:Set workspace name'
      '--proxy-domain:Set proxy domain'
    )
    _describe 'init option' init_opts
    _files -/
    return
    ;;
  status)
    local -a status_opts=('--json:Output structured JSON')
    _describe 'status option' status_opts
    _files -/
    return
    ;;
  -a | --app)
    if [[ " ${words[*]} " == *' up '* || " ${words[*]} " == *' down '* || " ${words[*]} " == *' restart '* ]]; then
      local -a app_names
      local app_name
      while IFS= read -r app_name; do
        [[ -n $app_name ]] && app_names+=("$app_name")
      done < <(_xcind_workspace_app_names)
      compadd -- "${app_names[@]}"
    fi
    return
    ;;
  up)
    local -a up_opts=(
      '-a:Limit to the named application (repeatable)'
      '--app:Limit to the named application (repeatable)'
    )
    _describe 'up option' up_opts
    _files -/
    return
    ;;
  down)
    local -a down_opts=(
      '--yes:Skip confirmation prompt'
      '-y:Skip confirmation prompt'
      '--volumes:Also remove Docker volumes'
      '-a:Limit to the named application (repeatable)'
      '--app:Limit to the named application (repeatable)'
    )
    _describe 'down option' down_opts
    _files -/
    return
    ;;
  restart)
    local -a restart_opts=(
      '--yes:Skip confirmation prompt'
      '-y:Skip confirmation prompt'
      '-a:Limit to the named application (repeatable)'
      '--app:Limit to the named application (repeatable)'
    )
    _describe 'restart option' restart_opts
    _files -/
    return
    ;;
  dispose)
    local -a dispose_opts=(
      '--volumes:Also remove Docker volumes'
      '--rm:Also remove the workspace directory'
      '--yes:Skip confirmation prompt'
      '-y:Skip confirmation prompt'
    )
    _describe 'dispose option' dispose_opts
    _files -/
    return
    ;;
  list)
    local -a list_opts=(
      '--json:Output structured JSON'
      '--prune:Remove stale registry entries'
    )
    _describe 'list option' list_opts
    return
    ;;
  register | forget)
    _files -/
    return
    ;;
  esac

  _describe 'xcind-workspace command' main_commands
}

# -----------------------------------------------------------------------------
# xcind-application: native completion
# -----------------------------------------------------------------------------

_xcind-application() {
  local -a main_commands=(
    'init:Initialize an application directory'
    'dispose:Tear down an application'
    'status:Show status for a single application'
    'list:List applications in the enclosing workspace'
    'ports:Show assigned host ports'
    'urls:Show proxied URLs'
    'exports:Show all exports (ports and URLs)'
    '--help:Show help'
    '-h:Show help'
    '--version:Show version'
    '-V:Show version'
  )

  # Context-sensitive completion
  case "${words[CURRENT - 1]}" in
  init)
    local -a init_opts=(
      '--name:Set XCIND_APP explicitly'
    )
    _describe 'init option' init_opts
    _files -/
    return
    ;;
  dispose)
    local -a dispose_opts=(
      '--volumes:Also remove Docker volumes'
      '--rm:Also remove the application directory'
      '--yes:Skip confirmation prompt'
      '-y:Skip confirmation prompt'
    )
    _describe 'dispose option' dispose_opts
    _files -/
    return
    ;;
  status | list | ports | urls | exports)
    local -a status_opts=('--json:Output structured JSON')
    _describe 'option' status_opts
    _files -/
    return
    ;;
  esac

  _describe 'xcind-application command' main_commands
}

# -----------------------------------------------------------------------------
# xcind-run: completion
# -----------------------------------------------------------------------------

_xcind-run() {
  # Once a name is on the line, the words after it belong to that bin or
  # script — offer nothing.
  local i
  for ((i = 2; i < CURRENT; i++)); do
    case "${words[$i]}" in
    -T | --no-tty | --list | --names | --init-shell | --help | -h | --version | -V) ;;
    --prefix) ((i++)) ;; # skip the prefix value
    --prefix=*) ;;
    *) return ;;
    esac
  done

  # --prefix takes free text
  if [[ ${words[CURRENT - 1]} == "--prefix" ]]; then
    return
  fi

  if [[ ${words[CURRENT]} == -* ]]; then
    local -a opts=(
      '-T:Pass -T to docker compose exec/run'
      '--no-tty:Pass -T to docker compose exec/run'
      '--list:List runnable bins and scripts'
      '--names:With --list, print bare names only'
      '--init-shell:Print shell wrapper functions for eval'
      '--prefix:Wrapper prefix for --init-shell (default x-)'
      '--help:Show help'
      '--version:Show version'
    )
    _describe 'xcind-run option' opts
    return
  fi

  # First non-flag word: bin and script names from the app's declarations.
  # (A read loop instead of ${(f)...} so shfmt can parse this file.)
  local -a names
  local _xcind_run_name
  while IFS= read -r _xcind_run_name; do
    [[ -n $_xcind_run_name ]] && names+=("$_xcind_run_name")
  done < <(xcind-run --list --names 2>/dev/null)
  if ((${#names[@]} > 0)); then
    _describe 'bin or script' names
  fi
}

# -----------------------------------------------------------------------------
# Register completions
# -----------------------------------------------------------------------------

compdef _xcind-application xcind-application
compdef _xcind-application xcind-app
compdef _xcind-compose xcind-compose
compdef _xcind-config xcind-config
compdef _xcind-proxy xcind-proxy
compdef _xcind-workspace xcind-workspace
compdef _xcind-run xcind-run

# -----------------------------------------------------------------------------
# Prefixed wrappers for the xcind commands
# -----------------------------------------------------------------------------

# Command suffix → completion function, for the wrappers below. Keep in sync
# with the `compdef` block above; test-xcind-completion.sh asserts the two
# agree.
__XCIND_SHELL_ALIAS_MAP="application:_xcind-application
app:_xcind-application
compose:_xcind-compose
config:_xcind-config
proxy:_xcind-proxy
workspace:_xcind-workspace
run:_xcind-run"

# Define <prefix><name> wrappers for the xcind commands and register each
# one's completion, so `x-config …` completes like `xcind-config …` instead of
# falling back to filenames.
#
# The command set comes from this file, not from an app's .xcind.sh, so one
# call per shell covers every directory. Nothing here touches XCIND_BINS or
# XCIND_SCRIPTS — reach those through `xcind-run`, whose completion re-reads
# the current app on every request.
#
# Usage: xcind-shell-aliases [PREFIX]   (default prefix: x-)
xcind-shell-aliases() {
  local prefix=${1:-x-} line short fn
  if [[ $prefix =~ [^a-zA-Z0-9_-] ]]; then
    echo "xcind-shell-aliases: prefix value must contain only alphanumeric, dash, or underscore characters" >&2
    return 64
  fi
  # (A read loop instead of ${(f)...} so shfmt can parse this file.)
  while IFS= read -r line; do
    short=${line%%:*}
    fn=${line#*:}
    [[ -z $short ]] && continue
    eval "${prefix}${short}() { xcind-${short} \"\$@\"; }"
    compdef "$fn" "${prefix}${short}"
  done <<<"$__XCIND_SHELL_ALIAS_MAP"
}
