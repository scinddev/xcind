#!/usr/bin/env bash
# xcind-run-lib.bash — Bin and script parsing for xcind-run
#
# This library provides the step tokenizer and the parsing and JSON
# serialization for XCIND_BINS and XCIND_SCRIPTS declarations. It is
# sourced by bin/xcind-run (and indirectly via xcind-lib.bash for the
# JSON contract and SHA computation).

# --------------------------------------------------------------------------
# Bins parsing
# --------------------------------------------------------------------------

# Parse XCIND_BINS into parallel arrays. Validates every entry; returns 1
# on the first error (message to stderr).
#
# Format: name:service[;key=value…]
# Keys: cmd (default = name), use = exec|run, desc
# Duplicate names are an error (no first-wins).
#
# Fills:
#   __XCIND_RUNNER_BIN_NAMES    — bin names
#   __XCIND_RUNNER_BIN_SERVICES — Compose service per bin
#   __XCIND_RUNNER_BIN_USES     — exec | run
#   __XCIND_RUNNER_BIN_CMDS     — command inside the service (default = name)
#   __XCIND_RUNNER_BIN_DESCS    — descriptions ("" when none)
__xcind-runner-parse-bins() {
  __XCIND_RUNNER_BIN_NAMES=()
  __XCIND_RUNNER_BIN_SERVICES=()
  __XCIND_RUNNER_BIN_USES=()
  __XCIND_RUNNER_BIN_CMDS=()
  __XCIND_RUNNER_BIN_DESCS=()

  if [[ -z ${XCIND_BINS+x} ]] || [[ ${#XCIND_BINS[@]} -eq 0 ]]; then
    return 0
  fi

  local seen_names=""
  local entry name service remainder use cmd desc key val
  local _old_ifs pairs pair

  for entry in "${XCIND_BINS[@]}"; do
    # Must contain a colon
    if [[ $entry != *:* ]]; then
      echo "invalid XCIND_BINS entry '$entry' (expected name:service[;key=value…])" >&2
      return 1
    fi

    # Split on first ':'
    name="${entry%%:*}"
    remainder="${entry#*:}"

    # Empty name → error
    if [[ -z $name ]]; then
      echo "invalid XCIND_BINS entry '$entry' (expected name:service[;key=value…])" >&2
      return 1
    fi

    # Name starts with @ or - or has whitespace → error
    if [[ $name == @* ]] || [[ $name == -* ]] || [[ $name =~ [[:space:]] ]]; then
      echo "invalid XCIND_BINS entry '$entry' (name must not start with @ or - or contain whitespace)" >&2
      return 1
    fi

    # service = between first ':' and first ';' (or end of remainder)
    service="${remainder%%;*}"
    if [[ $service == "$remainder" ]]; then
      # No semicolon — service is the whole remainder, no metadata
      remainder=""
    else
      remainder="${remainder#*;}"
    fi

    # Empty service → error
    if [[ -z $service ]]; then
      echo "invalid XCIND_BINS entry '$entry' (expected name:service[;key=value…])" >&2
      return 1
    fi

    # Skip duplicate names (error instead of first-wins)
    case ",$seen_names," in
    *",$name,"*)
      echo "duplicate XCIND_BINS entry '$name'" >&2
      return 1
      ;;
    esac
    seen_names="${seen_names:+$seen_names,}$name"

    # Parse metadata key=value pairs
    use="exec"
    cmd=""
    desc=""
    if [[ -n $remainder ]]; then
      _old_ifs="$IFS"
      IFS=';'
      # shellcheck disable=SC2206
      pairs=($remainder)
      IFS="$_old_ifs"
      for pair in "${pairs[@]}"; do
        # Skip empty pairs
        [[ -z $pair ]] && continue
        key="${pair%%=*}"
        val="${pair#*=}"
        if [[ $key == "$val" ]]; then
          # No '=' found — unknown key with no value
          echo "unknown XCIND_BINS attribute '$key' in '$entry'" >&2
          return 1
        fi
        case "$key" in
        use)
          if [[ $val != "exec" ]] && [[ $val != "run" ]]; then
            echo "invalid XCIND_BINS attribute 'use=$val' in '$entry' (expected exec or run)" >&2
            return 1
          fi
          use="$val"
          ;;
        cmd) cmd="$val" ;;
        desc) desc="$val" ;;
        *)
          echo "unknown XCIND_BINS attribute '$key' in '$entry'" >&2
          return 1
          ;;
        esac
      done
    fi

    # Default cmd to name if not specified
    if [[ -z $cmd ]]; then
      cmd="$name"
    fi

    __XCIND_RUNNER_BIN_NAMES+=("$name")
    __XCIND_RUNNER_BIN_SERVICES+=("$service")
    __XCIND_RUNNER_BIN_USES+=("$use")
    __XCIND_RUNNER_BIN_CMDS+=("$cmd")
    __XCIND_RUNNER_BIN_DESCS+=("$desc")
  done
  return 0
}

# Parse XCIND_BINS into a JSON object keyed by bin name.
#
# Usage:
#   __xcind-runner-bins-json
#   # prints: {"php":{"service":"app","use":"exec","cmd":"php"},"npm":{"service":"app","use":"exec","cmd":"npm"}}
#
# `cmd` is always present; `desc` only when given.
__xcind-runner-bins-json() {
  __xcind-runner-parse-bins || return 1

  if [[ ${#__XCIND_RUNNER_BIN_NAMES[@]} -eq 0 ]]; then
    echo "{}"
    return 0
  fi

  local i=0
  local count=${#__XCIND_RUNNER_BIN_NAMES[@]}
  local first=true
  local name service use cmd desc

  printf '{'
  while [ "$i" -lt "$count" ]; do
    name="${__XCIND_RUNNER_BIN_NAMES[$i]}"
    service="${__XCIND_RUNNER_BIN_SERVICES[$i]}"
    use="${__XCIND_RUNNER_BIN_USES[$i]}"
    cmd="${__XCIND_RUNNER_BIN_CMDS[$i]}"
    desc="${__XCIND_RUNNER_BIN_DESCS[$i]}"

    if [[ $first == true ]]; then
      first=false
    else
      printf ','
    fi

    if [[ -n $desc ]]; then
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --arg u "$use" --arg c "$cmd" --arg d "$desc" \
          '{service: $s, use: $u, cmd: $c, desc: $d}')"
    else
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --arg u "$use" --arg c "$cmd" \
          '{service: $s, use: $u, cmd: $c}')"
    fi

    i=$((i + 1))
  done
  printf '}'
  return 0
}

# --------------------------------------------------------------------------
# Word splitting
# --------------------------------------------------------------------------

# Split one step's text into tokens without eval. Pure-bash character loop
# with three states: unquoted, single-quoted, double-quoted.
#
#   - Space and tab end a token.
#   - '…' is literal.
#   - In "…" a backslash escapes only ", \ and $.
#   - An unquoted backslash escapes the next character.
#   - No variable, command, or glob expansion ("" yields an empty token).
#
# Fills the parallel arrays:
#   __XCIND_RUNNER_TOKENS — the token values
#   __XCIND_RUNNER_SPLICE — 1 when the source token was exactly $@ or "$@"
#                           (the caller splices user args there), else 0
#
# Returns 64 on an unterminated quote. Chosen over `eval "set -- …"` so
# Xcind matches what a Go shellwords library will do in Scind.
# shellcheck disable=SC1003  # the '\' literals are single backslash chars, not quote escapes
__xcind-runner-split() {
  local text="$1"
  __XCIND_RUNNER_TOKENS=()
  __XCIND_RUNNER_SPLICE=()

  local i=0
  local len=${#text}
  local state="u" # u = unquoted, s = single-quoted, d = double-quoted
  local tok=""    # token value accumulated so far
  local raw=""    # exact source characters consumed for this token
  local have=0    # 1 once the current token has any source (so "" emits)
  local c next splice

  while [ "$i" -lt "$len" ]; do
    c=${text:i:1}
    case $state in
    u)
      case $c in
      " " | "	")
        if [ "$have" -eq 1 ]; then
          splice=0
          if [[ $raw == '$@' ]] || [[ $raw == '"$@"' ]]; then
            splice=1
          fi
          __XCIND_RUNNER_TOKENS+=("$tok")
          __XCIND_RUNNER_SPLICE+=("$splice")
          tok=""
          raw=""
          have=0
        fi
        ;;
      "'")
        state="s"
        raw+=$c
        have=1
        ;;
      '"')
        state="d"
        raw+=$c
        have=1
        ;;
      '\')
        i=$((i + 1))
        if [ "$i" -lt "$len" ]; then
          tok+=${text:i:1}
          raw+="\\${text:i:1}"
        else
          # Trailing backslash: keep it literally.
          tok+='\'
          raw+='\'
        fi
        have=1
        ;;
      *)
        tok+=$c
        raw+=$c
        have=1
        ;;
      esac
      ;;
    s)
      if [[ $c == "'" ]]; then
        state="u"
        raw+=$c
      else
        tok+=$c
        raw+=$c
      fi
      ;;
    d)
      case $c in
      '"')
        state="u"
        raw+=$c
        ;;
      '\')
        next=${text:$((i + 1)):1}
        if [[ $next == '"' ]] || [[ $next == '\' ]] || [[ $next == '$' ]]; then
          i=$((i + 1))
          tok+=$next
          raw+="\\$next"
        else
          tok+=$c
          raw+=$c
        fi
        ;;
      *)
        tok+=$c
        raw+=$c
        ;;
      esac
      ;;
    esac
    i=$((i + 1))
  done

  if [[ $state != "u" ]]; then
    echo "unterminated quote in '$text'" >&2
    return 64
  fi

  if [ "$have" -eq 1 ]; then
    splice=0
    if [[ $raw == '$@' ]] || [[ $raw == '"$@"' ]]; then
      splice=1
    fi
    __XCIND_RUNNER_TOKENS+=("$tok")
    __XCIND_RUNNER_SPLICE+=("$splice")
  fi
  return 0
}

# --------------------------------------------------------------------------
# Scripts parsing
# --------------------------------------------------------------------------

# Parse XCIND_SCRIPTS into parallel arrays. Entry format: `name:` followed
# by steps, one per line (a single-line `name:step` form is allowed).
#
#   - Each step line is trimmed; blank lines are skipped.
#   - A line starting with `#` is a comment and is dropped from the steps;
#     the first comment is the script's description.
#   - A leading `-` on a step means its failure is ignored at run time and
#     is kept in the stored step. A bare `-` is an error.
#   - Name constraints match bins: no leading `@` or `-`, no whitespace.
#   - Duplicate script names are an error.
#
# Fills:
#   __XCIND_RUNNER_SCRIPT_NAMES — script names
#   __XCIND_RUNNER_SCRIPT_DESCS — descriptions ("" when none)
#   __XCIND_RUNNER_SCRIPT_STEPS — steps, newline-joined per script
#                                 (steps cannot contain newlines by construction)
#
# Returns 1 on the first validation error (message to stderr).
__xcind-runner-parse-scripts() {
  __XCIND_RUNNER_SCRIPT_NAMES=()
  __XCIND_RUNNER_SCRIPT_DESCS=()
  # shellcheck disable=SC2034  # read by __xcind-runner-scripts-json
  __XCIND_RUNNER_SCRIPT_STEPS=()

  if [[ -z ${XCIND_SCRIPTS+x} ]] || [[ ${#XCIND_SCRIPTS[@]} -eq 0 ]]; then
    return 0
  fi

  local seen_names=""
  local entry name body line trimmed desc steps

  for entry in "${XCIND_SCRIPTS[@]}"; do
    if [[ $entry != *:* ]]; then
      echo "invalid XCIND_SCRIPTS entry '$entry' (expected name: followed by steps)" >&2
      return 1
    fi

    name="${entry%%:*}"
    body="${entry#*:}"

    if [[ -z $name ]]; then
      echo "invalid XCIND_SCRIPTS entry '$entry' (expected name: followed by steps)" >&2
      return 1
    fi

    if [[ $name == @* ]] || [[ $name == -* ]] || [[ $name == *[[:space:]]* ]]; then
      echo "invalid XCIND_SCRIPTS entry '$entry' (name must not start with @ or - or contain whitespace)" >&2
      return 1
    fi

    case ",$seen_names," in
    *",$name,"*)
      echo "duplicate XCIND_SCRIPTS entry '$name'" >&2
      return 1
      ;;
    esac
    seen_names="${seen_names:+$seen_names,}$name"

    desc=""
    steps=""
    while IFS= read -r line; do
      # Trim leading and trailing whitespace.
      trimmed="${line#"${line%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"

      if [[ -z $trimmed ]]; then
        continue
      fi

      if [[ $trimmed == "#"* ]]; then
        if [[ -z $desc ]]; then
          desc="${trimmed#\#}"
          desc="${desc#"${desc%%[![:space:]]*}"}"
        fi
        continue
      fi

      if [[ $trimmed == "-" ]]; then
        echo "invalid step '-' in script '$name' (a bare - has no command)" >&2
        return 1
      fi

      steps="${steps:+$steps
}$trimmed"
    done <<<"$body"

    if [[ -z $steps ]]; then
      echo "script '$name' has no steps" >&2
      return 1
    fi

    __XCIND_RUNNER_SCRIPT_NAMES+=("$name")
    __XCIND_RUNNER_SCRIPT_DESCS+=("$desc")
    __XCIND_RUNNER_SCRIPT_STEPS+=("$steps")
  done
  return 0
}

# Parse XCIND_SCRIPTS into a JSON object keyed by script name.
#
# Usage:
#   __xcind-runner-scripts-json
#   # prints: {"fresh":{"steps":["php artisan migrate:fresh --seed"],"desc":"Rebuild the database"}}
#
# `steps` holds the raw steps (comments removed, `-` prefix kept).
# `desc` is present only when the script has a description.
__xcind-runner-scripts-json() {
  __xcind-runner-parse-scripts || return 1

  if [[ ${#__XCIND_RUNNER_SCRIPT_NAMES[@]} -eq 0 ]]; then
    echo "{}"
    return 0
  fi

  local i=0
  local count=${#__XCIND_RUNNER_SCRIPT_NAMES[@]}
  local first=true
  local name desc steps

  printf '{'
  while [ "$i" -lt "$count" ]; do
    name="${__XCIND_RUNNER_SCRIPT_NAMES[$i]}"
    desc="${__XCIND_RUNNER_SCRIPT_DESCS[$i]}"
    steps="${__XCIND_RUNNER_SCRIPT_STEPS[$i]}"

    if [[ $first == true ]]; then
      first=false
    else
      printf ','
    fi

    printf '%s:%s' \
      "$(printf '%s' "$name" | jq -R .)" \
      "$(jq -n --arg steps "$steps" --arg d "$desc" \
        '{steps: ($steps | split("\n"))} + (if $d == "" then {} else {desc: $d} end)')"

    i=$((i + 1))
  done
  printf '}'
  return 0
}

# --------------------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------------------

# Parse both declaration arrays and enforce the shared namespace: a name
# declared in both XCIND_BINS and XCIND_SCRIPTS is a load-time error.
__xcind-runner-load() {
  if [[ -n ${__XCIND_RUNNER_LOADED+x} ]]; then return 0; fi
  __xcind-runner-parse-bins || return 1
  __xcind-runner-parse-scripts || return 1

  # O(n+m) check: build a comma-delimited string of bin names, then scan
  # each script name against it with a case-glob match.
  local _bin_seen="" _n
  for _n in ${__XCIND_RUNNER_BIN_NAMES[@]+"${__XCIND_RUNNER_BIN_NAMES[@]}"}; do
    _bin_seen="${_bin_seen:+$_bin_seen,}$_n"
  done
  for _n in ${__XCIND_RUNNER_SCRIPT_NAMES[@]+"${__XCIND_RUNNER_SCRIPT_NAMES[@]}"}; do
    case ",$_bin_seen," in
    *",$_n,"*)
      echo "duplicate name '$_n' declared in both XCIND_BINS and XCIND_SCRIPTS" >&2
      return 1
      ;;
    esac
  done
  __XCIND_RUNNER_LOADED=1
  return 0
}

# Print the array index of a bin (or script) name. Returns 1 when absent.
__xcind-runner-bin-index() {
  local i=0
  local count=${#__XCIND_RUNNER_BIN_NAMES[@]}
  while [ "$i" -lt "$count" ]; do
    if [[ ${__XCIND_RUNNER_BIN_NAMES[$i]} == "$1" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

__xcind-runner-script-index() {
  local i=0
  local count=${#__XCIND_RUNNER_SCRIPT_NAMES[@]}
  while [ "$i" -lt "$count" ]; do
    if [[ ${__XCIND_RUNNER_SCRIPT_NAMES[$i]} == "$1" ]]; then
      echo "$i"
      return 0
    fi
    i=$((i + 1))
  done
  return 1
}

# Fill __XCIND_RUNNER_TTY with (-T) when stdin or stdout is not a terminal,
# or when the user forced it with -T/--no-tty (__XCIND_RUNNER_NO_TTY=1).
__xcind-runner-tty-opts() {
  __XCIND_RUNNER_TTY=()
  if [[ ${__XCIND_RUNNER_NO_TTY:-0} == "1" ]] || [ ! -t 0 ] || [ ! -t 1 ]; then
    __XCIND_RUNNER_TTY=(-T)
  fi
}

# docker compose with the app's resolved options.
__xcind-runner-compose() {
  docker compose ${XCIND_DOCKER_COMPOSE_OPTS[@]+"${XCIND_DOCKER_COMPOSE_OPTS[@]}"} "$@"
}

# Run one declared bin: exec (or run --rm) its cmd in its service, always
# appending the caller's args.
#   $1 = bin index, rest = args
__xcind-runner-exec-bin() {
  local idx=$1
  shift
  local service="${__XCIND_RUNNER_BIN_SERVICES[$idx]}"
  local use="${__XCIND_RUNNER_BIN_USES[$idx]}"
  local cmd="${__XCIND_RUNNER_BIN_CMDS[$idx]}"

  # The cmd may contain spaces; tokenize it at run time (no expansion).
  __xcind-runner-split "$cmd" || return $?
  local cmd_argv
  cmd_argv=("${__XCIND_RUNNER_TOKENS[@]}")

  __xcind-runner-tty-opts
  if [[ $use == "run" ]]; then
    __xcind-runner-compose run --rm \
      ${__XCIND_RUNNER_TTY[@]+"${__XCIND_RUNNER_TTY[@]}"} \
      "$service" "${cmd_argv[@]}" "$@"
  else
    __xcind-runner-compose exec \
      ${__XCIND_RUNNER_TTY[@]+"${__XCIND_RUNNER_TTY[@]}"} \
      "$service" "${cmd_argv[@]}" "$@"
  fi
}

# Run one of the step keywords with an already-built argv.
#   @exec <svc> [cmd…]   — no cmd defaults to bash
#   @run <svc> <cmd…>    — cmd required
#   @compose <args…>     — forwarded verbatim
__xcind-runner-exec-keyword() {
  local kind=$1
  shift

  case $kind in
  @exec)
    if [[ $# -eq 0 ]]; then
      echo "xcind-run: @exec requires a service" >&2
      return 64
    fi
    local svc=$1
    shift
    if [[ $# -eq 0 ]]; then
      set -- bash
    fi
    __xcind-runner-tty-opts
    __xcind-runner-compose exec \
      ${__XCIND_RUNNER_TTY[@]+"${__XCIND_RUNNER_TTY[@]}"} "$svc" "$@"
    ;;
  @run)
    if [[ $# -eq 0 ]]; then
      echo "xcind-run: @run requires a service" >&2
      return 64
    fi
    local svc=$1
    shift
    if [[ $# -eq 0 ]]; then
      echo "xcind-run: @run requires a command" >&2
      return 64
    fi
    __xcind-runner-tty-opts
    __xcind-runner-compose run --rm \
      ${__XCIND_RUNNER_TTY[@]+"${__XCIND_RUNNER_TTY[@]}"} "$svc" "$@"
    ;;
  @compose)
    __xcind-runner-compose "$@"
    ;;
  *)
    echo "xcind-run: unknown keyword '$kind'" >&2
    return 1
    ;;
  esac
}

# Run one step of a script.
#   $1 = owning script name (for messages)
#   $2 = append mode (1 = one-step script with no $@: append args)
#   $3 = step text (- prefix already stripped)
#   rest = the script's args
__xcind-runner-run-step() {
  local sname=$1
  local append=$2
  local step=$3
  shift 3

  if [[ $step != @* ]]; then
    # Host step: bash expands $@ (the only place expansion happens).
    local text=$step
    if [[ $append == "1" ]]; then
      text="$text \"\$@\""
    fi
    bash -c "$text" xcind-run "$@"
    return $?
  fi

  # @-step: tokenize (no expansion), splicing args where $@ appeared.
  __xcind-runner-split "$step" || return $?
  local toks spl
  toks=("${__XCIND_RUNNER_TOKENS[@]}")
  spl=("${__XCIND_RUNNER_SPLICE[@]}")

  local kw="${toks[0]}"
  local argv=()
  local i=1
  local count=${#toks[@]}
  while [ "$i" -lt "$count" ]; do
    if [[ ${spl[$i]} == "1" ]]; then
      argv+=("$@")
    else
      argv+=("${toks[$i]}")
    fi
    i=$((i + 1))
  done
  if [[ $append == "1" ]]; then
    argv+=("$@")
  fi

  case $kw in
  @exec | @run | @compose)
    __xcind-runner-exec-keyword "$kw" ${argv[@]+"${argv[@]}"}
    ;;
  *)
    local ref="${kw#@}"
    local idx
    if idx=$(__xcind-runner-bin-index "$ref"); then
      __xcind-runner-exec-bin "$idx" ${argv[@]+"${argv[@]}"}
    elif idx=$(__xcind-runner-script-index "$ref"); then
      __xcind-runner-run-script "$idx" ${argv[@]+"${argv[@]}"}
    else
      echo "xcind-run: unknown bin or script '$ref' (step in script '$sname')" >&2
      return 1
    fi
    ;;
  esac
}

# Run a script's steps in order, stopping at the first failure with its
# exit status. A step's leading '-' means its failure is ignored. Guards
# against reference cycles with a call stack of script names.
#   $1 = script index, rest = args
__xcind-runner-run-script() {
  local idx=$1
  shift
  local name="${__XCIND_RUNNER_SCRIPT_NAMES[$idx]}"

  case ",${__XCIND_RUNNER_STACK:-}," in
  *",$name,"*)
    local path="${__XCIND_RUNNER_STACK//,/ -> } -> $name"
    echo "xcind-run: script cycle: $path" >&2
    return 1
    ;;
  esac
  __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK:+$__XCIND_RUNNER_STACK,}$name"

  local steps=()
  local line
  while IFS= read -r line; do
    steps+=("$line")
  done <<<"${__XCIND_RUNNER_SCRIPT_STEPS[$idx]}"

  # Args are passed only where a bare $@ appears; a one-step script with
  # no $@ appends them; a multi-step script with no $@ takes none.
  local has_splice=0
  local step body flag
  for step in "${steps[@]}"; do
    body="${step#-}"
    __xcind-runner-split "$body" || return $?
    for flag in ${__XCIND_RUNNER_SPLICE[@]+"${__XCIND_RUNNER_SPLICE[@]}"}; do
      if [[ $flag == "1" ]]; then
        has_splice=1
        break
      fi
    done
  done

  local append=0
  if [[ ${#steps[@]} -eq 1 ]] && [[ $has_splice -eq 0 ]]; then
    append=1
  fi
  if [[ $has_splice -eq 0 ]] && [[ $append -eq 0 ]] && [[ $# -gt 0 ]]; then
    echo "xcind-run: script '$name' accepts no arguments (no \$@ in its steps)" >&2
    __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%"$name"}"
    __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%,}"
    return 64
  fi

  local rc ignore
  for step in "${steps[@]}"; do
    ignore=0
    if [[ $step == -* ]]; then
      ignore=1
      step="${step#-}"
      step="${step#"${step%%[![:space:]]*}"}"
    fi
    rc=0
    __xcind-runner-run-step "$name" "$append" "$step" "$@" || rc=$?
    if [[ $rc -ne 0 ]] && [[ $ignore -eq 0 ]]; then
      __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%"$name"}"
      __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%,}"
      return $rc
    fi
  done

  __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%"$name"}"
  __XCIND_RUNNER_STACK="${__XCIND_RUNNER_STACK%,}"
  return 0
}

# Dispatch a CLI name: a step keyword, a bin, or a script.
# Requires __xcind-runner-load to have run.
#   $1 = name, rest = args
__xcind-runner-dispatch() {
  local name=$1
  shift

  case $name in
  @exec | @run | @compose)
    __xcind-runner-exec-keyword "$name" "$@"
    return $?
    ;;
  esac

  local idx
  if idx=$(__xcind-runner-bin-index "$name"); then
    __xcind-runner-exec-bin "$idx" "$@"
  elif idx=$(__xcind-runner-script-index "$name"); then
    __XCIND_RUNNER_STACK=""
    __xcind-runner-run-script "$idx" "$@"
  else
    echo "xcind-run: unknown bin or script '$name'" >&2
    return 1
  fi
}

# Print the declared bins and scripts. Names with a leading '_' are
# hidden (but stay runnable).
#   $1 = 1 to print bare names only
__xcind-runner-list() {
  local names_only=${1:-0}
  local i count name desc service

  if [[ $names_only == "1" ]]; then
    for name in ${__XCIND_RUNNER_BIN_NAMES[@]+"${__XCIND_RUNNER_BIN_NAMES[@]}"}; do
      [[ $name == _* ]] && continue
      echo "$name"
    done
    for name in ${__XCIND_RUNNER_SCRIPT_NAMES[@]+"${__XCIND_RUNNER_SCRIPT_NAMES[@]}"}; do
      [[ $name == _* ]] && continue
      echo "$name"
    done
    return 0
  fi

  local printed_bins=0
  i=0
  count=${#__XCIND_RUNNER_BIN_NAMES[@]}
  while [ "$i" -lt "$count" ]; do
    name="${__XCIND_RUNNER_BIN_NAMES[$i]}"
    service="${__XCIND_RUNNER_BIN_SERVICES[$i]}"
    desc="${__XCIND_RUNNER_BIN_DESCS[$i]}"
    i=$((i + 1))
    [[ $name == _* ]] && continue
    if [[ $printed_bins -eq 0 ]]; then
      echo "bins:"
      printed_bins=1
    fi
    if [[ -n $desc ]]; then
      printf '  %-20s %-12s %s\n' "$name" "($service)" "$desc"
    else
      printf '  %-20s %s\n' "$name" "($service)"
    fi
  done

  local printed_scripts=0
  i=0
  count=${#__XCIND_RUNNER_SCRIPT_NAMES[@]}
  while [ "$i" -lt "$count" ]; do
    name="${__XCIND_RUNNER_SCRIPT_NAMES[$i]}"
    desc="${__XCIND_RUNNER_SCRIPT_DESCS[$i]}"
    i=$((i + 1))
    [[ $name == _* ]] && continue
    if [[ $printed_scripts -eq 0 ]]; then
      if [[ $printed_bins -eq 1 ]]; then
        echo ""
      fi
      echo "scripts:"
      printed_scripts=1
    fi
    if [[ -n $desc ]]; then
      printf '  %-20s %s\n' "$name" "$desc"
    else
      printf '  %s\n' "$name"
    fi
  done
  return 0
}

# Emit shell wrapper functions for every visible bin and script:
#   <prefix><name>() { xcind-run <name> "$@"; }
# Names with a leading '_' are skipped, like --list.
#   $1 = wrapper prefix (default x-)
__xcind-runner-init-shell() {
  local prefix=${1:-x-}
  local name
  for name in ${__XCIND_RUNNER_BIN_NAMES[@]+"${__XCIND_RUNNER_BIN_NAMES[@]}"} \
    ${__XCIND_RUNNER_SCRIPT_NAMES[@]+"${__XCIND_RUNNER_SCRIPT_NAMES[@]}"}; do
    [[ $name == _* ]] && continue
    printf '%s%s() { xcind-run %s "$@"; }\n' "$prefix" "$name" "$name"
  done
  return 0
}
