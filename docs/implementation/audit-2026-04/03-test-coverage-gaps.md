# 03 — Close test coverage gaps

**Scope:** Large (net-new tests across several areas)
**Risk:** Low (tests only; no production changes)
**Depends on:** #02 (use the extracted `test/lib/*.sh` helpers)
**Blocks:** #06 (the concurrency tests here verify #06's refactor)
**Conflicts with:** #02 if done in parallel (both modify test file headers)

---

## Problem

The existing 516 assertions cover the happy paths thoroughly but miss
several categories of real user scenarios:

1. **No tests for the assigned-ports `flock` critical section.** The
   helper `__xcind-with-assigned-lock` has two branches (flock present /
   missing); neither is exercised. No concurrent-writer test exists at
   all, so we can't safely refactor `xcind-assigned-lib.bash` (package
   #06 depends on this).
2. **`__xcind-assigned-port-available` has three probe fallbacks** (ss,
   netstat, `/dev/tcp`) and the real branches are all dead to the test
   suite. Existing tests stub the function out.
3. **`bin/xcind-workspace` (613 lines) has almost no CLI-level tests.**
   The workspace tests in `test-xcind.sh` exercise
   `__xcind-discover-workspace` but not the `xcind-workspace init`,
   `status`, or subcommand-parsing branches. The one place the CLI runs
   is via subshells inside integration-style tests.
4. **Hook failure modes are untested.** Specifically: a hook exiting
   non-zero, a hook emitting malformed `-f` lines, a hook referencing a
   file outside `$XCIND_GENERATED_DIR`. The pipeline's validation code
   exists (`__xcind-validate-hook-output` at
   `lib/xcind/xcind-lib.bash:1165`) but is only exercised by the happy path.
5. **yq-missing paths silently skip.** When `yq` isn't on PATH, several
   tests `continue` or skip blocks entirely. `make test` passes green on
   a box with no yq, which contradicts the "yq is required" policy. Make
   the skips loud, or run the default-registered hooks as a matrix
   (with yq / without yq) and assert the soft-skip vs hard-fail matrix.

Each of these is a real bug-preventer, not "more coverage for its own
sake." Addressing them makes future refactors (especially package #06)
safe.

## Evidence

### 1. No flock / concurrency tests

- **`lib/xcind/xcind-assigned-lib.bash:51-61`** — `__xcind-with-assigned-lock`.
- **`test/test-xcind-proxy.sh`** — `grep -n flock` yields zero hits inside
  tests; the function's behavior is implicit.
- **`grep -n 'wait\s*$'` / `grep -n ' & '`** across the test suite yield
  zero background-process patterns.

### 2. Port-probe fallbacks untested

- **`lib/xcind/xcind-assigned-lib.bash:69-99`** — three branches: `ss`,
  `netstat`, `/dev/tcp`.
- Existing tests either rely on whatever the dev box has, or stub the
  function via `__xcind-assigned-port-available() { return 0; }` override.

### 3. xcind-workspace CLI untested

- `bin/xcind-workspace` subcommands: `init`, `status`, flag parsing for
  `--name`, `--proxy-domain`, `--json`, error cases for unknown flags.
- `test/test-xcind.sh` has workspace tests starting around line 480 but
  they call `__xcind-discover-workspace` and related functions directly,
  not `"$XCIND_ROOT/bin/xcind-workspace"`.

### 4. Hook failure modes untested

- **`lib/xcind/xcind-lib.bash:1165-1179`** — `__xcind-validate-hook-output`
  checks that any `-f PATH` line references a file that exists. Triggered
  on cache-hit validation failure, which recurses back into a fresh hook
  run. This whole branch is untested.
- A hook that fails with non-zero exit should abort the pipeline (see
  `xcind-lib.bash:1239-1243`). Untested.

### 5. yq-missing silent skips

- **`test/test-xcind.sh:1739,1779,1817,1853,1895,1929,2005`** — eight
  blocks that contain `command -v yq >/dev/null 2>&1 || { echo "  (skip:
  yq not installed)"; continue; }` or similar. On a box without yq,
  `make test` will print skip notices and still exit green.
- With `e9319cd` promoting yq to required, this is a policy
  contradiction. Either fail the test suite when yq is missing, or
  treat the skip as a real "test not applicable" with a clear summary.

---

## Proposed fix

This package is large; split into **five sub-packages** that can each ship
as a separate commit. Do them in the order listed.

### 3a — Concurrent flock tests

New test section in `test-xcind-proxy.sh` (or a new file
`test/test-xcind-assigned.sh` if the proxy file gets unwieldy). Use a
mock HOME and the existing `assigned-ports.tsv` state file.

```bash
# ======================================================================
echo ""
echo "=== Test: __xcind-with-assigned-lock serializes concurrent writers ==="

ASSIGNED_HOME=$(mktemp_d)
_orig_HOME="$HOME"
export HOME="$ASSIGNED_HOME"
XCIND_ASSIGNED_DIR="${HOME}/.config/xcind"
XCIND_ASSIGNED_PORTS_FILE="${XCIND_ASSIGNED_DIR}/assigned-ports.tsv"
XCIND_ASSIGNED_PORTS_LOCK="${XCIND_ASSIGNED_DIR}/assigned-ports.lock"
__xcind-assigned-ensure-state-file

# Spawn N concurrent upserts for distinct (app_path, export) pairs.
# Without the lock, the rewriting TSV read loops trample each other
# and some rows are lost.
N=10
for i in $(seq 1 $N); do
  (
    __xcind-with-assigned-lock __xcind-assigned-upsert \
      "$((3300 + i))" "app$i" "web" "80" "/tmp/app$i"
  ) &
done
wait

# All N rows should be present
row_count=$(grep -cv '^#' "$XCIND_ASSIGNED_PORTS_FILE" || true)
assert_eq "all $N concurrent upserts persisted" "$N" "$row_count"

# No duplicate ports
unique_ports=$(awk -F'\t' '!/^#/ && NF>0 {print $1}' \
  "$XCIND_ASSIGNED_PORTS_FILE" | sort -u | wc -l | tr -d ' ')
assert_eq "no duplicate ports" "$N" "$unique_ports"

export HOME="$_orig_HOME"
unset _orig_HOME
```

**Notes for the implementer:**

- On a box without `flock`, the fallback runs unlocked and this test will
  flake. That's the point — add a second variant that sets
  `PATH="${PATH_WITHOUT_FLOCK}"` and asserts that the test *may* leak a
  row, documenting that the unlocked fallback is best-effort.
- Actually: a better approach is to make the unlocked fallback test
  deterministic by hiding `flock` from PATH via a mock that `exit 127`s,
  and then confirming the function still produces *valid* TSV (no partial
  rows) even if some rows are lost. We care about consistency, not
  correctness, in the unlocked case.
- 10 concurrent processes is plenty; don't crank this up or CI will flake
  on slow runners.

### 3b — Port-probe fallback tests

Three tests, one per branch. Use `PATH` narrowing to force the fallback
chain.

```bash
# Save real PATH
_orig_PATH="$PATH"

# Force /dev/tcp fallback: hide ss and netstat
MOCK_BIN=$(mktemp_d)
export PATH="$MOCK_BIN:$_orig_PATH"
# Create no-op stubs that `exit 127` when called
for tool in ss netstat; do
  cat >"$MOCK_BIN/$tool" <<'MOCKEOF'
#!/bin/sh
exit 127
MOCKEOF
  chmod +x "$MOCK_BIN/$tool"
done

# Now __xcind-assigned-port-available should fall through to /dev/tcp
# Pick a port we know is free
if __xcind-assigned-port-available 65432; then
  assert_eq "/dev/tcp: free port detected" "0" "0"
else
  assert_eq "/dev/tcp: free port detected" "0" "1"
fi

export PATH="$_orig_PATH"
```

Write similar variants for the `ss`-preferred and `netstat`-fallback
branches. Don't over-engineer — three short test blocks cover all three
probe branches.

### 3c — xcind-workspace CLI tests

New section in `test-xcind.sh`. Run the real CLI against a mock HOME +
mock docker.

```bash
# ======================================================================
echo ""
echo "=== Test: xcind-workspace init CLI ==="

WS_DIR=$(mktemp_d)

# Plain init creates .xcind.sh with XCIND_IS_WORKSPACE=1
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_DIR" >/dev/null
assert_file_exists "workspace .xcind.sh created" "$WS_DIR/.xcind.sh"
content=$(<"$WS_DIR/.xcind.sh")
assert_contains "workspace marker set" "XCIND_IS_WORKSPACE=1" "$content"

# --name flag
WS_NAMED=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_NAMED" --name "myteam" >/dev/null
content=$(<"$WS_NAMED/.xcind.sh")
assert_contains "name flag persisted" 'XCIND_WORKSPACE="myteam"' "$content"

# --proxy-domain flag
WS_PROXY=$(mktemp_d)
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_PROXY" --proxy-domain "test.local" >/dev/null
content=$(<"$WS_PROXY/.xcind.sh")
assert_contains "proxy domain persisted" 'XCIND_PROXY_DOMAIN="test.local"' "$content"

# Idempotent init
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_NAMED" >/dev/null
content_after=$(<"$WS_NAMED/.xcind.sh")
assert_eq "idempotent init preserves config" "$content" "$content_after"

# Init on a directory that already has a non-workspace .xcind.sh fails
APP_DIR=$(mktemp_d)
echo '# app config' >"$APP_DIR/.xcind.sh"
rc=0
"$XCIND_ROOT/bin/xcind-workspace" init "$APP_DIR" 2>/dev/null || rc=$?
assert_eq "init over existing app fails" "1" "$rc"

# Unknown flag
rc=0
"$XCIND_ROOT/bin/xcind-workspace" init "$WS_DIR" --bogus 2>/dev/null || rc=$?
assert_eq "unknown flag fails" "1" "$rc"
```

Similar block for `status` — test with and without `--json`, with a
workspace + app inside it, with no apps, and from inside vs outside the
workspace tree. The proxy test file already demonstrates the mock-HOME +
mock-docker pattern (`test/test-xcind-proxy.sh:62-80`).

### 3d — Hook failure mode tests

```bash
# ======================================================================
echo ""
echo "=== Test: hook failure aborts the pipeline ==="

HOOK_FAIL_APP=$(mktemp_d)
echo 'XCIND_COMPOSE_FILES=("compose.yaml")' >"$HOOK_FAIL_APP/.xcind.sh"
cat >"$HOOK_FAIL_APP/compose.yaml" <<'YAMLEOF'
services:
  web:
    image: nginx
YAMLEOF

# Inject a failing hook
__test_failing_hook() {
  echo "Error: intentional test failure" >&2
  return 7
}
XCIND_HOOKS_GENERATE=("__test_failing_hook")

reset_xcind_state
XCIND_APP_ROOT="$HOOK_FAIL_APP"

rc=0
__xcind-prepare-app 2>/dev/null || rc=$?
assert_eq "failing hook aborts pipeline" "7" "$rc"

unset -f __test_failing_hook
XCIND_HOOKS_GENERATE=("xcind-naming-hook" "xcind-app-hook" "xcind-app-env-hook" "xcind-host-gateway-hook" "xcind-proxy-hook" "xcind-assigned-hook" "xcind-workspace-hook")
```

Add similar tests for: hook emits `-f /nonexistent/path` (should trigger
validation rebuild on cache hit), hook emits malformed non-space line
(should not crash), hook writes a compose file that `docker compose
config` rejects.

### 3e — yq-missing policy enforcement

Decide between two options:

**Option A** (recommended): **fail the test suite if yq is missing.** Add
a top-of-file guard:

```bash
if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required to run the xcind test suite." >&2
  echo "Install yq (e.g., 'apt-get install yq' or 'nix-shell -p yq-go')." >&2
  exit 1
fi
```

Then delete all the `|| { echo "(skip: yq)"; continue; }` guards from the
existing tests. Net simpler.

**Option B:** **run the default-registered hooks as an explicit matrix.**
For each hook, assert its behavior both with yq present and with yq
hidden (via PATH narrowing). This gives stronger coverage of the
soft-skip vs hard-fail policy but adds ~14 new test blocks.

Option A is the right first step. If later we want to test the
yq-missing branches specifically, do that in a targeted new test section,
not by silently skipping.

---

## Acceptance criteria

Per sub-package:

- [ ] **3a:** At least one test proves that 10 concurrent `upsert`s
  produce 10 distinct rows. Test passes reliably on CI (run it 5× in a
  row to confirm no flakes).
- [ ] **3b:** Three new tests, one per probe branch, each confirming the
  branch correctly reports a free port and a busy port.
- [ ] **3c:** At least 10 new assertions covering `xcind-workspace init`
  and `xcind-workspace status` CLI paths, using the real `bin/` script
  via subshell.
- [ ] **3d:** Four new test blocks covering hook failure modes (exit
  non-zero, emit bad `-f`, emit malformed line, produce invalid YAML).
- [ ] **3e:** `make test` fails loudly on a box without yq (Option A) OR
  the yq-missing matrix tests pass (Option B).
- [ ] `make check` passes.
- [ ] Total test count grows by at least 30 assertions.

## Risk / rollback

- **Risk:** concurrent-flock tests are prone to CI flakes. Run them 5×
  before committing; if flaky, lower N or add a short sleep between
  spawns.
- **Risk:** port-probe tests rely on `65432` being free. If CI happens to
  have something listening there, test fails. Use a port from the
  dynamic range and grep for it via `ss` first as a sanity check.
- **Rollback:** tests only; revert is clean.

## Scope estimate

6–8 hours total, split as:
- 3a: 2 hours (trickiest; get concurrency right)
- 3b: 1 hour (three nearly-identical tests)
- 3c: 1.5 hours (~15 assertions)
- 3d: 1.5 hours (test fixture setup + 4 assertions)
- 3e: 30 min (Option A) or 2 hours (Option B)

## Out of scope

- **Docker integration tests** that actually run containers. This package
  uses mock docker stubs only.
- **Coverage metrics.** We're closing known gaps, not chasing a number.
- **Rewriting existing tests** beyond the silent-skip cleanup in 3e. If
  #02 has shipped, prefer the new helpers; otherwise leave older tests
  alone.
