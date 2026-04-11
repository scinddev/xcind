# 06 — TSV read-loop refactor in `xcind-assigned-lib.bash`

**Scope:** Medium (touches 4–5 functions in one file)
**Risk:** Medium — refactors hot-path code inside a `flock` critical section
**Depends on:** #03 (concurrent-flock tests must exist before refactoring)
**Blocks:** nothing
**Conflicts with:** nothing (single-file refactor)

---

## Why this is last

This refactor is a maintenance win, not a bug fix. The existing code
works correctly under the test coverage we have. But five functions
share the same TSV read-loop boilerplate, and the repetition makes
future schema changes (adding a column, changing the separator, etc.)
a five-site change with five chances to miss one.

**Do not do this refactor until package #03 has landed the concurrent
`flock` tests.** The current test suite exercises these functions via
the happy path only; without concurrency tests, a subtle bug in the
refactor (wrong quoting inside a predicate callback, accidentally
swapped fields, dropped header line) won't surface until a user trips
over it in production.

## Problem

**`lib/xcind/xcind-assigned-lib.bash`** has five functions that all
iterate the TSV state file with the same boilerplate:

```bash
while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
  [[ -z $L_port ]] && continue
  [[ ${L_port:0:1} == "#" ]] && continue
  # ... function-specific logic ...
done <"$XCIND_ASSIGNED_PORTS_FILE"
```

Occurrences (post-`368db82` line numbers):

| Function | Line | What it does |
|----------|------|--------------|
| `__xcind-assigned-lookup` | 111 | Find matching (app_path, export); print port |
| `__xcind-assigned-upsert` | 135 | Rewrite, dropping old matches, appending new row |
| `__xcind-assigned-remove-entry` | 163 | Rewrite, dropping matching (app_path, export) |
| `__xcind-assigned-remove-port` | 187 | Rewrite, dropping matching port; set found flag |
| `__xcind-assigned-prune` | 212 | Rewrite, dropping rows with missing app_path |
| `__xcind-assigned-json-for-app` | 442 | Iterate for JSON output |

Plus **`bin/xcind-proxy:237`** (`__xcind-proxy-status-assigned-text`)
and **`bin/xcind-proxy:262`** (`__xcind-proxy-status-assigned-json`)
use the same pattern for status display.

The four **mutating** functions (`upsert`, `remove-entry`, `remove-port`,
`prune`) additionally share a "rewrite-via-tmp" pattern:

```bash
local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"
while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
  [[ -z $L_port ]] && continue
  [[ ${L_port:0:1} == "#" ]] && continue
  # function-specific decision: skip or keep
  if "$should_keep"; then
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
  fi
done <"$XCIND_ASSIGNED_PORTS_FILE"
mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
```

If we add a 7th column to the TSV, we'd need to:
- Update `XCIND_ASSIGNED_PORTS_HEADER`
- Add `L_newfield` to 7 `read -r` calls
- Add `%s\t` to 4 `printf` format strings
- Update `__xcind-assigned-upsert`'s signature and all its callers
- Update `__xcind-assigned-json-for-app`'s jq construction
- Update both `bin/xcind-proxy` display functions

That's a lot of coordinated edits for one schema change. Extracting a
helper reduces that to 2–3 sites.

## Design decision required

There are **two materially different refactor approaches**. Pick one
and commit to it before starting.

### Option A — Iterator + file-scope predicate callbacks (my recommendation)

Extract two helpers: one for read-only iteration, one for mutating
rewrites. Each takes a predicate function name as a callback.

```bash
# Iterate data rows, invoking a callback with the 6 fields.
# Callback can set variables in the caller's scope.
# Returns whatever the callback returns on non-zero; returns 0 on
# normal completion.
__xcind-assigned-iter() {
  local callback="$1"
  shift
  [[ -f $XCIND_ASSIGNED_PORTS_FILE ]] || return 0
  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    "$callback" "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" "$@" || return $?
  done <"$XCIND_ASSIGNED_PORTS_FILE"
  return 0
}

# Rewrite the assigned-ports file, keeping only rows for which the
# predicate returns 0. Callers must hold the assigned-ports lock.
__xcind-assigned-rewrite() {
  local predicate="$1"
  shift
  __xcind-assigned-ensure-state-file

  local tmp="${XCIND_ASSIGNED_PORTS_FILE}.tmp"
  # Clean up tmp on any exit path inside this function.
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN
  printf '%s\n' "$XCIND_ASSIGNED_PORTS_HEADER" >"$tmp"

  local L_port L_app L_xport L_cport L_path L_ts
  while IFS=$'\t' read -r L_port L_app L_xport L_cport L_path L_ts; do
    [[ -z $L_port ]] && continue
    [[ ${L_port:0:1} == "#" ]] && continue
    if "$predicate" "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" "$@"; then
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$L_port" "$L_app" "$L_xport" "$L_cport" "$L_path" "$L_ts" >>"$tmp"
    fi
  done <"$XCIND_ASSIGNED_PORTS_FILE"

  mv -- "$tmp" "$XCIND_ASSIGNED_PORTS_FILE"
  # Clear the trap since mv succeeded
  trap - RETURN
}
```

Then each mutating function becomes tiny:

```bash
# Remove any entry matching (app_path, export). No-op if not found.
__xcind-assigned-remove-entry() {
  local target_path="$1" target_xport="$2"
  __xcind-assigned-rewrite __xcind-assigned-keep-not-entry \
    "$target_path" "$target_xport"
}

__xcind-assigned-keep-not-entry() {
  local L_port="$1" L_app="$2" L_xport="$3" L_cport="$4" L_path="$5" L_ts="$6"
  local target_path="$7" target_xport="$8"
  [[ $L_path == "$target_path" && $L_xport == "$target_xport" ]] && return 1
  return 0
}
```

**Pros:**
- Every mutation function shrinks from ~15 lines to ~4.
- Schema changes touch exactly 3 sites: header constant, one `read -r`,
  one `printf`.
- The read-only iter sites (`json-for-app`, the two proxy status
  functions) can share `__xcind-assigned-iter`.
- Predicates are named, testable, shellcheck-able functions.

**Cons:**
- Function-pointer callbacks are unusual in Bash; maintainers reading
  the refactored code for the first time will need to trace the
  predicate.
- Passing extra args through the callback is a little awkward
  (`"$@"` after the fixed 6 fields).
- State that needs to escape the callback (like `remove-port`'s
  "found" flag) has to use a global variable or the callback's return
  code alone.

### Option B — In-place improvement, no extraction

Leave the five functions as-is but fix the narrower problem: centralize
the "skip blank and comment lines" preamble and make the TSV field list
a single source of truth as a sourced constant.

```bash
# TSV field count for assigned-ports state file. Update if the schema
# changes; the read-loop destructurings reference this indirectly.
XCIND_ASSIGNED_TSV_FIELDS=6

# Macro-ish convenience: skip header/blank lines at the top of every
# read loop. Call immediately after the read inside the loop body:
#   while IFS=$'\t' read -r L_port L_app ...; do
#     __xcind-assigned-skip-header "$L_port" && continue
#     ...
#   done
__xcind-assigned-skip-header() {
  local first="$1"
  [[ -z $first ]] && return 0
  [[ ${first:0:1} == "#" ]] && return 0
  return 1
}
```

**Pros:**
- No callback weirdness.
- Each function is still immediately readable.
- Schema changes are still multi-site, but the field count is
  centralized.

**Cons:**
- Doesn't actually reduce duplication much.
- The "macro" pattern (`cmd && continue`) is subtle and easy to get
  wrong (`&&` inside a while loop under `set -e` is a footgun surface).

### Recommendation

**Option A, if #03 has landed and you're confident in the concurrent
tests.** The function-pointer pattern is unusual but it's a documented
Bash idiom (e.g., `trap` takes a command name; `xargs` does similar).
The benefit at schema-change time is substantial.

**Option B, if you want the smallest possible change or you're uneasy
about callbacks.** It's still an improvement over the status quo and
costs an hour.

---

## Implementation steps (assuming Option A)

1. **Prerequisite check.** Confirm `test/test-xcind-proxy.sh` has the
   concurrent-flock tests from package #03. If not, stop and complete
   #03 first.

2. **Add the two helpers** near the top of `xcind-assigned-lib.bash`,
   after the constants section.

3. **Convert `__xcind-assigned-lookup`** first — it's the simplest
   (read-only, single-hit). Use it to prove the iterator pattern works.

   ```bash
   __xcind-assigned-lookup() {
     local target_path="$1" target_xport="$2"
     # Global because the callback can't easily set a return value
     __xcind_assigned_lookup_result=""
     if __xcind-assigned-iter __xcind-assigned-lookup-match \
          "$target_path" "$target_xport"; then
       return 1  # not found
     fi
     printf '%s\n' "$__xcind_assigned_lookup_result"
     return 0
   }

   __xcind-assigned-lookup-match() {
     local L_port="$1" L_app="$2" L_xport="$3" L_cport="$4" L_path="$5" L_ts="$6"
     local target_path="$7" target_xport="$8"
     if [[ $L_path == "$target_path" && $L_xport == "$target_xport" ]]; then
       __xcind_assigned_lookup_result="$L_port"
       return 1  # "found" — stop iteration
     fi
     return 0  # continue
   }
   ```

   Note the trick: the iterator continues while the callback returns
   0, and the caller treats iter's 0 return as "not found" and 1 as
   "found". Document this clearly in the iter helper's header.

   Run `make test` — the lookup tests should pass without modification.

4. **Convert `__xcind-assigned-remove-entry`** next — it's a simple
   predicate-based rewrite. Use the pattern shown above under Option A.

5. **Convert `__xcind-assigned-prune`** and
   **`__xcind-assigned-remove-port`**. These need to track side-channel
   state:
   - `prune` needs to count pruned rows.
   - `remove-port` needs a "found" flag for the return code.

   Use a module-level variable for each:

   ```bash
   __xcind-assigned-prune() {
     __xcind_assigned_prune_count=0
     __xcind-assigned-rewrite __xcind-assigned-keep-existing-path
     printf '%s\n' "$__xcind_assigned_prune_count"
   }

   __xcind-assigned-keep-existing-path() {
     local L_port="$1" L_app="$2" L_xport="$3" L_cport="$4" L_path="$5" L_ts="$6"
     if [[ ! -d $L_path ]]; then
       __xcind_assigned_prune_count=$((__xcind_assigned_prune_count + 1))
       return 1  # drop
     fi
     return 0  # keep
   }
   ```

6. **Convert `__xcind-assigned-upsert`** last. It's the trickiest
   because it combines a rewrite (drop old matches, drop same-port
   collisions) AND an append of the new row. Option: split into two
   steps inside the function:

   ```bash
   __xcind-assigned-upsert() {
     local port="$1" app="$2" xport="$3" cport="$4" app_path="$5"
     __xcind-assigned-ensure-state-file
     local ts
     ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

     # Step 1: drop any existing row with this identity or this port.
     __xcind_assigned_upsert_path="$app_path"
     __xcind_assigned_upsert_xport="$xport"
     __xcind_assigned_upsert_port="$port"
     __xcind-assigned-rewrite __xcind-assigned-upsert-keep

     # Step 2: append the new row.
     printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
       "$port" "$app" "$xport" "$cport" "$app_path" "$ts" \
       >>"$XCIND_ASSIGNED_PORTS_FILE"

     unset __xcind_assigned_upsert_path __xcind_assigned_upsert_xport \
           __xcind_assigned_upsert_port
   }

   __xcind-assigned-upsert-keep() {
     local L_port="$1" L_app="$2" L_xport="$3" L_cport="$4" L_path="$5" L_ts="$6"
     [[ $L_path == "$__xcind_assigned_upsert_path" \
        && $L_xport == "$__xcind_assigned_upsert_xport" ]] && return 1
     [[ $L_port == "$__xcind_assigned_upsert_port" ]] && return 1
     return 0
   }
   ```

7. **Convert read-only iterators** (`__xcind-assigned-json-for-app` and
   the two `bin/xcind-proxy` status functions) to use
   `__xcind-assigned-iter`. These are easier because they don't need
   rewrite logic.

8. **Run `make check`** after each conversion. Do NOT batch all the
   conversions into one commit — you'll lose the ability to bisect if
   something breaks. Five commits, one per function, is fine.

9. **Run the concurrent-flock tests from #03 multiple times**
   (`make test` 5× in a row). The refactor should not introduce any
   new flakes.

## Acceptance criteria

- [ ] `__xcind-assigned-iter` and `__xcind-assigned-rewrite` exist and
  are documented.
- [ ] All five mutating/reading functions use the new helpers.
- [ ] The TSV read-loop boilerplate (`while IFS=$'\t' read ... [[ -z
  $L_port ]] && continue ...`) is gone from all five.
- [ ] `make check` passes.
- [ ] The concurrent-flock tests from #03 pass 5 runs in a row.
- [ ] `grep -c 'while IFS=$'\''\\t'\'' read -r L_port'
  lib/xcind/xcind-assigned-lib.bash` returns ≤ 2 (iter + rewrite).

## Risk / rollback

- **Risk:** medium. Function-pointer callbacks are easy to get wrong,
  especially when the callback needs to share state with the caller.
  The mitigation is the test suite from #03 — run it after every
  conversion.
- **Rollback:** each conversion is a separate commit; `git revert` the
  ones that break. This is why step 8 says not to batch.

## Scope estimate

3–4 hours, assuming #03 is complete:
- 30 min: add the two helpers with thorough header comments
- 20 min × 5: convert each function (lookup, remove-entry, prune,
  remove-port, upsert)
- 30 min: convert the three read-only iter sites
- 30 min: run concurrency tests 5×, adjust if needed, commit

## Out of scope

- **Do not change the TSV schema** while doing this refactor. Schema
  change + refactor = double the ways to break.
- **Do not port this to any other file.** `xcind-assigned-lib.bash` is
  the only place with this much TSV duplication. The three
  `bin/xcind-proxy` status read sites use the iter helper but the
  rewrite helper has no other callers.
- **Do not switch from the module-level global variables to
  `declare -g`** or associative arrays. `declare -g` doesn't exist in
  Bash 3.2; plain module-level variables work fine and the audit
  specifically targets Bash 3.2+.
- **Do not replace the TSV format with JSON or SQLite.** That's an ADR,
  not a refactor.
