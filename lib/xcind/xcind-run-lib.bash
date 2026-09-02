#!/usr/bin/env bash
# xcind-run-lib.bash — Bin and script parsing for xcind-run
#
# This library provides parsing and JSON serialization for XCIND_BINS and
# XCIND_SCRIPTS declarations. It is sourced by bin/xcind-run (and indirectly
# via xcind-lib.bash for JSON contract and SHA computation).

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
  if [[ ${#XCIND_BINS[@]} -eq 0 ]]; then
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
# Scripts parsing
# --------------------------------------------------------------------------

# Tokenize a single XCIND_SCRIPTS entry into its components.
# Format: name:service[;key=value…][;@ref step1][;@ref step2]…
#
# Steps use @ref syntax: @ref bin-name [arg1 [arg2 …]]
#   @ref bin-name         → bin reference with no arguments
#   @ref bin-name arg1    → bin reference with one argument
#   @ref bin-name arg1…   → bin reference with multiple arguments
#
# Metadata keys (same as XCIND_BINS): desc
# Duplicate keys produce the last value.
#
# Populates:
#   __SCRIPT_TOKEN_NAME     — script name
#   __SCRIPT_TOKEN_SERVICE  — Docker Compose service
#   __SCRIPT_TOKEN_DESC     — description (empty when absent)
#   __SCRIPT_TOKEN_STEPS    — array of raw step strings (@ref bin-name [args…])
#
# Returns 0 on success, 1 on validation error (message to stderr).
__xcind-runner-tokenize-script-entry() {
  local entry="$1"

  # ── name:service — must contain a colon ──
  if [[ $entry != *:* ]]; then
    echo "invalid XCIND_SCRIPTS entry '$entry' (expected name:service[;key=value…][;@ref step…])" >&2
    return 1
  fi

  __SCRIPT_TOKEN_NAME="${entry%%:*}"
  local remainder="${entry#*:}"

  # Empty name → error
  if [[ -z $__SCRIPT_TOKEN_NAME ]]; then
    echo "invalid XCIND_SCRIPTS entry '$entry' (name must not be empty)" >&2
    return 1
  fi

  # Name starts with @ or - or has whitespace → error
  if [[ $__SCRIPT_TOKEN_NAME == @* ]] || [[ $__SCRIPT_TOKEN_NAME == -* ]] || [[ $__SCRIPT_TOKEN_NAME =~ [[:space:]] ]]; then
    echo "invalid XCIND_SCRIPTS entry '$entry' (name must not start with @ or - or contain whitespace)" >&2
    return 1
  fi

  # service = between first ':' and first ';' (or end of remainder)
  __SCRIPT_TOKEN_SERVICE="${remainder%%;*}"
  if [[ $__SCRIPT_TOKEN_SERVICE == "$remainder" ]]; then
    # No semicolon — service is the whole remainder, no metadata or steps
    remainder=""
  else
    remainder="${remainder#*;}"
  fi

  # Empty service → error
  if [[ -z $__SCRIPT_TOKEN_SERVICE ]]; then
    echo "invalid XCIND_SCRIPTS entry '$entry' (service must not be empty)" >&2
    return 1
  fi

  # ── remainder — key=value metadata and @ref steps ──
  __SCRIPT_TOKEN_DESC=""
  __SCRIPT_TOKEN_STEPS=()

  if [[ -n $remainder ]]; then
    local _old_ifs="$IFS"
    IFS=';'
    # shellcheck disable=SC2206
    local parts=($remainder)
    IFS="$_old_ifs"

    local part
    for part in "${parts[@]}"; do
      # Skip empty pairs
      [[ -z $part ]] && continue

      if [[ $part == @ref\ * ]]; then
        # Step reference — "@ref " followed by at least one char
        __SCRIPT_TOKEN_STEPS+=("$part")
      elif [[ $part == *=* ]]; then
        # Metadata — key=value
        local key="${part%%=*}"
        local val="${part#*=}"
        case "$key" in
        desc) __SCRIPT_TOKEN_DESC="$val" ;;
        *)
          echo "unknown XCIND_SCRIPTS attribute '$key' in '$entry'" >&2
          return 1
          ;;
        esac
      else
        # Not metadata and not @ref — error
        echo "invalid XCIND_SCRIPTS entry '$entry' (expected key=value or @ref step, got '$part')" >&2
        return 1
      fi
    done
  fi

  # Must have at least one @ref step
  if [[ ${#__SCRIPT_TOKEN_STEPS[@]} -eq 0 ]]; then
    echo "invalid XCIND_SCRIPTS entry '$entry' (must have at least one @ref step)" >&2
    return 1
  fi

  return 0
}

# Parse XCIND_SCRIPTS into a JSON object keyed by script name.
# Validates every entry; exits 1 on the first error.
#
# Format: name:service[;key=value…][;@ref step1][;@ref step2]…
# Steps use @ref bin-name [args…]
# Duplicate names are an error (no first-wins).
#
# Usage:
#   __xcind-runner-scripts-json
#   # prints: {"deploy":{"service":"app","steps":[{"ref":"npm","args":["install"]}],"desc":"Deploy"}}
__xcind-runner-scripts-json() {
  if [[ -n ${XCIND_SCRIPTS+x} ]] && [[ ${#XCIND_SCRIPTS[@]} -eq 0 ]]; then
    echo "{}"
    return 0
  fi

  local seen_names=""
  local first=true
  local entry

  printf '{'
  for entry in "${XCIND_SCRIPTS[@]}"; do
    # Tokenize
    if ! __xcind-runner-tokenize-script-entry "$entry"; then
      return 1
    fi

    local name="$__SCRIPT_TOKEN_NAME"
    local service="$__SCRIPT_TOKEN_SERVICE"
    local desc="$__SCRIPT_TOKEN_DESC"
    local -a steps=("${__SCRIPT_TOKEN_STEPS[@]}")

    # Duplicate name check (error instead of first-wins)
    case ",$seen_names," in
    *",$name,"*)
      echo "duplicate XCIND_SCRIPTS entry '$name'" >&2
      return 1
      ;;
    esac
    seen_names="${seen_names:+$seen_names,}$name"

    # Build steps JSON array
    local steps_json_parts=()
    local step
    for step in "${steps[@]}"; do
      # Strip "@ref " prefix (5 chars)
      local step_body="${step#@ref }"

      # If stripping didn't change anything, @ref was bare — error
      if [[ $step_body == "$step" ]]; then
        echo "invalid XCIND_SCRIPTS entry '$entry' (@ref step must specify a bin name)" >&2
        return 1
      fi

      # Parse bin name and optional arguments
      local bin_name args_json
      if [[ $step_body == *\ * ]]; then
        # Has arguments: "@ref bin-name arg1 arg2"
        bin_name="${step_body%% *}"
        local args_str="${step_body#* }"

        # Build args JSON array
        args_json="["
        local arg_first=true
        local _old_ifs="$IFS"
        IFS=' '
        # shellcheck disable=SC2206
        local args_arr=($args_str)
        IFS="$_old_ifs"

        for arg in "${args_arr[@]}"; do
          if [[ $arg_first == true ]]; then
            arg_first=false
          else
            args_json+=","
          fi
          args_json+="$(printf '%s' "$arg" | jq -R .)"
        done
        args_json+="]"
      else
        # No arguments: "@ref bin-name"
        bin_name="$step_body"
        args_json="[]"
      fi

      # Validate bin name is not empty
      if [[ -z $bin_name ]]; then
        echo "invalid XCIND_SCRIPTS entry '$entry' (@ref step must specify a bin name)" >&2
        return 1
      fi

      # Use jq to produce the step JSON object
      local step_json
      step_json=$(jq -n \
        --arg ref "$bin_name" \
        --argjson args "$args_json" \
        '{ref: $ref, args: $args}')
      steps_json_parts+=("$step_json")
    done

    # Join steps into a JSON array
    local all_steps_json="["
    local sfirst=true
    local sj
    for sj in "${steps_json_parts[@]}"; do
      if [[ $sfirst == true ]]; then
        sfirst=false
      else
        all_steps_json+=","
      fi
      all_steps_json+="$sj"
    done
    all_steps_json+="]"

    # Emit JSON for this entry
    if [[ $first == true ]]; then
      first=false
    else
      printf ','
    fi

    if [[ -n $desc ]]; then
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --argjson stp "$all_steps_json" --arg d "$desc" \
          '{service: $s, steps: $stp, desc: $d}')"
    else
      printf '%s:%s' \
        "$(printf '%s' "$name" | jq -R .)" \
        "$(jq -n --arg s "$service" --argjson stp "$all_steps_json" \
          '{service: $s, steps: $stp}')"
    fi
  done
  printf '}'
  return 0
}
