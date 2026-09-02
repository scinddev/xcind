#!/usr/bin/env bash
# xcind-run-lib.bash — Bin and script parsing for xcind-run
#
# This library provides the step tokenizer and the parsing and JSON
# serialization for XCIND_BINS and XCIND_SCRIPTS declarations. It is
# sourced by bin/xcind-run (and indirectly via xcind-lib.bash for the
# JSON contract and SHA computation).

__XCIND_RUN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------------
# Bins parsing
# --------------------------------------------------------------------------

# Parse XCIND_BINS into a JSON object keyed by bin name.
# Validates every entry; exits 1 on the first error.
#
# Format: name:service[;key=value…]
# Keys: cmd (default = name), use = exec|run, desc
# Duplicate names are an error (no first-wins).
#
# Usage:
#   __xcind-runner-bins-json
#   # prints: {"php":{"service":"app","use":"exec","cmd":"php"},"npm":{"service":"app","use":"exec","cmd":"npm"}}
__xcind-runner-bins-json() {
  if [[ -z ${XCIND_BINS+x} ]] || [[ ${#XCIND_BINS[@]} -eq 0 ]]; then
    echo "{}"
    return 0
  fi

  local seen_names=""
  local first=true
  local entry name service remainder use cmd desc key val

  printf '{'
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
      local _old_ifs="$IFS"
      IFS=';'
      local pairs
      # shellcheck disable=SC2206
      pairs=($remainder)
      IFS="$_old_ifs"
      local pair
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

    # Emit JSON
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
