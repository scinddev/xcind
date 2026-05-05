# Handoff: assigned hook is skipped on cache hit

**Status**: open
**Surfaced**: 2026-04-16, during review of the assigned-ports "port isn't sticking" bug

## Symptom

When `__xcind-prepare-app` finds an existing `XCIND_GENERATED_DIR`, it
replays persisted hook output instead of re-running hooks. The assigned
hook is treated the same as every other GENERATE hook, so it does not run.
If the TSV at `~/.local/state/xcind/proxy/assigned-ports.tsv` is mutated
outside of xcind between runs (user edits it, another app reassigns a
colliding port, a `prune` removes entries, etc.), `compose.assigned.yaml`
under `.xcind/generated/<sha>/` stays at whatever the hook wrote the last
time the SHA was missed. The overlay and the TSV can disagree until
something bumps the SHA.

## Location

- `lib/xcind/xcind-lib.bash:1283-1347` — `__xcind-run-hooks`, cache-hit
  branch at lines 1290-1311.
- `lib/xcind/xcind-lib.bash:942` — `__xcind-compute-sha`; the TSV is not
  part of the SHA input, so external TSV mutation never invalidates the
  generated-dir cache.
- `lib/xcind/xcind-assigned-lib.bash:424-538` — the hook whose output is
  cached (produces `compose.assigned.yaml` + a `-f <path>` line).

## Root cause

The cache-key-then-replay design assumes every GENERATE hook is a pure
function of the SHA inputs. The assigned hook breaks that assumption: it
depends on live state (port availability probe, existing TSV contents) that
isn't part of the SHA. Caching its output is unsound — any time the hidden
inputs diverge from what they were at cache-write time, the replayed
overlay is wrong.

The other GENERATE hooks (naming, app, app-env, host-gateway, proxy,
workspace) are safe to cache because their outputs do only depend on SHA
inputs.

## Proposed fix (sketch)

Mark the assigned hook as "always run." One shape:

- A new `XCIND_HOOKS_ALWAYS` array (or a flag on the hook registration) for
  hooks whose outputs can't be cached.
- `__xcind-run-hooks` executes `XCIND_HOOKS_ALWAYS` hooks every time and
  treats cache-hit replay as applying only to `XCIND_HOOKS_GENERATE`.
- Move `xcind-assigned-hook` from `XCIND_HOOKS_GENERATE` to the new
  always-run list.

Alternative: include the TSV mtime/content hash in `__xcind-compute-sha`.
Cheaper mechanically but couples every hook's cache lifetime to an
unrelated state file, and mutates the SHA more often than needed.

## Why deferred

The user's reported port-flap symptom is explained entirely by the
self-eviction bug (see `assigned-ports-self-eviction` fix, primary change
in this PR). Shipping the two fixes together would have expanded the
diff, changed hook-runner semantics for all hooks at once, and required
updating cache-behavior tests that aren't about the flap. Cleaner to land
as a follow-up once the self-eviction change has stabilized.

## Acceptance criteria

- Editing or deleting the TSV between two `xcind-compose up` invocations
  without touching any SHA input causes `compose.assigned.yaml` to
  regenerate on the second run.
- Pure GENERATE hooks (naming, app, etc.) still skip on cache hit —
  performance regression is bounded to the assigned hook.
- Regression test in `test/test-xcind-proxy.sh` covers the
  "mutate-TSV-then-rerun-with-stable-SHA" path.
