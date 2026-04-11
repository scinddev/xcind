# 05 — bin/ script polish

**Scope:** Small (five independent fixes across three files)
**Risk:** Low
**Depends on:** nothing
**Blocks:** nothing
**Conflicts with:** #01 (both touch `bin/xcind-proxy`; do sequentially)

---

## Problem

Five small issues in `bin/*` scripts, each independently fixable. None
break functionality today; they produce confusing error messages, mask
real problems, or miss edge cases. Each is a 1–5 line fix. Ship them as
one commit titled something like "bin: fix corner cases in config,
proxy, workspace flag parsing".

1. **`xcind-config --generate-*=` with empty value silently writes to
   stdout.**
2. **`xcind-config` calls `__xcind_bin_dir` four times for the same
   value.**
3. **`xcind-workspace status` glob misses hidden app directories.**
4. **`xcind-workspace status` masks real jq errors.**
5. **`xcind-proxy status` preview formatting loses quoting on paths
   with spaces.** (This is actually in `lib/xcind/xcind-lib.bash` but
   belongs here because it's a bin-facing output bug.)

---

## 5.1 — `--generate-*=` with empty value

### Evidence

**`bin/xcind-config:111-114`** and parallel blocks at 127 and 143:

```bash
--generate-docker-wrapper=*)
  _do_gen_docker_wrapper=true
  _gen_docker_wrapper_file="${1#*=}"
  _action_count=$((_action_count + 1))
  ;;
```

When a user writes `xcind-config --generate-docker-wrapper=`, the
`"${1#*=}"` expansion yields an empty string. `_gen_docker_wrapper_file`
is set to `""`, but the `--generate-docker-wrapper` flag does NOT claim
stdout via `__xcind_config_claim_stdout`. Later, at
`bin/xcind-config:262-268`:

```bash
if [[ $_do_gen_docker_wrapper == true ]]; then
  if [[ -n $_gen_docker_wrapper_file ]]; then
    __xcind-dump-docker-wrapper "$app_root" "$(__xcind_bin_dir)" >"$_gen_docker_wrapper_file"
  else
    __xcind-dump-docker-wrapper "$app_root" "$(__xcind_bin_dir)"
  fi
fi
```

The empty-file branch falls through to stdout without claiming it.
Consequence: if a user runs
`xcind-config --generate-docker-wrapper= --generate-docker-compose-wrapper=`,
both write to stdout, concatenating two wrappers into unusable output.
The separate-flag form (`--generate-docker-wrapper `) correctly
claims stdout at line 123, so this is specifically the `=` form bug.

### Fix

In each `--generate-*=*` branch, treat an empty value as "stdout" and
claim it:

```bash
--generate-docker-wrapper=*)
  _do_gen_docker_wrapper=true
  _gen_docker_wrapper_file="${1#*=}"
  if [[ -z $_gen_docker_wrapper_file ]]; then
    __xcind_config_claim_stdout "generate-docker-wrapper"
  fi
  _action_count=$((_action_count + 1))
  ;;
```

Apply the same fix to `--generate-docker-compose-wrapper=*` and
`--generate-docker-compose-configuration=*`.

**Alternative:** reject empty values outright:

```bash
--generate-docker-wrapper=*)
  _do_gen_docker_wrapper=true
  _gen_docker_wrapper_file="${1#*=}"
  if [[ -z $_gen_docker_wrapper_file ]]; then
    __xcind_config_die "--generate-docker-wrapper= requires a file path (use --generate-docker-wrapper without = for stdout)"
  fi
  _action_count=$((_action_count + 1))
  ;;
```

**Recommendation:** reject empty values. It's a user-error path
(most people typing `--flag=` with no value mean to provide a value
and forgot), and the explicit error is clearer than silently routing
to stdout.

### Test

Add to the argument-parsing section of `test-xcind.sh`:

```bash
# --generate-*=  (empty value) should error
rc=0
"$XCIND_ROOT/bin/xcind-config" --generate-docker-wrapper= 2>/dev/null || rc=$?
assert_eq "empty generate-docker-wrapper= rejected" "1" "$rc"
```

---

## 5.2 — `__xcind_bin_dir` called multiple times

### Evidence

**`bin/xcind-config:247-254`** defines `__xcind_bin_dir`:

```bash
__xcind_bin_dir() {
  local xcind_compose_path
  if xcind_compose_path=$(command -v xcind-compose 2>/dev/null); then
    dirname "$xcind_compose_path"
  else
    echo "$XCIND_ROOT/bin"
  fi
}
```

**`bin/xcind-config:264-274`** calls it four times:

```bash
if [[ $_do_gen_docker_wrapper == true ]]; then
  if [[ -n $_gen_docker_wrapper_file ]]; then
    __xcind-dump-docker-wrapper "$app_root" "$(__xcind_bin_dir)" >"$_gen_docker_wrapper_file"
  else
    __xcind-dump-docker-wrapper "$app_root" "$(__xcind_bin_dir)"
  fi
fi

if [[ $_do_gen_compose_wrapper == true ]]; then
  if [[ -n $_gen_compose_wrapper_file ]]; then
    __xcind-dump-docker-compose-wrapper "$app_root" "$(__xcind_bin_dir)" >"$_gen_compose_wrapper_file"
  else
    __xcind-dump-docker-compose-wrapper "$app_root" "$(__xcind_bin_dir)"
  fi
fi
```

Each call is a subshell that forks a `command -v`. Harmless in absolute
terms, but the function is called 2–4 times per invocation for an
unchanging value.

### Fix

Compute once, reuse:

```bash
if [[ $_do_gen_docker_wrapper == true || $_do_gen_compose_wrapper == true ]]; then
  _xcind_bin_dir_cached=$(__xcind_bin_dir)
fi

if [[ $_do_gen_docker_wrapper == true ]]; then
  if [[ -n $_gen_docker_wrapper_file ]]; then
    __xcind-dump-docker-wrapper "$app_root" "$_xcind_bin_dir_cached" >"$_gen_docker_wrapper_file"
  else
    __xcind-dump-docker-wrapper "$app_root" "$_xcind_bin_dir_cached"
  fi
fi
# ... same for _do_gen_compose_wrapper
```

### Test

Not needed — no behavior change. Existing tests cover the generator
outputs.

---

## 5.3 — `xcind-workspace status` misses hidden app dirs

### Evidence

**`bin/xcind-workspace:222-231`** (approximate):

```bash
for subdir in "$ws_root"/*/; do
  [[ ! -d "$subdir" ]] && continue
  local app_candidate="${subdir%/}"
  [[ ! -f "$app_candidate/.xcind.sh" ]] && continue

  if ! __xcind-is-workspace-dir "$app_candidate"; then
    app_dirs+=("$app_candidate")
    app_names+=("$(basename "$app_candidate")")
  fi
done
```

The glob `"$ws_root"/*/` expands only to non-hidden directories. Apps
whose directory name starts with `.` (e.g., `.staging`, `.archive`)
are silently skipped. This might be intentional — or might just be an
oversight.

### Fix

**Option A (decide: silent skip is intentional).** Add a comment:

```bash
# Intentionally skip hidden directories. Apps in a directory starting
# with "." are not considered part of the workspace. If you need to
# include them, rename or move the app directory.
for subdir in "$ws_root"/*/; do
```

**Option B (include hidden dirs).** Use a more comprehensive glob:

```bash
# Include hidden directories so users can opt into . -prefixed app names.
local subdir
for subdir in "$ws_root"/*/ "$ws_root"/.*/; do
  [[ ! -d "$subdir" ]] && continue
  # Skip . and .. entries
  local base
  base=$(basename "${subdir%/}")
  [[ "$base" == "." || "$base" == ".." ]] && continue
  local app_candidate="${subdir%/}"
  ...
done
```

**Recommendation:** Option A. Silently including `.git` or `.cache` as
apps would be worse than the current behavior. A comment is enough.

### Test

If Option A, add a test that confirms the behavior:

```bash
# Workspace with a hidden subdir containing .xcind.sh: skipped
WS_HIDDEN=$(mktemp_d)
echo 'XCIND_IS_WORKSPACE=1' >"$WS_HIDDEN/.xcind.sh"
mkdir -p "$WS_HIDDEN/.staging"
echo '# hidden app' >"$WS_HIDDEN/.staging/.xcind.sh"

out=$("$XCIND_ROOT/bin/xcind-workspace" status "$WS_HIDDEN" 2>/dev/null)
assert_not_contains "hidden apps skipped" ".staging" "$out"
```

---

## 5.4 — `xcind-workspace status` masks real jq errors

### Evidence

**`bin/xcind-workspace:324`** (approximate, post-`368db82`):

```bash
_app_ws=$(printf '%s' "$_xcind_json" | jq -r '.metadata.workspace // ""' 2>/dev/null || echo "")
```

If `jq` fails because the JSON is malformed (a real bug in
`xcind-config --json`), `_app_ws` silently becomes `""`, the app is
treated as "not in this workspace", and the user never sees the
diagnostic.

### Fix

Capture stderr to a variable and surface it on failure:

```bash
local _jq_err
_app_ws=$(
  printf '%s' "$_xcind_json" | jq -r '.metadata.workspace // ""' 2>&1 1>&3
) 3>&1 || true
# Actually — the above is clumsy. Simpler:

local _app_ws_tmp _jq_rc=0
_app_ws_tmp=$(printf '%s' "$_xcind_json" | jq -r '.metadata.workspace // ""' 2>"$_err_file") || _jq_rc=$?
if [[ $_jq_rc -ne 0 ]]; then
  echo "xcind-workspace: warning: failed to parse metadata for $app_name: $(cat "$_err_file")" >&2
  _app_ws=""
else
  _app_ws="$_app_ws_tmp"
fi
```

**Recommendation:** fall back to empty (current behavior) but print a
stderr warning naming the app and the jq error. The app is still
skipped in the output, but the user knows why.

### Test

Harder to test without a flaky mock. Skip tests for this one; the
visible-warning behavior is the main improvement.

---

## 5.5 — `__xcind-preview-command` loses quoting

### Evidence

**`lib/xcind/xcind-lib.bash:751`**:

```bash
printf 'docker compose %s %s\n' "${XCIND_DOCKER_COMPOSE_OPTS[*]}" "$*"
```

`${XCIND_DOCKER_COMPOSE_OPTS[*]}` flattens the array with IFS-joined
concatenation. A compose file path containing a space (e.g.,
`~/Documents/My App/compose.yaml`) is printed as two tokens, and the
output is not copy-pasteable back into a shell.

Reproduction:

```bash
mkdir -p "/tmp/space dir"
cp your-compose.yaml "/tmp/space dir/compose.yaml"
cd "/tmp/space dir"
xcind-config --preview
# Output includes:
#   docker compose -f /tmp/space dir/compose.yaml ...
```

### Fix

Use `printf '%q'` to emit each array element in shell-quoted form:

```bash
__xcind-preview-command() {
  local app_root="$1"
  shift

  if [[ ${#XCIND_DOCKER_COMPOSE_OPTS[@]} -eq 0 ]]; then
    __xcind-build-compose-opts "$app_root"
  fi

  echo "# Working directory: $app_root"
  local _quoted=""
  local _arg
  for _arg in "${XCIND_DOCKER_COMPOSE_OPTS[@]}"; do
    _quoted+=" $(printf '%q' "$_arg")"
  done
  # Trim the leading space
  _quoted="${_quoted# }"

  local _passthrough=""
  for _arg in "$@"; do
    _passthrough+=" $(printf '%q' "$_arg")"
  done
  _passthrough="${_passthrough# }"

  if [[ -n $_passthrough ]]; then
    printf 'docker compose %s %s\n' "$_quoted" "$_passthrough"
  else
    printf 'docker compose %s\n' "$_quoted"
  fi
}
```

`printf '%q'` is a Bash builtin; it works on Bash 3.2. It emits
shell-safe forms like `/tmp/space\ dir/compose.yaml`.

### Test

Add a test in `test-xcind.sh`'s preview section:

```bash
# Preview with a path containing a space
PREVIEW_APP=$(mktemp_d)
mkdir -p "$PREVIEW_APP/with space"
cat >"$PREVIEW_APP/with space/compose.yaml" <<'YAMLEOF'
services:
  web:
    image: nginx
YAMLEOF
cat >"$PREVIEW_APP/.xcind.sh" <<EOF
XCIND_COMPOSE_FILES=("with space/compose.yaml")
EOF

out=$(XCIND_APP_ROOT="$PREVIEW_APP" "$XCIND_ROOT/bin/xcind-config" --preview 2>/dev/null)
assert_contains "preview quotes spaces" "with\\ space" "$out"
```

---

## Combined acceptance

- [ ] 5.1: `--generate-*=` with empty value produces a clear error.
- [ ] 5.2: `__xcind_bin_dir` is called at most once per
  `xcind-config` invocation.
- [ ] 5.3: hidden directories are either documented as skipped or
  included, with a test.
- [ ] 5.4: failed jq parse emits a warning naming the app.
- [ ] 5.5: `xcind-config --preview` output is copy-pasteable with
  paths containing spaces.
- [ ] `make check` passes.
- [ ] Total test count grows by 3–4 assertions.

## Risk / rollback

- **Risk:** 5.5's `printf '%q'` output format differs from the
  current unquoted output; any test or script that greps for the old
  form will break. Grep for `xcind-config --preview` in tests and
  scripts before shipping.
- **Rollback:** all fixes are small, independent, and easy to revert
  piecemeal.

## Scope estimate

1.5 hours total:
- 5.1: 15 min
- 5.2: 10 min
- 5.3: 10 min (Option A + comment + test)
- 5.4: 20 min
- 5.5: 30 min (including test)
- 20 min: `make check` + commit

## Out of scope

- Do not redesign `xcind-config`'s flag parsing. The bugs here are
  single-line.
- Do not add new `xcind-workspace` subcommands. The scope is polishing
  existing behavior.
- Do not rewrite `__xcind-preview-command` to use `set -x`-style output
  or a DSL. `printf '%q'` is the standard Bash idiom.
