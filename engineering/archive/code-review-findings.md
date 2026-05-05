# Code Review Findings

Date: 2026-04-01

Comprehensive review of `bin/` and `lib/xcind/` covering errors, missing error
handling, cross-script inconsistencies, and code quality issues.

---

## Priority 1 — Bugs / Missing Error Handling

### 1.1 `docker compose config` failure not checked

**File:** `lib/xcind/xcind-lib.bash:870`
**Function:** `__xcind-populate-cache`

```bash
docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" config >"$XCIND_CACHE_DIR/resolved-config.yaml"
```

**Problem:** If `docker compose config` fails (bad compose file, docker not
running, etc.), a truncated or empty file is written to the cache. Downstream
consumers — yq queries in proxy export resolution, cache hash computation — will
silently operate on garbage data.

**Fix:** Add `|| return 1` so the failure propagates. Callers already handle
non-zero returns from the resolve pipeline.

---

### 1.2 `docker compose up -d` failure not checked in force path

**File:** `bin/xcind-proxy:57`
**Function:** `__xcind-proxy-up` (the `--force` branch)

```bash
docker compose -f "$XCIND_PROXY_COMPOSE" up -d
```

**Problem:** In the `--force` code path, `docker compose up -d` failure is
silently ignored. The non-force path delegates to `__xcind-proxy-ensure-running`
which does check for errors (lines 157-161), making this an inconsistency.

**Fix:** Capture the exit code and return it, or call a shared helper that
already handles the error. Match the pattern used by `__xcind-proxy-ensure-running`.

---

## Priority 2 — Cross-Script Inconsistencies

### 2.1 Version flag mismatch between xcind-compose and xcind-proxy

**Files:**
- `bin/xcind-compose:38` — uses `--xcind-version`
- `bin/xcind-proxy:31` — uses `--version` / `-V`

**Problem:** Users expect a consistent CLI interface across the xcind toolset.
`xcind-config` also uses `--version`.

**Fix:** Standardize on `--version` / `-V` for all three scripts. If
`--xcind-version` must be preserved for backwards compatibility in
`xcind-compose`, keep it as a hidden alias but add `--version` / `-V` as the
primary flags.

---

### 2.2 xcind-compose has no `--help` flag

**File:** `bin/xcind-compose`

**Problem:** Both `xcind-config` and `xcind-proxy` have `--help` / `-h` with
usage output. `xcind-compose` has no help interface — users must read source to
discover options like `--xcind-version`.

**Fix:** Add a minimal `--help` / `-h` handler that prints usage, similar to the
pattern in `xcind-proxy`.

---

### 2.3 Inconsistent boolean check pattern in xcind-config

**File:** `bin/xcind-config:195-209`

Lines 195-204 use `[[ $var == true ]]` for boolean checks, but line 207 uses
`[[ -n $_do_completion ]]`. This works because `$_do_completion` stores a shell
name (`bash`/`zsh`) rather than `true`, but it breaks the visual pattern.

**Fix:** Consider storing a separate `_do_completion=true` boolean and a
`_completion_shell` variable, so all the mutual-exclusion checks use the same
`== true` pattern. Alternatively, add a comment explaining why this one differs.

---

### 2.4 Mixed conditional bracket style in xcind-proxy

**File:** `bin/xcind-proxy:51`

```bash
if [ "$force" = true ]; then
```

The rest of the script uses `[[ ]]`. This is a minor style inconsistency.

**Fix:** Change to `[[ "$force" == true ]]` for consistency.

---

## Priority 3 — Code Quality

### 3.1 `eval echo` on config file patterns

**File:** `lib/xcind/xcind-lib.bash:278`
**Function:** `__xcind-resolve-compose-files`

```bash
expanded=$(eval echo "$pattern" 2>/dev/null) || continue
```

Used to expand variables like `${APP_ENV}` in compose file path patterns sourced
from `.xcind.sh`. Since `.xcind.sh` is user-controlled config that is already
`source`d directly, the eval does not widen the attack surface — but it is worth
noting for future hardening if the pattern source ever changes.

**Fix (optional):** Replace with `envsubst` or explicit `${!var}` indirect
expansion if the set of variables to expand is bounded.

---

### 3.2 `$*` in preview output

**File:** `lib/xcind/xcind-lib.bash:621`
**Function:** `__xcind-preview-command`

```bash
echo "docker compose ${XCIND_DOCKER_COMPOSE_OPTS[*]} $*"
```

`$*` collapses all arguments into a single string. For display/preview purposes
this is cosmetic, but using `"$@"` would more accurately represent how arguments
are passed to `docker compose`.

**Fix:** Change to `printf 'docker compose %s %s\n' "${XCIND_DOCKER_COMPOSE_OPTS[*]}" "$*"`
or accept the cosmetic limitation with a comment.

---

### 3.3 Intentional unquoted array append from hook output

**File:** `lib/xcind/xcind-lib.bash:1040,1061`

```bash
# shellcheck disable=SC2206
XCIND_DOCKER_COMPOSE_OPTS+=($output)
```

Word splitting is intentional here — hook output is expected to be
space-separated compose flags. The `shellcheck disable` confirms this is
deliberate. However, it means hooks cannot return flags containing spaces.

**Fix (optional):** If hooks ever need to return flags with spaces, switch to
newline-delimited output with `readarray`. Low priority unless a hook requires it.

---

### 3.4 Nested function redefined on each call

**File:** `lib/xcind/xcind-lib.bash:488-494`
**Function:** `__xcind-resolve-json`

`__to_json_array()` is defined inside `__xcind-resolve-json`, so bash re-creates
the function definition on every invocation. Minor performance cost.

**Fix:** Move `__to_json_array` to file scope alongside other private helpers.

---

## Recommended Order of Work

| Order | Item | Effort | Impact |
|-------|------|--------|--------|
| 1 | 1.1 — Add error check to `docker compose config` | Small | Prevents silent cache corruption |
| 2 | 1.2 — Add error check to proxy force-up path | Small | Prevents silent proxy start failure |
| 3 | 2.1 — Standardize version flags | Small | User-facing consistency |
| 4 | 2.2 — Add `--help` to xcind-compose | Small | Discoverability |
| 5 | 2.4 — Fix bracket style in xcind-proxy | Trivial | Style consistency |
| 6 | 2.3 — Normalize boolean checks in xcind-config | Trivial | Readability |
| 7 | 3.4 — Hoist nested function | Trivial | Minor perf |
| 8 | 3.2 — Fix preview `$*` | Trivial | Cosmetic accuracy |
| 9 | 3.1 — Harden eval pattern | Medium | Future-proofing |
| 10 | 3.3 — Newline-delimited hook output | Medium | Only if needed |
