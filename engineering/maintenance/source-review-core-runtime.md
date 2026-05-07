# Source Review: Core runtime

**Date**: 2026-05-05
**Reviewer**: Codex
**Status**: Complete

## Scope

**Source files reviewed**:
- `lib/xcind/xcind-lib.bash`
- `lib/xcind/xcind-bootstrap.bash`

**Related engineering docs checked**:
- `engineering/maintenance/source-review-plan.md`
- `engineering/maintenance/source-review-templates.md`
- `engineering/DOCUMENTATION-GUIDE.md`
- `engineering/maintenance/sync.md`
- `engineering/maintenance/update.md`
- `engineering/specs/configuration-schemas.md`
- `engineering/specs/context-detection.md`
- `engineering/specs/application-lifecycle.md`
- `engineering/specs/workspace-lifecycle.md`
- `engineering/specs/hook-lifecycle.md`
- `engineering/specs/generated-override-files.md`
- `engineering/reference/configuration.md`
- `engineering/architecture/overview.md`
- `engineering/implementation/project-layout.md`
- `engineering/implementation/tech-stack.md`
- `engineering/implementation/handoffs/assigned-hook-cache-hit-skip.md`
- `engineering/implementation/handoffs/config-json-cache-staleness.md`

**Related tests/examples checked**:
- `test/test-xcind.sh`
- `test/test-xcind-proxy.sh`
- `engineering/behaviors/config-resolution/compose-file-defaults.feature`
- `engineering/behaviors/config-resolution/override-files.feature`
- `engineering/behaviors/config-resolution/project-naming.feature`
- `engineering/behaviors/config-resolution/variable-expansion.feature`
- `engineering/behaviors/config-resolution/xcind-sh-discovery.feature`
- `engineering/behaviors/workspace/workspace-mode.feature`
- `engineering/behaviors/workspace/self-declaration.feature`

## Review Notes

**Behavior summary**:
The core runtime resolves the application root, sources workspace/app/additional configuration, derives compose/env/override files, computes the generation SHA, populates cache artifacts, runs cached GENERATE hooks, and exposes JSON, preview, dependency-check, doctor, and wrapper-generation helpers. `xcind-bootstrap.bash` validates that a bin stub set `XCIND_ROOT` and then loads the shared runtime library.

**Key contracts verified**:
- App root detection skips workspace marker directories and honors explicit `XCIND_APP_ROOT`.
- Workspace detection sources the parent workspace config before app config, with late binding for self-declared workspace membership.
- `.xcind.override.sh` and declared additional config files are sourced and tracked for SHA invalidation when they exist.
- Compose/env file resolution expands variables, auto-includes `.override` siblings, skips missing files, and preserves paths with spaces in compose option arrays.
- GENERATE hook output is line-based, persisted under `.xcind/generated/{sha}/.hook-output-{hook}`, and replayed in hook registration order on cache hit.
- EXECUTE hooks run every invocation and are not part of the generation cache.

**Risks assessed**:
- Correctness and failure handling: Core error paths generally propagate failures, but generated-dir cache replay can skip hooks when persisted output is missing, and cache `config.json` is written before assigned-port hooks update state.
- Bash 3.2 portability: Code avoids associative arrays and uses Bash 3.2-compatible arrays/process substitution. `make lint` passed.
- Shell safety and maintainability: Path handling is mostly quoted. `eval` in pattern expansion is documented as a trust-boundary compromise, and the comments clearly scope the risk.
- State/cache/generated files: Highest risk area. The cache assumes generated directories are complete and assumes every GENERATE hook is a pure function of the SHA inputs; assigned-port generation violates that assumption.
- CLI/config contracts: Configuration defaults and JSON shape mostly match engineering reference. The generated-override cache-key docs are less complete than the implementation.
- Tests and behavior evidence: Existing tests cover override derivation, additional config sourcing, SHA invalidation for additional configs, hook replay order, stale `-f` file validation, execute-hook uncached behavior, and doctor output. Missing coverage remains for partial generated dirs, hook-list/code changes under stable app inputs, and direct cache `config.json` freshness.
- Engineering documentation drift: Confirmed stale stateless wording, incomplete generated-cache-key documentation, incomplete source-order docs, and stale implementation layout around bootstrap/library scope.

## Findings

| ID | Priority | Title | Source Location | Status |
|----|----------|-------|-----------------|--------|
| `CORE-RUNTIME-001` | `P1` | Partial generated directories are trusted as cache hits and can skip hooks | `lib/xcind/xcind-lib.bash:1852` | Closed |
| `CORE-RUNTIME-002` | `P1` | Assigned-port generation is cached despite depending on live state outside the SHA | `lib/xcind/xcind-lib.bash:1846` | Closed |
| `CORE-RUNTIME-003` | `P2` | Cache `config.json` is written before post-hook assigned-port state exists | `lib/xcind/xcind-lib.bash:589` | Closed |
| `CORE-RUNTIME-004` | `P3` | Bootstrap source comment still says there are four callers | `lib/xcind/xcind-bootstrap.bash:10` | Closed |

## Documentation Drift

| ID | Layer | Document | Summary | Status |
|----|-------|----------|---------|--------|
| `CORE-RUNTIME-DOC-001` | Specifications | `engineering/specs/configuration-schemas.md` | Stateless configuration section says there are no state files or registries, but assigned-port and workspace registry files are current behavior. | Closed |
| `CORE-RUNTIME-DOC-002` | Specifications | `engineering/specs/generated-override-files.md` | Cache-key summary omits several implemented inputs: env files, additional config files, `XCIND_TOOLS`, host-gateway settings, and detected host-gateway value. | Open |
| `CORE-RUNTIME-DOC-003` | Specifications | `engineering/specs/configuration-schemas.md` | Source-order section omits `.xcind.override.sh` siblings and `XCIND_ADDITIONAL_CONFIG_FILES` for workspace and app configs. | Open |
| `CORE-RUNTIME-DOC-004` | Implementation | `engineering/implementation/project-layout.md` | Runtime layout omits `xcind-bootstrap.bash` and newer installed libraries/hooks now sourced by `xcind-lib.bash`. | Open |

## Commands Run

```bash
rtk sed -n '1,240p' engineering/maintenance/source-review-plan.md
rtk sed -n '1,260p' engineering/maintenance/source-review-templates.md
rtk rg --files engineering docs lib/xcind
rtk git status --short
rtk sed -n '1,260p' /Users/beausimensen/.codex/RTK.md
rtk sed -n '1,260p' engineering/DOCUMENTATION-GUIDE.md
rtk sed -n '1,240p' engineering/maintenance/sync.md
rtk sed -n '1,240p' engineering/maintenance/update.md
rtk sed -n '1,260p' engineering/implementation/project-layout.md
rtk sed -n '1,220p' engineering/implementation/tech-stack.md
rtk sed -n '1,260p' lib/xcind/xcind-lib.bash
rtk sed -n '261,620p' lib/xcind/xcind-lib.bash
rtk sed -n '500,980p' lib/xcind/xcind-lib.bash
rtk sed -n '980,1460p' lib/xcind/xcind-lib.bash
rtk sed -n '1460,1930p' lib/xcind/xcind-lib.bash
rtk sed -n '1,260p' lib/xcind/xcind-bootstrap.bash
rtk nl -ba lib/xcind/xcind-lib.bash
rtk nl -ba lib/xcind/xcind-bootstrap.bash
rtk sed -n '1,260p' engineering/specs/configuration-schemas.md
rtk sed -n '1,280p' engineering/specs/context-detection.md
rtk sed -n '1,300p' engineering/specs/application-lifecycle.md
rtk sed -n '1,340p' engineering/specs/hook-lifecycle.md
rtk sed -n '1,340p' engineering/specs/generated-override-files.md
rtk sed -n '1,360p' engineering/reference/configuration.md
rtk sed -n '1,320p' engineering/specs/workspace-lifecycle.md
rtk sed -n '1,260p' engineering/architecture/overview.md
rtk sed -n '1,240p' engineering/implementation/handoffs/assigned-hook-cache-hit-skip.md
rtk sed -n '1,220p' engineering/implementation/handoffs/config-json-cache-staleness.md
rtk rg -n "run-hooks|hook-output|cache hit|config.json|assignedExports|partial|XCIND_HOOKS_GENERATE|XCIND_ADDITIONAL_CONFIG_FILES|override" test engineering/behaviors lib/xcind bin
rtk rg -n "xcind-bootstrap|__xcind-prepare-app|__xcind-run-execute-hooks|source .*xcind-bootstrap|XCIND_ROOT" bin test lib/xcind
rtk sed -n '880,1220p' test/test-xcind.sh
rtk sed -n '1220,1508p' test/test-xcind.sh
rtk sed -n '2620,2710p' test/test-xcind-proxy.sh
rtk make lint
```

**Result**: Passed.

`make check` was not run because this was a review-only pass with no implementation changes, and the request limited validation to non-mutating checks unless needed.

## Blockers or Follow-Up

- No blockers.
- The two existing handoff notes for assigned-hook cache replay and cache `config.json` staleness map directly to `CORE-RUNTIME-002` and `CORE-RUNTIME-003`.
- Implement findings in separate follow-up changes, then run `make check`.

## CORE-RUNTIME-001: Partial generated directories are trusted as cache hits and can skip hooks

**Priority**: `P1`
**Status**: Closed
**Source**: `lib/xcind/xcind-lib.bash:1852`
**Area**: Core runtime

### Resolution

`__xcind-run-hooks` (`lib/xcind/xcind-lib.bash`) now:

- Treats `$XCIND_GENERATED_DIR` as a cache hit only when the new
  `.complete` marker exists **and** every hook in the current
  `XCIND_HOOKS_GENERATE` has a persisted `.hook-output-{hook}` file. A
  missing marker or any missing per-hook output forces a rebuild instead of
  silently replaying a partial cache.
- Rebuilds atomically on cache miss: `rm -rf` any previous directory,
  `mkdir -p` a fresh one, run each hook, then write the `.complete` marker
  only after all hooks succeeded. The marker contains the registered hook
  list for diagnostics.
- Cleans up partial state when a hook fails: the generated directory is
  removed before the error is propagated, so the next invocation rebuilds
  from scratch instead of replaying a half-written cache.

### Validation

- New deterministic regression coverage in `test/test-xcind.sh`:
  - "partial cache" group — a hook fails after an earlier hook persisted
    output; the failing run cleans up, and the next run re-runs every hook
    instead of replaying.
  - "new hook" group — `XCIND_HOOKS_GENERATE` gains a hook between two runs
    with the same SHA; the previously generated directory is treated as
    incomplete and rebuilt, so the new hook actually runs.
- `bash test/test-xcind.sh`: 491 passed, 0 failed.
- `bash test/test-xcind-proxy.sh`: 515 passed, 0 failed.
- `make check`: passed.

### Behavior Observed

`__xcind-run-hooks` treats the mere existence of `$XCIND_GENERATED_DIR` as a cache hit. On that path, it loops through `XCIND_HOOKS_GENERATE`, but if `.hook-output-{hook}` is missing it silently continues. The cache-miss path creates `$XCIND_GENERATED_DIR` before running all hooks and does not remove it if a later hook fails, so a failed or interrupted generation can leave a partial directory that future runs replay as complete. The same skip behavior also masks newly added default hooks when an existing app has a stable SHA from an older Xcind version.

### Expected Behavior

A generated-dir cache hit should be accepted only when it is complete for the current hook registration set. Missing hook output for any registered hook should invalidate and rebuild the generated directory, not silently omit that hook's compose overlay.

### Impact

Required generated overlays can disappear without a config change: naming/app labels, env injection, proxy routing, assigned ports, host-gateway entries, or workspace aliases may be omitted from the Docker Compose invocation. This can cause broken routing, missing env files, wrong project names, or stale behavior after upgrades.

### Recommended Fix

Make generation atomic and validate completeness. One practical shape: write hooks into a temporary generated directory, validate each non-empty `-f` output, then rename into place with a completion marker that records the hook list. On cache hit, require the marker and every registered hook output before replaying; otherwise rebuild.

### Tests

- Add `test/test-xcind.sh` coverage where a hook fails after an earlier hook wrote output, then a second run with the same SHA must rebuild rather than skip the failed hook.
- Add coverage where `$XCIND_GENERATED_DIR` exists but `.hook-output-{new_hook}` is missing for the current `XCIND_HOOKS_GENERATE`; the hook must run.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/specs/hook-lifecycle.md` if a completion marker or new cache-validation rule becomes part of the hook cache contract.

## CORE-RUNTIME-002: Assigned-port generation is cached despite depending on live state outside the SHA

**Priority**: `P1`
**Status**: Closed
**Source**: `lib/xcind/xcind-lib.bash:1846`
**Area**: Core runtime

### Resolution

Introduced a new `XCIND_HOOKS_ALWAYS=("xcind-assigned-hook")` array in
`lib/xcind/xcind-lib.bash`. The assigned hook stays in
`XCIND_HOOKS_GENERATE` so ordering, the `.complete` marker, and the
per-hook completeness check from CORE-RUNTIME-001 remain intact, but on a
cache HIT replay `__xcind-run-hooks` now consults the new
`__xcind-hook-is-always` helper and re-runs any hook in
`XCIND_HOOKS_ALWAYS` against current live state instead of replaying its
persisted output. Pure GENERATE hooks (naming, app, app-env,
host-gateway, proxy, workspace) continue to replay from
`.hook-output-{name}` exactly as before. The re-run path also refreshes
the persisted output so a future run that drops the hook from
`XCIND_HOOKS_ALWAYS` still sees current state. Cache miss behavior is
unchanged.

### Validation

- New deterministic regression coverage:
  - `test/test-xcind.sh` "always-run" group — a stub `XCIND_HOOKS_ALWAYS`
    hook re-runs on cache hit when its live token mutates, while a sibling
    pure hook still replays from cache and the deleted overlay
    regenerates with the new token.
  - `test/test-xcind-proxy.sh` "xcind-assigned-hook re-runs through
    __xcind-run-hooks on cache hit" group — drives the full
    `__xcind-run-hooks` path with the real assigned hook: clears
    `~/.local/state/xcind/proxy/assigned-ports.tsv` and removes
    `compose.assigned.yaml` between two runs sharing the same SHA. The
    second run replays the pure stub from cache, re-runs
    `xcind-assigned-hook`, regenerates the overlay, and repopulates the
    TSV.
- `bash test/test-xcind.sh`: 501 passed, 0 failed.
- `bash test/test-xcind-proxy.sh`: 525 passed, 0 failed.
- `make check`: passed (lint + tests, exit 0).

### Behavior Observed

`xcind-assigned-hook` is registered in `XCIND_HOOKS_GENERATE` and is skipped on generated-dir cache hits like pure overlay hooks. Its output depends on live assigned-port TSV contents and port availability, but those inputs are not part of `__xcind-compute-sha`. If the TSV is edited, pruned, or otherwise changes while app inputs stay stable, `compose.assigned.yaml` can disagree with current assigned-port state until another SHA input changes.

### Expected Behavior

Generated output for `type=assigned` exports should remain consistent with the assigned-port registry and current allocation rules across repeated invocations with unchanged app config.

### Impact

Stable host-port mappings can become stale or misleading, especially after `xcind-proxy prune`, manual state repair, or competing allocations. Users may keep applying a cached port binding that no longer matches Xcind's state file.

### Recommended Fix

Use the existing handoff direction: separate always-run generation from pure cached generation, and move `xcind-assigned-hook` out of the cache-replay-only path. Alternatively, include the assigned TSV state in the cache key, but that broadens invalidation for every hook.

### Tests

- Add/update `test/test-xcind-proxy.sh` to mutate or delete the assigned TSV between two `xcind-compose`/`xcind-config` runs with a stable SHA and assert that `compose.assigned.yaml` regenerates.
- Verify pure hooks still replay from cache.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/specs/hook-lifecycle.md` and `engineering/specs/generated-override-files.md` if assigned generation becomes an always-run phase or a separate hook class.

## CORE-RUNTIME-003: Cache `config.json` is written before post-hook assigned-port state exists

**Priority**: `P2`
**Status**: Closed
**Source**: `lib/xcind/xcind-lib.bash:589`
**Area**: Core runtime

### Resolution

Split the cache `config.json` write out of `__xcind-populate-cache` into a
new `__xcind-write-cache-config-json` helper in `lib/xcind/xcind-lib.bash`.
`__xcind-populate-cache` now writes only `resolved-config.yaml` (still
called before hooks because hooks consume it for service enumeration).
`__xcind-prepare-app` invokes `__xcind-write-cache-config-json` after
`__xcind-run-hooks`, so the cached JSON reflects post-hook
`assignedExports` (and any other state hooks mutate). The helper writes
through a `.tmp` sidecar and `mv`s into place to avoid leaving a corrupt
`config.json` if `jq` fails, and is a no-op when `jq` is unavailable —
matching the prior behavior of `__xcind-populate-cache`. Cache miss and
cache hit paths both benefit because `__xcind-prepare-app` always reaches
the post-hook write step.

### Validation

- New deterministic regression coverage in `test/test-xcind-proxy.sh`
  ("cache config.json reflects post-hook assignedExports" group): seeds
  `resolved-config.yaml` with a single `mysql` service, registers the
  real `xcind-assigned-hook` in `XCIND_HOOKS_GENERATE` /
  `XCIND_HOOKS_ALWAYS`, drives `__xcind-run-hooks` followed by
  `__xcind-write-cache-config-json`, and asserts:
  - `config.json` does not exist until the post-hook write step.
  - The TSV row for the app records the assigned host port.
  - `.assignedExports.db.host_port` in the cached JSON equals the TSV
    host port.
  - `.assignedExports.db.container_port` and `.compose_service` match
    the declared export.
  - Cached `config.json` matches the live `__xcind-resolve-json` output
    byte-for-byte (the path `xcind-config --json` uses), confirming the
    direct cache reader sees the same state.
- `bash test/test-xcind.sh`: 501 passed, 0 failed.
- `bash test/test-xcind-proxy.sh`: 532 passed, 0 failed.
- `make lint`: clean.
- `make check`: passed (exit 0).

### Behavior Observed

`__xcind-prepare-app` calls `__xcind-populate-cache` before `__xcind-run-hooks`. `__xcind-populate-cache` writes `config.json` by calling `__xcind-resolve-json`, whose `assignedExports` value reads assigned-port state. On a cache miss, the assigned hook updates that state after `config.json` has already been written, so direct readers of `.xcind/cache/{sha}/config.json` can see stale assigned-export data. The CLI path re-resolves JSON later, so `xcind-config --json` is not affected.

### Expected Behavior

Cache `config.json` should reflect the same post-hook resolved state that `xcind-config --json` reports, or the cache file should not be treated as a current integration artifact.

### Impact

External integrations that read `.xcind/cache/{sha}/config.json` directly can observe missing or stale `assignedExports` immediately after a cache-miss run. This is a maintenance/integration risk rather than the primary CLI user path.

### Recommended Fix

Rewrite `config.json` after `__xcind-run-hooks`, or move the JSON cache write out of `__xcind-populate-cache` so it always happens after post-hook state is available. Keep `resolved-config.yaml` before hooks because hooks use it for service enumeration.

### Tests

- Add a regression test that triggers a cache-miss assigned-port allocation, reads `.xcind/cache/{sha}/config.json` directly after `__xcind-prepare-app`, and asserts that `assignedExports` matches the TSV row.
- Verify `xcind-config --json` output remains unchanged.
- Verify with `make check`.

### Engineering Docs

- No doc update required if the cache file is made fresh; update `engineering/reference/configuration.md` or integration docs only if direct cache consumers are intentionally unsupported.

## CORE-RUNTIME-004: Bootstrap source comment still says there are four callers

**Priority**: `P3`
**Status**: Closed
**Source**: `lib/xcind/xcind-bootstrap.bash:10`
**Area**: Core runtime

### Resolution

Replaced the stale "four callers" wording in `lib/xcind/xcind-bootstrap.bash`
with "every bin caller", so the comment no longer drifts as bin entrypoints
are added or removed (current set: `xcind-compose`, `xcind-config`,
`xcind-proxy`, `xcind-workspace`, `xcind-application`).

### Validation

- `bash test/test-xcind.sh`: 491 passed, 0 failed.
- `bash test/test-xcind-proxy.sh`: 515 passed, 0 failed.
- `shfmt --diff` and `shellcheck` clean on tracked SHELL_FILES (the only
  `make check` failure was `shfmt` reporting on the untracked `pi/`
  external project, unrelated to this change).

### Behavior Observed

The bootstrap file comment says centralizing startup avoids touching "four callers." Current installed bin scripts that source bootstrap are `xcind-compose`, `xcind-config`, `xcind-proxy`, `xcind-workspace`, and `xcind-application`.

### Expected Behavior

Source comments should avoid stale caller counts or should match the current bin surface.

### Impact

Low maintenance risk: future edits may underestimate the blast radius of bootstrap changes.

### Recommended Fix

Replace the exact caller count with "all bin callers" or update the count.

### Tests

- No behavior test required.
- Verify with `make lint`.

### Engineering Docs

- No engineering doc update required.

## CORE-RUNTIME-DOC-001: Stateless configuration wording conflicts with current state files

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-registry-lib.bash:1`
**Document Source**: `engineering/specs/configuration-schemas.md`

### Current Document Claim

The configuration schema spec says Xcind is stateless, has no state files, manifests, or registries, and infers runtime state from Docker.

### Actual Implementation Behavior

Current runtime behavior uses persistent state under `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/`, including assigned-port TSV state and a workspace registry. Other engineering docs, including workspace lifecycle and the configuration reference, already acknowledge those files.

### Authority Decision

Code correct, docs stale.

### Resolution

`engineering/specs/configuration-schemas.md` no longer claims Xcind is
stateless. The "Design Rationale: Declarative Configuration" section now
distinguishes declarative configuration (`.xcind.sh`, proxy `config.sh`)
from narrowly-scoped runtime state and generated artifacts under
`${XDG_STATE_HOME:-$HOME/.local/state}/xcind/` and per-app
`.xcind/generated/` directories. The aspect table lists the workspace
registry (`workspaces.tsv`) and the assigned-port state
(`proxy/assigned-ports.tsv`) alongside the existing declarative sources,
and links to [Workspace Lifecycle: State](../specs/workspace-lifecycle.md#state)
so the two specs stay aligned. The doc-only edit landed on the current
branch in commit `733dcbf` ahead of this ledger update.

### Validation

- `rtk make lint`: passed (shfmt + shellcheck clean on tracked SHELL_FILES).
- No source files changed; tests not re-run for this doc-only drift item.

### Proposed Documentation Update

Update `engineering/specs/configuration-schemas.md` to distinguish declarative configuration from narrowly scoped runtime state, matching the state table in `engineering/specs/workspace-lifecycle.md`.

### Related Finding

None.

## CORE-RUNTIME-DOC-002: Generated override cache-key documentation is incomplete

**Status**: Open
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-lib.bash:1085`
**Document Source**: `engineering/specs/generated-override-files.md`

### Current Document Claim

The generated override spec says the cache SHA is computed from compose file paths/content, app `.xcind.sh`, workspace `.xcind.sh`, and global proxy config.

### Actual Implementation Behavior

`__xcind-compute-sha` also includes compose env files, app env files, sourced additional config files and overrides, `XCIND_TOOLS`, app/workspace/workspaceless naming variables, host-gateway configuration variables, and the runtime-detected host-gateway value when enabled.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Expand the cache-key list in `engineering/specs/generated-override-files.md` or defer to `engineering/specs/hook-lifecycle.md` with a complete list that includes env files, additional configs, tools, naming inputs, and host-gateway inputs.

### Related Finding

None.

## CORE-RUNTIME-DOC-003: Configuration source order omits override and additional config sourcing

**Status**: Open
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-lib.bash:543`
**Document Source**: `engineering/specs/configuration-schemas.md`

### Current Document Claim

The configuration schema spec summarizes source order as global proxy config, workspace `.xcind.sh`, then application `.xcind.sh`.

### Actual Implementation Behavior

The runtime source chain includes workspace `.xcind.override.sh`, workspace `XCIND_ADDITIONAL_CONFIG_FILES` plus their overrides, app `.xcind.sh`, app `.xcind.override.sh`, and app additional config files plus their overrides. Global proxy config is sourced by proxy-specific code when needed, not as the first step in the generic app-resolution pipeline.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Revise the source-order section in `engineering/specs/configuration-schemas.md` to describe the runtime app-resolution order precisely and note that global proxy config is consumed by proxy behavior rather than universally sourced before workspace/app config.

### Related Finding

None.

## CORE-RUNTIME-DOC-004: Project layout omits bootstrap and newer runtime libraries

**Status**: Open
**Layer**: Implementation
**Implementation Source**: `lib/xcind/xcind-bootstrap.bash:1`
**Document Source**: `engineering/implementation/project-layout.md`

### Current Document Claim

The implementation layout lists a small subset of `lib/xcind` files and describes the core library as the direct shared library sourced by executables.

### Actual Implementation Behavior

Bin scripts source `xcind-bootstrap.bash`, which then sources `xcind-lib.bash`. `xcind-lib.bash` also sources newer libraries including app identity, assigned ports, host gateway, workspace registry, and completions exist in the installed library tree.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Update `engineering/implementation/project-layout.md` to include `xcind-bootstrap.bash`, the current bin entrypoints, and all maintained `lib/xcind` files with concise responsibilities.

### Related Finding

`CORE-RUNTIME-004`
