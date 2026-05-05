# Handoff: cached config.json reflects pre-hook TSV state

**Status**: open
**Surfaced**: 2026-04-16, during review of the assigned-ports "port isn't sticking" bug

## Symptom

Anything that reads `.xcind/cache/<sha>/config.json` directly — bypassing
`xcind-config --json` — can see an `assignedExports` block that doesn't
match the current TSV or the current `compose.assigned.yaml`. The CLI is
unaffected because `bin/xcind-config` re-resolves the JSON after hooks
have run; only direct cache consumers (for example the JetBrains plugin,
or any tool that greps the cache for speed) are affected.

## Location

- `lib/xcind/xcind-lib.bash:1050-1069` — `__xcind-populate-cache` writes
  `resolved-config.yaml` and `config.json`.
- `lib/xcind/xcind-lib.bash:495-496` — call order inside
  `__xcind-prepare-app`: `__xcind-populate-cache` runs, then
  `__xcind-run-hooks` runs.
- `lib/xcind/xcind-lib.bash:612-692` — `__xcind-resolve-json`, used by
  both the cache writer at line 1067 and the CLI path at
  `bin/xcind-config:316`.
- `lib/xcind/xcind-assigned-lib.bash:489` — where the TSV is upserted
  with the freshly-allocated port, inside the assigned hook.

## Root cause

Ordering. `__xcind-populate-cache` writes `config.json` by calling
`__xcind-resolve-json`, which calls `__xcind-assigned-json-for-app`, which
reads the TSV. That write happens *before* `__xcind-run-hooks` runs the
assigned hook that updates the TSV. So on a cache miss:

1. populate-cache reads the TSV (old/empty for this run's allocation).
2. populate-cache writes `config.json` with that stale `assignedExports`.
3. run-hooks executes the assigned hook, which upserts the TSV.
4. `config.json` is never rewritten on this invocation.

The CLI avoids this by re-calling `__xcind-resolve-json` after prepare-app
finishes (at `bin/xcind-config:316`), producing correct output for
end-users. The cache file itself stays stale until the *next* prepare-app
writes a fresh one (which, on a cache hit, happens at step 2 above using
the now-current TSV — so the staleness self-heals one run later).

## Proposed fix (sketch)

Two reasonable options:

1. Move the `config.json` write out of `__xcind-populate-cache` to a new
   step that runs after `__xcind-run-hooks`. `resolved-config.yaml` still
   belongs in populate-cache because the assigned hook reads it (line
   432). Only the JSON write needs to move.
2. Rewrite `config.json` at the end of prepare-app unconditionally, after
   hooks. Simpler; negligible cost (jq is cheap relative to
   `docker compose config`).

Option 2 is the smaller change.

## Why deferred

Doesn't cause the user's reported port flap — that's entirely the
self-eviction bug. The CLI output is already correct. This handoff only
matters once we know a cache consumer relies on `config.json` being
fresh-on-write. Worth fixing before external integrations land.

## Acceptance criteria

- After `__xcind-prepare-app` returns on a cache miss,
  `.xcind/cache/<sha>/config.json` contains the post-hook TSV state.
- `bin/xcind-config --json` output is unchanged (it was already correct).
- Regression test reads the cache file directly after a cache-miss
  invocation and asserts the `assignedExports.<name>.host_port` matches
  the TSV row just written.
