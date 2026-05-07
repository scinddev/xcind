# Source Review: Workspace and App Identity

**Date**: 2026-05-05
**Reviewer**: Codex
**Status**: Complete

## Scope

**Source files reviewed**:
- `lib/xcind/xcind-workspace-lib.bash`
- `lib/xcind/xcind-app-lib.bash`
- `bin/xcind-workspace`
- `bin/xcind-application`

**Related engineering docs checked**:
- `engineering/maintenance/source-review-plan.md`
- `engineering/maintenance/source-review-templates.md`
- `engineering/DOCUMENTATION-GUIDE.md`
- `engineering/maintenance/sync.md`
- `engineering/specs/workspace-lifecycle.md`
- `engineering/specs/application-lifecycle.md`
- `engineering/specs/context-detection.md`
- `engineering/specs/directory-structure.md`
- `engineering/specs/configuration-schemas.md`
- `engineering/specs/generated-override-files.md`
- `engineering/specs/docker-labels.md`
- `engineering/specs/hook-lifecycle.md`
- `engineering/reference/cli.md`
- `engineering/reference/configuration.md`
- `engineering/architecture/overview.md`
- `engineering/implementation/project-layout.md`

**Related tests/examples checked**:
- `test/test-xcind.sh`
- `test/test-xcind-proxy.sh`
- `engineering/behaviors/workspace/workspace-mode.feature`
- `engineering/behaviors/workspace/self-declaration.feature`
- `engineering/behaviors/workspace/network-aliases.feature`
- `engineering/behaviors/config-resolution/xcind-sh-discovery.feature`
- `engineering/behaviors/config-resolution/override-files.feature`
- `engineering/behaviors/config-resolution/project-naming.feature`
- `examples/workspaces/dev/frontend/.xcind.sh`
- `examples/workspaces/dev/backend/.xcind.sh`
- `examples/workspaceless/acmeapps/.xcind.sh`

## Review Notes

**Behavior summary**:
The workspace and app identity area provides generated Compose overlays for app labels and workspace network aliases, plus management CLIs for creating, inspecting, registering, listing, and forgetting workspaces and applications. Runtime context detection remains in `xcind-lib.bash`, but this area depends on its workspace/app variables and labels generated here for Docker-based status queries.

**Key contracts verified**:
- `xcind-app-hook` emits `compose.app.yaml` with `xcind.app.name` and `xcind.app.path` labels for every resolved service.
- `xcind-workspace-hook` skips workspaceless apps and emits `compose.workspace.yaml` with workspace labels, a workspace-internal network attachment, and service aliases in workspace mode.
- `__xcind-workspace-execute-hook` runs on every `xcind-compose` invocation in workspace mode and attempts to create `{workspace}-internal`.
- `xcind-workspace init` creates `.xcind.sh` with `XCIND_IS_WORKSPACE=1`, optional `XCIND_WORKSPACE` / `XCIND_PROXY_DOMAIN`, and auto-registers the workspace.
- `xcind-workspace status/list/register/forget` use the workspace registry and source discovered `.xcind.sh` files under the documented trust boundary.
- `xcind-application init/status/list` scaffold app config, reject workspace roots for app init, derive status from `xcind-config --json`, and enumerate immediate non-hidden app directories in a workspace.

**Risks assessed**:
- Correctness and failure handling: The hook generation paths mostly soft-skip as documented, but workspace network creation suppresses all Docker failures, and several CLI parsers accept malformed argument shapes.
- Bash 3.2 portability: Arrays, process substitution, dynamic scoping callbacks, and `local` usage are consistent with the rest of the project and pass shellcheck.
- Shell safety and maintainability: Paths are generally quoted. The init writers intentionally rewrite `.xcind.sh`; the application CLI documents that caveat, but workspace init does not.
- State/cache/generated files: App/workspace generated files are deterministic on cache miss. Workspace registry writes are silent by design, but `list --prune` mutates state and was not run during this review.
- CLI/config contracts: Main CLI reference is mostly aligned. Workspace init update semantics and exact argument cardinality are weaker than expected for management commands.
- Tests and behavior evidence: Existing tests cover app/workspace init/status/list, app and workspace hooks, registry auto-registration, stale registry handling, and workspace mismatch filtering. Missing coverage remains for missing flag values, repeated positional args, and failed workspace network creation diagnostics.
- Engineering documentation drift: Confirmed stale claims around statelessness, global state layout, project layout, hook responsibilities, and `xcind-config` no-arg behavior.

## Findings

| ID | Priority | Title | Source Location | Status |
|----|----------|-------|-----------------|--------|
| `WAI-001` | `P2` | Workspace/application init flags without values abort through `set -u` | `bin/xcind-workspace:65` | Closed |
| `WAI-002` | `P2` | Workspace/application subcommands silently accept repeated or extra positional arguments | `bin/xcind-application:211` | Closed |
| `WAI-003` | `P1` | `xcind-workspace init` with flags rewrites existing workspace config and drops unrelated settings | `bin/xcind-workspace:106` | Closed |
| `WAI-004` | `P2` | Workspace network creation failures are fully suppressed before compose uses the external network | `lib/xcind/xcind-workspace-lib.bash:108` | Closed |

## Documentation Drift

| ID | Layer | Document | Summary | Status |
|----|-------|----------|---------|--------|
| `WAI-DOC-001` | Specifications | `engineering/specs/configuration-schemas.md` | Stateless configuration rationale still says there are no state files, manifests, or registries, but workspace registry and assigned-port state are current behavior. | Closed |
| `WAI-DOC-002` | Specifications | `engineering/specs/directory-structure.md` | Global state tree documents proxy state but omits `${XDG_STATE_HOME}/xcind/workspaces.tsv`. | Closed |
| `WAI-DOC-003` | Implementation | `engineering/implementation/project-layout.md` | Source layout omits `bin/xcind-workspace`, `bin/xcind-application`, `xcind-app-lib.bash`, and other current built-in libraries/hooks. | Open |
| `WAI-DOC-004` | Architecture | `engineering/architecture/overview.md` | Architecture says the workspace internal network is created by `xcind-workspace-hook` and omits several current GENERATE hooks from the pipeline list. | Open |
| `WAI-DOC-005` | Specifications | `engineering/specs/hook-lifecycle.md` | Built-in hook table says `xcind-proxy-hook` emits context labels even though app/workspace context labels are now emitted by dedicated hooks. | Open |
| `WAI-DOC-006` | Specifications | `engineering/specs/context-detection.md` | Quick reference says bare `xcind-config` shows JSON/appRoot, but implementation and CLI reference make bare `xcind-config` show help. | Open |

## Commands Run

```bash
rtk make lint
```

**Result**: Passed for the initial review pass.

For the follow-up implementation pass (Round 4), `make check` passed for the core staged patch in a clean temporary worktree. In the local orchestrator environment, `make check` is occasionally blocked at the `shfmt --diff .` step by unrelated untracked `pi/` directories, but focused validation (`shfmt`, `shellcheck`, and `make test`) passes for the modified files.

## Blockers or Follow-Up

- All implementation findings have been implemented and closed.
- WAI-DOC-001, WAI-DOC-002, and WAI-DOC-003 were closed in Round 4.
- WAI-001, WAI-002, and WAI-003 overlap with CLI-area findings and were resolved in Round 1 follow-ups.
- WAI-004 was resolved in Round 4.

## WAI-001: Workspace/application init flags without values abort through `set -u`

**Priority**: `P2`
**Status**: Closed
**Source**: `bin/xcind-workspace:65`
**Area**: Workspace and app identity

### Resolution

Resolved by the Round 1 CLI entrypoint follow-up for `CLI-ENTRY-001`
(PR #64). Current `xcind-workspace init` and `xcind-application init`
parsers call local missing-value guards before reading `$2`; missing
`--name` / `--proxy-domain` values now fail with command-shaped `Error:`
messages instead of unbound-variable diagnostics.

### Validation

- Existing `test/test-xcind.sh` coverage asserts missing values for
  `xcind-workspace init --name`, `xcind-workspace init --proxy-domain`, and
  `xcind-application init --name` exit non-zero, include `Error:`, name the
  flag, and do not include `unbound variable`.
- Round 1 ledger validation: `make check`.

### Behavior Observed

`xcind-workspace init` reads `$2` directly for `--proxy-domain` and `--name`; `xcind-application init` does the same for `--name`. With `set -u`, commands such as `xcind-workspace init --name` and `xcind-application init --name` fail with an unbound-variable shell diagnostic instead of the command's normal `Error:` and usage style.

### Expected Behavior

Value-taking flags should validate that the next argument exists and is a value. Missing values should fail with command-specific errors and non-zero status.

### Impact

Invalid user input produces inconsistent, implementation-shaped errors. This is especially visible in scripts because the failure mode differs from other unknown-option handling in the same commands.

### Recommended Fix

Add a Bash-3.2-compatible helper or local guard before reading `$2` in both init parsers. Prefer a shared pattern for all value-taking flags in management CLIs.

### Tests

- Add `test/test-xcind.sh` cases for `xcind-workspace init --name`, `xcind-workspace init --proxy-domain`, and `xcind-application init --name`.
- Assert non-zero status and an `Error:` message without `unbound variable`.
- Verify with `make check`.

### Engineering Docs

- No doc update required because this is invalid-input handling, not a documented behavior change.

## WAI-002: Workspace/application subcommands silently accept repeated or extra positional arguments

**Priority**: `P2`
**Status**: Closed
**Source**: `bin/xcind-application:211`
**Area**: Workspace and app identity

### Resolution

Resolved by the Round 1 CLI entrypoint follow-up for `CLI-ENTRY-002`
(PR #64). Current optional-`DIR` parsers track whether a positional argument
has already been set and reject a second positional with `Unexpected
argument`; `xcind-workspace register` and `xcind-workspace forget` also reject
surplus path arguments.

### Validation

- Existing `test/test-xcind.sh` coverage rejects repeated `DIR` values for
  `xcind-workspace init`, `xcind-workspace status`, `xcind-application init`,
  `xcind-application status`, and `xcind-application list`, plus surplus
  arguments for workspace register/forget.
- Round 1 ledger validation: `make check`.

### Behavior Observed

Several parsers treat any non-option as `DIR` and keep parsing, so repeated positional arguments overwrite earlier values. Examples include `xcind-workspace status dir1 dir2`, `xcind-application status dir1 dir2`, and `xcind-application list dir1 dir2`. `xcind-workspace register PATH extra` and `xcind-workspace forget PATH extra` only read `$1` and ignore surplus arguments.

### Expected Behavior

Commands that accept at most one positional argument should reject a second positional argument. Commands that require exactly one path should reject zero and more than one path.

### Impact

Typos can make commands inspect, register, or forget a different path than the user intended, and surplus arguments give a false sense that additional filters or operands were honored.

### Recommended Fix

Track whether `DIR` has already been set in status/list parsers and error on a second positional. For `register` and `forget`, require `"$#"` to equal one after help handling.

### Tests

- Add `test/test-xcind.sh` cases for repeated `DIR` arguments on workspace status, application status, and application list.
- Add cases for `xcind-workspace register PATH extra` and `xcind-workspace forget PATH extra`.
- Verify with `make check`.

### Engineering Docs

- No doc update required unless usage text is expanded to state exact argument cardinality.

## WAI-003: `xcind-workspace init` with flags rewrites existing workspace config and drops unrelated settings

**Priority**: `P1`
**Status**: Closed
**Source**: `bin/xcind-workspace:106`
**Area**: Workspace and app identity

### Resolution

Resolved by the Round 1 CLI entrypoint follow-up for `CLI-ENTRY-003`
(PR #64). Current `xcind-workspace init` uses targeted key updates for
`XCIND_WORKSPACE` and `XCIND_PROXY_DOMAIN` when re-running init with flags
against an existing workspace. Unrelated workspace configuration remains in
place.

### Validation

- Existing `test/test-xcind.sh` coverage re-runs `xcind-workspace init` with
  `--name` and `--proxy-domain` against an existing `.xcind.sh` containing
  `XCIND_ADDITIONAL_CONFIG_FILES`, then asserts the unrelated setting is
  preserved while managed keys are updated.
- Round 1 ledger validation: `make check`.

### Behavior Observed

When `.xcind.sh` already marks a workspace and `xcind-workspace init` is re-run with `--name` or `--proxy-domain`, the command sources existing values for only `XCIND_WORKSPACE` and `XCIND_PROXY_DOMAIN`, then rewrites `.xcind.sh` with just `XCIND_IS_WORKSPACE=1` and those optional values.

### Expected Behavior

Re-running workspace init with flags should preserve unrelated workspace configuration or explicitly document and warn that only the managed minimal file shape is retained.

### Impact

Users can lose workspace-level settings such as hook arrays, URL templates, proxy options, or additional supported `XCIND_*` variables by running an update command that the CLI reference describes as updating config.

### Recommended Fix

Preserve existing file content and edit only managed keys where practical. If full preservation is intentionally out of scope, add an explicit warning and document the rewrite caveat in the CLI reference and workspace lifecycle spec, mirroring the application init caveat.

### Tests

- Add a test where an existing workspace `.xcind.sh` contains an unrelated supported variable, then `xcind-workspace init --name ...` preserves it.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/reference/cli.md` and `engineering/specs/workspace-lifecycle.md` if the intended behavior remains rewrite-only.

## WAI-004: Workspace network creation failures are fully suppressed before compose uses the external network

**Priority**: `P2`
**Status**: Closed
**Source**: `lib/xcind/xcind-workspace-lib.bash:108`
**Area**: Workspace and app identity

### Resolution

Updated `__xcind-workspace-execute-hook` to inspect the workspace network
before attempting creation. If the network is missing, the hook attempts
`docker network create`; on failure, it checks again to suppress the normal
create/inspect race and otherwise prints warnings that name the workspace
network, include Docker's error output when present, and explain that Docker
Compose may later fail because the external network is unavailable. The hook
still returns success to preserve non-fatal EXECUTE hook behavior.

### Validation

- Added `test/test-xcind.sh` coverage for a failed `docker network create`:
  the hook exits 0, warns with the workspace network name, includes Docker's
  error output, and warns that Docker Compose may fail.
- Added `test/test-xcind.sh` coverage for an existing network: the hook exits
  0 without warning.
- Updated existing `test/test-xcind-proxy.sh` execute-hook coverage to expect
  the new inspect-before-create flow.
- `shfmt --diff lib/xcind/xcind-workspace-lib.bash test/test-xcind.sh test/test-xcind-proxy.sh`: passed.
- `make shellcheck`: passed.
- `make test`: passed, 599 passed / 0 failed.
- `make check`: blocked at `shfmt --diff .` by unrelated untracked
  `pi/examples/extensions/doom-overlay/doom/build.sh` formatting drift in the
  existing worktree; no Round 4 files were reported by the focused shfmt check.

### Behavior Observed

`__xcind-workspace-execute-hook` runs `docker network create "$network" >/dev/null 2>&1 || true` for every workspace-mode compose invocation. This suppresses success, already-exists, Docker-not-running, permission, and invalid-name failures alike. The generated `compose.workspace.yaml` declares the same network as external, so Docker Compose will later fail if the network was not actually created.

### Expected Behavior

The execute hook should remain idempotent and avoid failing for the already-exists case, but unexpected Docker failures should produce a diagnostic that names the network and failing operation. If the design is to keep EXECUTE hooks non-fatal, the warning should still explain that Compose may fail because the external workspace network is unavailable.

### Impact

Users can see a later Docker Compose external-network failure with no indication that Xcind attempted and failed to create the workspace network. This makes Docker daemon, permissions, and invalid workspace-name problems harder to diagnose.

### Recommended Fix

Check whether the network exists first, then attempt creation. Suppress only the already-exists race. On other failures, print a concise warning to stderr with the network name and Docker error; decide separately whether this hook should remain non-fatal under the hook lifecycle convention.

### Tests

- Add a test that mocks `docker network inspect` missing and `docker network create` failing, then asserts a warning is emitted.
- Keep the existing idempotent success/no-op tests.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/specs/hook-lifecycle.md` only if the fix changes EXECUTE hook failure policy.

## WAI-DOC-001: Configuration schemas still describe Xcind as having no registries or state files

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-workspace:54`
**Document Source**: `engineering/specs/configuration-schemas.md`

### Current Document Claim

The stateless configuration section says Xcind has no state files, manifests, or registries.

### Actual Implementation Behavior

Workspace init and runtime discovery write `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/workspaces.tsv`; assigned ports use `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy/assigned-ports.tsv`.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Update the rationale to distinguish declarative configuration from narrow runtime state. List `workspaces.tsv` and `proxy/assigned-ports.tsv` as state files rather than saying no registries exist.

### Related Finding

None.

### Resolution

No additional documentation edit was needed. `engineering/specs/configuration-schemas.md` is already aligned by earlier docs work: it distinguishes declarative `.xcind.sh`/proxy config from runtime state, lists `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/workspaces.tsv`, and lists `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy/assigned-ports.tsv`.

### Validation

- `rtk rg -n "workspaces\\.tsv|assigned-ports\\.tsv|XDG_STATE_HOME|\\.local/state" bin lib`
- `rtk rg -n "workspaces\\.tsv|assigned-ports\\.tsv|declarative|runtime state|state" engineering/specs/configuration-schemas.md`
- `rtk rg -n "no state files|no registries|no state|stateless|manifests|registries" engineering/specs/configuration-schemas.md` returned no stale wording matches.

## WAI-DOC-002: Directory structure omits workspace registry state

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-workspace:54`
**Document Source**: `engineering/specs/directory-structure.md`

### Current Document Claim

The global state tree documents only the `proxy/` subdirectory under `~/.local/state/xcind/`.

### Actual Implementation Behavior

`xcind-workspace init`, `xcind-workspace register`, and runtime workspace discovery maintain `~/.local/state/xcind/workspaces.tsv` outside the proxy subdirectory.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Add `workspaces.tsv` to the global state tree and describe it as the workspace discovery registry consumed by `xcind-workspace list/register/forget`.

### Related Finding

None.

### Resolution

Updated `engineering/specs/directory-structure.md` Global Configuration section. Added `workspaces.tsv` outside the `proxy/` subdirectory and updated text to describe it as the workspace discovery registry state consumed by `xcind-workspace list/register/forget`.

### Validation

- `rtk rg -n "workspaces\.tsv|xcind-workspace list/register/forget|XCIND_REGISTRY_FILE|XCIND_REGISTRY_DIR" engineering/specs/directory-structure.md lib/xcind/xcind-registry-lib.bash bin/xcind-workspace`
- `make check` was attempted in the local worktree and stopped at
  repository-wide `shfmt --diff .` due to unrelated untracked
  `pi/examples/extensions/doom-overlay/doom/build.sh` formatting drift.

## WAI-DOC-003: Project layout omits current workspace/application entrypoints and identity hooks

**Status**: Closed
**Layer**: Implementation
**Implementation Source**: `bin/xcind-workspace:1`
**Document Source**: `engineering/implementation/project-layout.md`

### Current Document Claim

The implementation layout lists only three executables and omits `xcind-app-lib.bash`, `xcind-assigned-lib.bash`, `xcind-host-gateway-lib.bash`, registry/bootstrap/completion libraries, and the newer workspace/application entrypoints.

### Actual Implementation Behavior

The maintained executable set includes `xcind-workspace` and `xcind-application`, and the default hook set includes app identity, app env, host gateway, proxy, assigned ports, and workspace hooks.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Refresh the source tree and built-in hook list in `engineering/implementation/project-layout.md` to match `bin/`, `lib/xcind/`, `Makefile`, and `contrib/test-all`.

### Related Finding

None.

### Resolution

Confirmed that `engineering/implementation/project-layout.md` was already refreshed in a previous round: it contains all `bin/` entrypoints (including `xcind-workspace` and `xcind-application`), all `lib/xcind/*.bash` files (including `xcind-app-lib.bash`, `xcind-assigned-lib.bash`, etc.), and all built-in hooks.

### Validation

- `rtk rg --files bin lib/xcind`
- `rtk rg -n "xcind-workspace|xcind-application|xcind-app-lib|xcind-workspace-lib|__xcind-workspace-execute-hook|Built-in hooks|lib/xcind/xcind-registry-lib.bash" engineering/implementation/project-layout.md`
- `rtk git diff --check`

## WAI-DOC-004: Architecture overview has stale workspace network and hook pipeline wording

**Status**: Open
**Layer**: Architecture
**Implementation Source**: `lib/xcind/xcind-workspace-lib.bash:99`
**Document Source**: `engineering/architecture/overview.md`

### Current Document Claim

The network section says the workspace internal network is created by `xcind-workspace-hook`, and the Docker Compose integration section lists only naming, app-env, proxy, and workspace as GENERATE hooks.

### Actual Implementation Behavior

`xcind-workspace-hook` is a pure GENERATE hook that writes the external-network overlay. `__xcind-workspace-execute-hook` creates the Docker network at execution time. The current default GENERATE hook list also includes app identity, host gateway, and assigned-port hooks.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Update the architecture overview to attribute workspace network creation to the EXECUTE hook and refresh the hook pipeline list with all default built-in hooks.

### Related Finding

None.

## WAI-DOC-005: Hook lifecycle still attributes context labels to the proxy hook

**Status**: Open
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-app-lib.bash:17`
**Document Source**: `engineering/specs/hook-lifecycle.md`

### Current Document Claim

The built-in hook table says `xcind-proxy-hook` generates Traefik labels, proxy network, and context labels.

### Actual Implementation Behavior

App context labels are emitted by `xcind-app-hook`; workspace context labels are emitted by `xcind-workspace-hook`; the proxy hook no longer owns those labels.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Change the proxy hook purpose to Traefik labels, proxy network attachment, and export labels. Leave context labels documented on app/workspace hooks, matching `engineering/specs/docker-labels.md`.

### Related Finding

None.

## WAI-DOC-006: Context detection quick reference has stale `xcind-config` no-arg behavior

**Status**: Open
**Layer**: Specifications
**Implementation Source**: `bin/xcind-config:1`
**Document Source**: `engineering/specs/context-detection.md`

### Current Document Claim

The quick reference says bare `xcind-config` produces JSON output with `appRoot`.

### Actual Implementation Behavior

Bare `xcind-config` shows usage help. JSON output requires `xcind-config --json`, which matches `engineering/reference/cli.md`.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Remove or correct the bare `xcind-config` line and keep `xcind-config --json` as the JSON/appRoot example.

### Related Finding

None.
