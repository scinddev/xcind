# 02 — Test infrastructure hardening

**Scope:** Medium (touches both test files + adds `test/lib/`)
**Risk:** Low (no behavior changes to production code)
**Depends on:** nothing
**Blocks:** #03 (new tests should use the helpers this package extracts)
**Conflicts with:** anything else that modifies test file headers; sequence
them if possible.

---

## Problem

The test suite is hand-rolled Bash without a framework. That's fine for
this size, but the test files have accumulated the friction of scale:

1. **`assert_*` helpers are copy-pasted between the two test files** and
   already drifting. `assert_file_exists` exists only in the proxy file;
   `assert_not_contains` previously dropped the "actual" diagnostic line in
   the proxy file (fixed in `368db82`). The next drift is a matter of time.
2. **No `trap` cleanup of tempdirs.** 64 `mktemp -d` calls across the two
   files, zero `trap ... EXIT` handlers. Any `set -e` abort between
   `mktemp` and the explicit `rm -rf` leaks a tmpdir in `/tmp`.
3. **24 near-identical `unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR …` reset
   blocks** in `test-xcind.sh`. The list has drifted: some include
   `XCIND_ADDITIONAL_CONFIG_FILES`, some don't. One block had
   `XCIND_ENV_FILES` (deprecated) instead of `XCIND_COMPOSE_ENV_FILES` —
   fixed in `368db82`, but the duplication makes that kind of bug likely
   to recur.
4. **A few tautological assertions and silent `2>/dev/null` swallows** that
   hide would-be-visible regressions.

None of this breaks tests today. It makes tests brittle, and it blocks
cleanly-written new tests in package #03.

## Evidence

### Duplication / drift

- **`test/test-xcind.sh:13-50`** vs **`test/test-xcind-proxy.sh:13-60`** —
  `assert_eq`, `assert_contains`, `assert_not_contains` are duplicated
  nearly byte-identically. The proxy file additionally has
  `assert_file_exists` (lines 39-48) which is missing from `test-xcind.sh`.

- **`test/test-xcind.sh:268,281,568,603,645,669,713,806,842,850,871,893,
  937,988,1020,1058,1514,1524,1535,1556,1568,1583,1598,1613,1629`** —
  the 24 reset blocks. Canonical form (from line 268):

  ```bash
  unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR XCIND_COMPOSE_ENV_FILES \
        XCIND_APP_ENV_FILES XCIND_BAKE_FILES XCIND_TOOLS
  ```

  Drifting additions seen in the wild: `XCIND_ADDITIONAL_CONFIG_FILES`,
  `XCIND_STAGING_LOADED`, `XCIND_LOCAL_LOADED`. Intentional, but the
  core list is identical.

### Resource leaks

- **`test/test-xcind.sh`** — 47 `mktemp -d` calls, zero traps.
- **`test/test-xcind-proxy.sh`** — 17 `mktemp -d` calls, zero traps.
- Explicit `rm -rf` at the end of each section only runs on the normal exit
  path; any `set -e` abort (unbound var, unexpected command failure) leaks.

### Tautologies and silent-swallows

- **`test/test-xcind.sh:769`** — `assert_eq "empty execute hooks: no error"
  "0" "$?"` is tautological under `set -e`. If the previous call had
  failed, the script would have exited before this assert runs. The assert
  always passes regardless of the actual behavior.

- **`test/test-xcind.sh:108,451,1684,1940`** — `2>/dev/null` on calls
  whose stderr is now invisible:

  ```bash
  result=$(__xcind-app-root "$EMPTY_DIR" 2>/dev/null) && status=0 || status=$?
  ```

  If `__xcind-app-root` starts emitting a useful warning, the test hides
  it. Better: capture stderr and assert on both the exit code and the
  error text.

- **`test/test-xcind.sh:725,734`** — `beta_pos_miss` / `alpha_pos_miss`
  computed via `grep -n | cut` that can return empty strings, then
  compared with `-lt`. Works today; fragile.

- **`test/test-xcind.sh:464,750-768`** — seven uses of hardcoded
  `/tmp/test-app`. Works today only because `__xcind-run-execute-hooks`
  doesn't stat its argument. If another test (or the SUT) ever touches
  `/tmp/test-app`, these tests become non-deterministic.

---

## Proposed fix

### Step 1 — Create `test/lib/assert.sh`

Extract the shared helpers. Target:

```bash
#!/usr/bin/env bash
# test/lib/assert.sh — Shared assertion helpers for xcind test suites.
#
# Source from each test runner; updates PASS/FAIL in the caller's shell.

# Counters live in the caller. Initialize them before sourcing.
: "${PASS:=0}"
: "${FAIL:=0}"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack == *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ $haystack != *"$needle"* ]]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label"
    echo "    expected NOT to contain: $needle"
    echo "    actual: $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_missing() {
  local label="$1" path="$2"
  if [ ! -f "$path" ]; then
    echo "  ✓ $label"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $label (file exists: $path)"
    FAIL=$((FAIL + 1))
  fi
}

# Capture exit status of a command without triggering set -e.
# Usage: status=$(capture_status cmd args...)
capture_status() {
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  echo "$rc"
}
```

**Keep the existing assert_* pattern of updating `PASS`/`FAIL` via outer-scope
variables.** Switching to a return-code pattern would require rewriting
every call site for no benefit.

Update `test/test-xcind.sh:1-12` and `test/test-xcind-proxy.sh:1-12` to
source the new file:

```bash
#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XCIND_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$XCIND_ROOT/lib/xcind/xcind-lib.bash"

PASS=0
FAIL=0
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/assert.sh"
```

Delete the inline `assert_*` function definitions in both test files.

**Register the new file** in `install.sh`, `uninstall.sh`, `Makefile`
`SHELL_FILES`, `package.json` (probably not — tests aren't packaged),
`flake.nix` (probably not — same reason), `contrib/test-all`, and
`.github/workflows/tests.yml` as needed. The `add-installed-file` skill
normally triggers for `bin/*` and `lib/xcind/*` but the policy for
`test/lib/*` is undefined — use the `contrib/check-file-manifest` script
to find out what needs updating. Most likely only `Makefile` `SHELL_FILES`
needs the new entry.

### Step 2 — Add `test/lib/setup.sh` with tmpdir + reset helpers

```bash
#!/usr/bin/env bash
# test/lib/setup.sh — Shared setup / teardown helpers.
#
# Source after test/lib/assert.sh.

# All tempdirs created via mktemp_d get cleaned up on script exit.
_XCIND_TEST_TMPDIRS=()

mktemp_d() {
  local d
  d=$(mktemp -d)
  _XCIND_TEST_TMPDIRS+=("$d")
  printf '%s\n' "$d"
}

# shellcheck disable=SC2317 # registered as a trap
_xcind_cleanup_tmpdirs() {
  local d
  for d in "${_XCIND_TEST_TMPDIRS[@]+"${_XCIND_TEST_TMPDIRS[@]}"}"; do
    [ -d "$d" ] && rm -rf "$d"
  done
}
trap _xcind_cleanup_tmpdirs EXIT

# Reset the xcind config state that bleeds between test sections.
# Call at the top of every test block that loads a config, before any
# __xcind-load-config / __xcind-prepare-app invocation.
reset_xcind_state() {
  unset \
    XCIND_COMPOSE_FILES \
    XCIND_COMPOSE_DIR \
    XCIND_COMPOSE_ENV_FILES \
    XCIND_APP_ENV_FILES \
    XCIND_BAKE_FILES \
    XCIND_TOOLS \
    XCIND_ADDITIONAL_CONFIG_FILES \
    XCIND_ENV_FILES \
    XCIND_APP \
    XCIND_WORKSPACE \
    XCIND_WORKSPACE_ROOT \
    XCIND_WORKSPACELESS \
    XCIND_IS_WORKSPACE
  __XCIND_SOURCED_CONFIG_FILES=()
  XCIND_DOCKER_COMPOSE_OPTS=()
}
```

Source it right after `assert.sh`:

```bash
source "$SCRIPT_DIR/lib/assert.sh"
source "$SCRIPT_DIR/lib/setup.sh"
```

### Step 3 — Replace mechanical usages

Search-and-replace across both test files:

1. `mktemp -d` → `mktemp_d` (where the result is a tempdir the test creates
   and doesn't pass to external code that forks its own cleanup).
2. The 24 `unset XCIND_COMPOSE_FILES XCIND_COMPOSE_DIR …` blocks →
   `reset_xcind_state`. Preserve any **extra** vars the individual block
   unsets (`XCIND_STAGING_LOADED`, `XCIND_LOCAL_LOADED`, etc.) as a
   second line after the call.
3. Delete the explicit `rm -rf "$MOCK_APP"` calls wherever the dir came
   from `mktemp_d` — the trap handles it. Leave explicit cleanups in
   place where the test wants mid-section cleanup (between two tempdirs
   that can't coexist, for instance).

Expected diff: ~80 lines removed from `test-xcind.sh`, ~30 from
`test-xcind-proxy.sh`.

### Step 4 — Fix the tautology and a few silent-swallows

- **`test/test-xcind.sh:769`** — the assertion is noise. Either delete it
  (since `set -e` already enforces the invariant) or replace it with a
  meaningful check: e.g., verify that `__xcind-run-execute-hooks` with an
  empty `XCIND_HOOKS_EXECUTE` array doesn't mutate `XCIND_DOCKER_COMPOSE_OPTS`.

- **`test/test-xcind.sh:108`** — turn the silenced-stderr call into a
  captured one:

  ```bash
  result=$(__xcind-app-root "$EMPTY_DIR" 2>"$ERR_FILE") && status=0 || status=$?
  assert_eq "fails without .xcind.sh" "1" "$status"
  err=$(<"$ERR_FILE")
  assert_contains "error mentions missing .xcind.sh" ".xcind.sh" "$err"
  ```

  Same treatment for 451, 1684, 1940 — four similar sites.

- **`test/test-xcind.sh:464,750-768`** — replace `/tmp/test-app` with
  `mktemp_d`-allocated paths. Search for `test-app` and audit each match;
  there are about seven.

---

## Acceptance criteria

- [ ] `test/lib/assert.sh` exists and is sourced from both test files.
- [ ] `test/lib/setup.sh` exists and is sourced from both test files.
- [ ] The inline `assert_*` definitions are deleted from both test files.
- [ ] At least 20 of the 24 reset blocks in `test-xcind.sh` are replaced
  with `reset_xcind_state`.
- [ ] `mktemp -d` direct calls drop to near zero in both test files (use
  `grep -c 'mktemp -d'` before and after).
- [ ] Running `bash -c 'set -e; false' test/test-xcind.sh` leaves no
  leftover `/tmp/tmp.*` directories (manual verification).
- [ ] The tautological assertion at line 769 is either deleted or rewritten.
- [ ] The four silenced-stderr captures at 108/451/1684/1940 also assert on
  stderr content.
- [ ] `/tmp/test-app` no longer appears in `test/test-xcind.sh`.
- [ ] `make check` passes.
- [ ] Total test count is unchanged or higher (278 + 238 = 516 baseline).
- [ ] `Makefile` `SHELL_FILES` includes the new `test/lib/*.sh` files so
  shellcheck runs on them.

## Risk / rollback

- **Risk:** the mechanical replacement of `mktemp -d` is easy to get wrong
  in places where the calling code expects a path it manages itself. Do
  this in one commit, run the tests, and only then move on.
- **Rollback:** `git revert`; nothing else depends on the new files yet.

## Scope estimate

2–3 hours of focused work:
- 30 min: create `test/lib/assert.sh` + `setup.sh`, source from both files,
  delete inline defs, verify.
- 45 min: replace the 24 reset blocks in `test-xcind.sh`.
- 45 min: replace `mktemp -d` sites + remove now-dead explicit `rm -rf`.
- 20 min: fix the four silent-swallow sites + the tautology.
- 30 min: `make check`, adjust, commit.

## Out of scope

- **Do not introduce a test framework** (bats, shunit2, etc.). The audit
  concluded the hand-rolled runner is fine for this size.
- **Do not add `assert_regex` or any new assertion types** unless you hit
  a concrete need in the same PR.
- **Do not touch test logic beyond the targeted fixes.** The goal is
  mechanical: extract helpers, fix the clearly-broken assertions, move on.
- **Do not add `trap` cleanup to `test/` files outside of `test/lib/setup.sh`.**
  Centralize the cleanup; a per-file trap would be another drift hazard.
- **Do not rename existing `assert_*` functions** — every test in the file
  calls them.
