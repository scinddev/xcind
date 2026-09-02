#!/usr/bin/env bash
# xcind-run-lib.bash — Bin parsing for xcind-run
#
# This library provides parsing and JSON serialization for XCIND_BINS
# declarations. It is sourced by bin/xcind-run (and indirectly via
# xcind-lib.bash for JSON contract and SHA computation).

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
