# 04 — lib/ safety cleanups

**Scope:** Small (three independent fixes in `lib/xcind/`)
**Risk:** Low
**Depends on:** nothing
**Blocks:** nothing
**Conflicts with:** nothing (unless #06 is in flight — both touch
`xcind-lib.bash` but in distant sections)

---

## Problem

Three small correctness / robustness issues surfaced in the deep Bash
audit. None are ticking time bombs, but all three are the kind of thing a
senior shell programmer would fix on sight.

1. **Nested functions in `__xcind-check-deps` leak on early return.**
2. **`local IFS=';'` idiom in `__xcind-resolve-tools` assumes inherited
   IFS is default.**
3. **`__xcind-expand-vars` trust boundary is undocumented.**

The fixes are all small and independent, but they share a scope
(`lib/xcind/xcind-lib.bash`) and a theme (defensive hygiene), so ship
them as one commit.

---

## 4.1 — Nested functions leak on early return

### Evidence

**`lib/xcind/xcind-lib.bash:1022-1138`** — `__xcind-check-deps` defines
three helpers inside its body: `__check_required`, `__check_optional`,
`__dep_version`. Because Bash has no lexical nested functions, these go
straight into the global function namespace. The function ends with:

```bash
# clean up helpers from the shell namespace
unset -f __check_required __check_optional __dep_version

return "$rc"
```

The `unset -f` only runs on the normal exit path. If any command in the
body fails under `set -e` (e.g., a `printf` to a closed stdout), the
function exits without cleanup and the helpers persist in the global
namespace until the shell ends.

Today the impact is limited because `__xcind-check-deps` is only called
by `xcind-config --check`, which is a terminal action — the script
exits immediately after, so any leaked functions disappear with the
process. But this is future-unsafe: if anything else starts calling
`__xcind-check-deps` (a status bar, a notification hook, a library
consumer), the leaked helpers could collide with user-defined functions
of the same name.

### Fix

Two clean options:

**Option A (recommended): move the helpers to file scope** with a
`__xcind-check-deps-` prefix so they don't look like candidates for
reuse or collision.

```bash
# File-scope helpers for __xcind-check-deps. Prefixed to avoid collisions
# and to make the scope relationship obvious.
__xcind-check-deps-version() {
  local cmd="$1" out
  case "$cmd" in
  bash) out=$(bash --version 2>/dev/null) && echo "$out" | head -1 | sed 's/.*version \([^ ]*\).*/\1/' ;;
  docker) docker --version 2>/dev/null | sed 's/Docker version \([^,]*\).*/\1/' ;;
  "docker compose") docker compose version --short 2>/dev/null || echo "?" ;;
  jq) jq --version 2>/dev/null | sed 's/^jq-//' ;;
  yq) yq --version 2>/dev/null | sed 's/.*version v\{0,1\}//' ;;
  sha256sum) out=$(sha256sum --version 2>/dev/null) && echo "$out" | head -1 | sed 's/.*(GNU coreutils) //' ;;
  shasum) out=$(shasum --version 2>/dev/null) && echo "$out" | head -1 || echo "?" ;;
  *) echo "" ;;
  esac
}

__xcind-check-deps-required() {
  local cmd="$1" purpose="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ✓ %-20s %s\n" "$cmd" "$(__xcind-check-deps-version "$cmd")"
    return 0
  fi
  printf "  ✗ %-20s %-12s  %s\n" "$cmd" "(not found)" "$purpose"
  return 1
}
# ... and so on for optional
```

The helpers no longer need to mutate `rc` / `required_missing` /
`warnings` by closure — they return a status, and the caller accumulates.

**Option B (less invasive): keep the nested definitions but guarantee
cleanup with `trap ... RETURN`.**

```bash
__xcind-check-deps() {
  local rc=0
  local required_missing=0
  local warnings=0

  __check_required() { ... }
  __check_optional() { ... }
  __dep_version() { ... }

  # Guarantee cleanup on any exit path, including set -e.
  trap 'unset -f __check_required __check_optional __dep_version' RETURN

  # ... rest of the body ...
}
```

`trap ... RETURN` fires when the function returns for any reason.
Delete the explicit `unset -f` at the end (redundant with the trap).

**Recommendation:** Option A. File-scope functions are more idiomatic
Bash and easier to shellcheck.

### Acceptance

- [ ] `__xcind-check-deps` no longer defines functions inside its body.
- [ ] The former helpers live at file scope with a `__xcind-check-deps-`
  prefix.
- [ ] The mutation-by-closure pattern is replaced with explicit return
  values + caller accumulation.
- [ ] `xcind-config --check` output is byte-identical to before.
- [ ] `make check` passes.

---

## 4.2 — `local IFS=';'` idiom in `__xcind-resolve-tools`

### Evidence

**`lib/xcind/xcind-lib.bash:508-521`** (approximate line numbers after
`368db82`):

```bash
if [[ -n $meta ]]; then
  local IFS=';'
  local pairs
  # shellcheck disable=SC2206
  pairs=($meta)
  unset IFS
  local pair
  for pair in "${pairs[@]}"; do
    ...
  done
fi
```

The idiom `local IFS=';'; ...; unset IFS` is trying to temporarily
override the field separator. But `unset IFS` inside a function doesn't
restore the *caller's* IFS — it removes the local binding and exposes
whatever the inherited IFS was, which may not be the default
`$' \t\n'`. In this function the next interesting expansion is the
`for pair in "${pairs[@]}"` loop, which doesn't depend on IFS (`@`
with double quotes is unaffected), so there's no visible bug. But the
idiom is wrong and will bite someone later.

### Fix

Use the save-restore pattern or (better) avoid changing IFS at the
function scope:

```bash
if [[ -n $meta ]]; then
  local _old_ifs="$IFS"
  IFS=';'
  local pairs
  # shellcheck disable=SC2206
  pairs=($meta)
  IFS="$_old_ifs"
  local pair
  for pair in "${pairs[@]}"; do
    ...
  done
fi
```

Or, even better, avoid IFS manipulation by using parameter expansion:

```bash
if [[ -n $meta ]]; then
  # Split $meta on ';' into an array without touching IFS.
  local pairs=()
  local remainder="$meta" pair
  while [[ -n $remainder ]]; do
    pair="${remainder%%;*}"
    pairs+=("$pair")
    if [[ $remainder == *";"* ]]; then
      remainder="${remainder#*;}"
    else
      remainder=""
    fi
  done
  local p
  for p in "${pairs[@]}"; do
    ...
  done
fi
```

**Recommendation:** the save-restore version. The parameter-expansion
loop is strictly better but adds 7 lines for a benefit that doesn't
matter in the hot path.

### Acceptance

- [ ] `local IFS=';'` is replaced with save + restore.
- [ ] `__xcind-resolve-tools` output is unchanged (existing tests cover
  this).
- [ ] `make check` passes.

---

## 4.3 — Document `__xcind-expand-vars` trust boundary

### Evidence

**`lib/xcind/xcind-lib.bash:203-211`** (approximate) — `__xcind-expand-vars`:

```bash
__xcind-expand-vars() {
  local pattern="$1"
  local expanded="" _prev_glob=on
  case $- in *f*) _prev_glob=off ;; esac
  set -f
  eval "expanded=\"${pattern//\"/\\\"}\"" 2>/dev/null || expanded=""
  [ "$_prev_glob" = on ] && set +f
  printf '%s' "$expanded"
}
```

This is a deliberate `eval` to expand `$VAR`, `${VAR}`, and `$(cmd)`
references in config-file patterns. The function is called on strings
read from `.xcind.sh` files in the app root and its parent workspace
root. The trust model is: **`.xcind.sh` is user-authored code, so
executing it is equivalent to the user running it.**

That assumption breaks during **`xcind-workspace status`**. The command
walks the workspace tree with `for subdir in "$ws_root"/*/` and calls
`xcind-config --json` in a subshell for each subdirectory's
`.xcind.sh`. If the workspace root happens to contain an untrusted
subdirectory (cloned repo, downloaded archive, other people's
checkouts), running `xcind-workspace status` executes arbitrary code
from those `.xcind.sh` files via `eval`.

This is **low risk in practice** — users already run untrusted code
constantly in dev environments, and `.xcind.sh` is obviously an
execution surface — but it's undocumented. The fix is a clear note in
the function's header comment.

### Fix

Add a comment block above `__xcind-expand-vars` and to the
`xcind-workspace status` help text:

```bash
# Expand $VAR and ${VAR} references in a pattern from .xcind.sh.
# Prints the expanded result to stdout, or empty on failure.
#
# TRUST BOUNDARY: this function uses eval to honor command substitution
# ($()) for backward compatibility with existing .xcind.sh files.
# Callers must ensure the pattern comes from a .xcind.sh file the user
# trusts. Specifically:
#   - xcind-compose and xcind-config are safe: they walk upward from
#     $PWD, so the user has already chosen to `cd` into the app.
#   - xcind-workspace status walks DOWNWARD through subdirectories and
#     invokes xcind-config on each child. If a workspace root contains
#     untrusted clones, `status` will execute code from their .xcind.sh
#     files. This is a known limitation — the workspace model assumes
#     all apps under a workspace root are trusted.
#
# Compared to `eval echo "$pattern"`, this:
#   - Does not go through echo, so patterns like "-n" round-trip correctly.
#   - Disables glob expansion during the eval, so "*.yaml" is not expanded
#     against CWD.
# ...
```

And add a note to `bin/xcind-workspace --help` output, or at minimum to
the `status` subcommand help:

> Note: `status` invokes xcind-config on every subdirectory containing
> `.xcind.sh`. If the workspace root contains untrusted directories,
> those `.xcind.sh` files will be sourced and may execute arbitrary
> code. Only run `status` inside workspace roots you control.

### Acceptance

- [ ] `__xcind-expand-vars` header comment includes the trust-boundary
  note.
- [ ] `xcind-workspace status --help` output includes a one-line warning
  (or the man page / README section does).
- [ ] No code changes to `__xcind-expand-vars` itself — the eval is
  deliberate.

### Alternative (out of scope for this package)

A proper fix would be to narrow the eval to variable expansion only
(no `$(cmd)`), then either deprecate `$(cmd)` in patterns or gate it
behind an explicit `XCIND_ALLOW_COMMAND_SUBSTITUTION=1` opt-in. That's
a behavior change that deserves an ADR and a deprecation cycle, not a
drive-by fix. File as a follow-up if you want to tackle it.

---

## Combined acceptance

- [ ] All three sub-items are addressed in one commit titled something
  like "lib: defensive cleanups in check-deps, resolve-tools, expand-vars".
- [ ] `make check` passes.
- [ ] `xcind-config --check` output is byte-identical to before.
- [ ] Test count is unchanged.

## Risk / rollback

- **Risk:** 4.1 and 4.2 change internal structure without changing
  behavior; test coverage verifies equivalence.
- **Rollback:** `git revert`; no dependencies.

## Scope estimate

1–2 hours total:
- 4.1: 40 minutes (Option A refactor)
- 4.2: 10 minutes (save/restore swap)
- 4.3: 20 minutes (documentation)
- 30 minutes: `make check` + commit

## Out of scope

- Do not refactor any other nested-function sites. Grep confirms
  `__xcind-check-deps` is the only place that does this in the project.
- Do not rewrite `__xcind-expand-vars` behavior. Only docs change.
- Do not add a `XCIND_SAFE_EXPAND` flag or similar gate — that's an ADR.
