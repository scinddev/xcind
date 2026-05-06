# Source Review: CLI entrypoints

**Date**: 2026-05-05
**Reviewer**: Codex
**Status**: Complete

## Scope

**Source files reviewed**:
- `bin/xcind-compose`
- `bin/xcind-config`
- `bin/xcind-proxy`
- `bin/xcind-workspace`
- `bin/xcind-application`

**Related engineering docs checked**:
- `engineering/maintenance/source-review-plan.md`
- `engineering/maintenance/source-review-templates.md`
- `engineering/DOCUMENTATION-GUIDE.md`
- `engineering/reference/cli.md`
- `engineering/specs/context-detection.md`
- `engineering/specs/configuration-schemas.md`
- `engineering/specs/proxy-infrastructure.md`
- `engineering/specs/workspace-lifecycle.md`
- `engineering/specs/application-lifecycle.md`
- `engineering/implementation/project-layout.md`
- `engineering/implementation/tech-stack.md`

**Related tests/examples checked**:
- `test/test-xcind.sh`
- `test/test-xcind-proxy.sh`
- `engineering/behaviors/config-resolution/project-naming.feature`
- `engineering/behaviors/proxy/*.feature`
- `engineering/behaviors/workspace/*.feature`
- `examples/workspaceless/acmeapps/.xcind.sh`
- `examples/workspaces/dev/*/.xcind.sh`

## Review Notes

**Behavior summary**:
The CLI entrypoints resolve their install root, source the bootstrap library, then either dispatch command-specific management actions or run the shared app-resolution pipeline. `xcind-compose` is a thin Docker Compose executor. `xcind-config` exposes resolved configuration, preview, doctor, completion, dependency check, and generator modes. `xcind-proxy`, `xcind-workspace`, and `xcind-application` provide management subcommands around proxy state, workspace registry/status, and application scaffolding/status/listing.

**Key contracts verified**:
- All five binaries support `--version`/`-V` and resolve symlinked install roots without GNU `readlink -f`.
- `xcind-compose` and `xcind-config` use the shared `__xcind-prepare-app` pipeline before consuming resolved compose options.
- `xcind-config` no-arg behavior is help output, and stdout-producing modes reject incompatible combinations.
- `xcind-proxy status --json`, workspace/application JSON modes, and config JSON modes require `jq` before structured output.
- Workspace and application status/list commands intentionally source discovered `.xcind.sh` files, matching the documented trust boundary.

**Risks assessed**:
- Correctness and failure handling: Most command failures are checked, but several argument parsers assume values after flags or ignore unexpected trailing arguments.
- Bash 3.2 portability: Entry points use arrays, process substitution, and dynamic scoping patterns compatible with Bash 3.2; `make lint` found no shellcheck/shfmt issues.
- Shell safety and maintainability: Path expansions are generally quoted. Repeated root-resolution stubs are duplicated across all entrypoints and must remain synchronized.
- State/cache/generated files: `xcind-config` compose configuration generation uses a temp file and rename; proxy/workspace/application management commands can mutate state, so only lint was run for validation.
- CLI/config contracts: Main reference is mostly aligned, but proxy init help and several specs drift from implementation behavior.
- Tests and behavior evidence: Existing tests cover version/help smoke, config argument validation, proxy init/status/release/prune, workspace init/status/list/register/forget, and application init/status/list. Missing-value and trailing-argument cases are not covered.
- Engineering documentation drift: Confirmed drift in proxy init config overwrite semantics, stale project layout, stale "no registries" wording, and `xcind-config` no-arg output in the context-detection quick reference.

## Findings

| ID | Priority | Title | Source Location | Status |
|----|----------|-------|-----------------|--------|
| `CLI-ENTRY-001` | `P2` | Init flags without values abort through `set -u` instead of usage errors | `bin/xcind-proxy:52` | Closed |
| `CLI-ENTRY-002` | `P2` | Several subcommands silently ignore unexpected trailing arguments | `bin/xcind-proxy:483` | Closed |
| `CLI-ENTRY-003` | `P1` | `xcind-workspace init` with flags rewrites existing workspace config and drops unrelated settings | `bin/xcind-workspace:106` | Closed |
| `CLI-ENTRY-004` | `P3` | `xcind-proxy init --help` still names legacy `docker-compose.yaml` output | `bin/xcind-proxy:424` | Closed |

## Documentation Drift

| ID | Layer | Document | Summary | Status |
|----|-------|----------|---------|--------|
| `CLI-ENTRY-DOC-001` | Specifications | `engineering/specs/proxy-infrastructure.md` | Proxy init spec says `config.sh` is only created if missing and never overwritten, but CLI init rewrites it from existing values plus flags. | Closed |
| `CLI-ENTRY-DOC-002` | Implementation | `engineering/implementation/project-layout.md` | Executable and library tree omits newer workspace/application entrypoints and several installed libraries. | Closed |
| `CLI-ENTRY-DOC-003` | Specifications | `engineering/specs/configuration-schemas.md` | Stateless configuration section says there are no state files, manifests, or registries, but the workspace registry and assigned-port state are current behavior. | Closed |
| `CLI-ENTRY-DOC-004` | Specifications | `engineering/specs/context-detection.md` | Quick reference says bare `xcind-config` shows JSON/appRoot, but the implementation and CLI reference make bare `xcind-config` show help. | Closed |

## Commands Run

```bash
rtk make lint
rtk make check
```

**Result**: Passed.

`make check` emitted transient assigned-ports temp-file `mv` diagnostics during tests, but the target completed successfully with exit code 0.

## Blockers or Follow-Up

- No blockers.
- Implement findings in small follow-up changes, then run `make check`.

## CLI-ENTRY-001: Init flags without values abort through `set -u` instead of usage errors

**Priority**: `P2`
**Status**: Closed
**Source**: `bin/xcind-proxy:52`
**Area**: CLI entrypoints

### Behavior Observed

`xcind-proxy init` reads values directly from `$2` for every value-taking flag. `xcind-workspace init` and `xcind-application init` use the same pattern for their value-taking flags. With `set -u`, commands such as `xcind-proxy init --http-port`, `xcind-workspace init --name`, and `xcind-application init --name` abort with an unbound-variable shell error instead of the command's normal `Error:`/usage style.

### Expected Behavior

Every value-taking CLI flag should validate that a following value exists and is not another option when that flag requires a value. Failures should print a command-specific error and exit non-zero without a shell runtime diagnostic.

### Impact

This is a user-facing CLI quality issue and makes scripting against invalid input harder because the error format is inconsistent with the rest of the parsers.

### Recommended Fix

Add small helpers or local checks before reading `$2` in `xcind-proxy init`, `xcind-workspace init`, and `xcind-application init`. Preserve Bash 3.2 compatibility and existing accepted forms.

### Tests

- Add invalid-argument tests in `test/test-xcind-proxy.sh` for missing values on proxy init flags.
- Add invalid-argument tests in `test/test-xcind.sh` for workspace/application init missing values.
- Verify with `make check`.

### Engineering Docs

- No doc update required because this is invalid-input handling, not a documented behavior change.

### Resolution

Closed by adding missing-value checks before reading `$2` in `xcind-proxy init`, `xcind-workspace init`, and `xcind-application init`. Regression coverage now rejects missing values for proxy init flags `--proxy-domain`, `--http-port`, `--image`, `--dashboard`, `--dashboard-port`, `--tls-mode`, `--https-port`, `--tls-cert-file`, and `--tls-key-file`; workspace init flags `--name` and `--proxy-domain`; and application init flag `--name`.

Validation: `rtk make check`.

## CLI-ENTRY-002: Several subcommands silently ignore unexpected trailing arguments

**Priority**: `P2`
**Status**: Closed
**Source**: `bin/xcind-proxy:483`
**Area**: CLI entrypoints

### Behavior Observed

`xcind-proxy up` receives only `${2:-}` from dispatch, so `xcind-proxy up --force extra` ignores `extra`, and `xcind-proxy up --bogus` falls through as a normal non-force `up`. `down`, `prune`, and `release` similarly do not reject surplus arguments. `status` only checks whether the first argument is `--json`, then ignores the rest. Workspace/application parsers also accept repeated positional `DIR` values by overwriting the previous one.

### Expected Behavior

Subcommands should reject unknown flags and unexpected positional arguments consistently, matching the stricter behavior already present in `xcind-config`, `xcind-workspace list`, `xcind-application list`, and init parsers for unknown options.

### Impact

Typos can execute a command against real Docker or Xcind state while appearing accepted. This matters most for `xcind-proxy up/down/prune/release`, where state changes are expected.

### Recommended Fix

Pass full subcommand arguments after `shift`, parse each subcommand explicitly, and reject unexpected arguments. For `release`, require exactly one port. For `status`, allow only zero args or `--json`.

### Tests

- Add proxy CLI tests in `test/test-xcind-proxy.sh` for `up --bogus`, `up --force extra`, `status --json extra`, `down extra`, `prune extra`, and `release 3306 extra`.
- Add workspace/application tests in `test/test-xcind.sh` for repeated `DIR` arguments where only one is supported.
- Verify with `make check`.

### Engineering Docs

- No doc update required unless new usage text is added for exact argument cardinality.

### Resolution

Closed by passing full argument lists through proxy dispatch and rejecting unknown flags or unexpected positionals before stateful operations. Affected proxy subcommands are `up`, `down`, `status`, `release`, and `prune`; workspace/application optional-`DIR` parsers now reject repeated `DIR` arguments for `xcind-workspace init/status` and `xcind-application init/status/list`. `xcind-workspace register/forget` also reject surplus path arguments.

Validation: `make check`.

## CLI-ENTRY-003: `xcind-workspace init` with flags rewrites existing workspace config and drops unrelated settings

**Priority**: `P1`
**Status**: Closed
**Source**: `bin/xcind-workspace:106`
**Area**: CLI entrypoints

### Behavior Observed

When `.xcind.sh` already marks a workspace and `xcind-workspace init` is re-run with `--name` or `--proxy-domain`, the command sources the existing file only to recover `XCIND_WORKSPACE` and `XCIND_PROXY_DOMAIN`, then rewrites `.xcind.sh` with just `XCIND_IS_WORKSPACE=1` plus those two optional values. Any other hand-edited workspace settings are removed.

### Expected Behavior

Re-running workspace init with flags should either preserve unrelated workspace configuration or clearly document and warn that the command rewrites the file and drops unsupported fields. The current CLI reference says the config is updated, which reads as a targeted update rather than a destructive rewrite.

### Impact

Users can lose workspace-level settings such as hook arrays, proxy defaults beyond the one flag, or other supported `XCIND_*` variables by re-running a management command that appears safe.

### Recommended Fix

Prefer preserving existing file content and editing only managed keys, using a Bash-3.2-compatible approach. If full preservation is intentionally out of scope, add a warning and update the CLI reference/workspace lifecycle docs with the same explicit caveat already present for `xcind-application init --name`.

### Tests

- Add a `test/test-xcind.sh` case where an existing workspace `.xcind.sh` contains an unrelated supported variable, then `xcind-workspace init --name ...` preserves it.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/reference/cli.md` and possibly `engineering/specs/workspace-lifecycle.md` if the intended behavior remains rewrite-only.

### Resolution

Closed by updating `xcind-workspace init` so re-running an existing workspace with `--name` and/or `--proxy-domain` performs targeted updates to `XCIND_WORKSPACE` and `XCIND_PROXY_DOMAIN` while preserving unrelated existing workspace configuration. Added regression coverage for preserving `XCIND_ADDITIONAL_CONFIG_FILES` during a flagged re-init.

Validation: `make check`

## CLI-ENTRY-004: `xcind-proxy init --help` still names legacy `docker-compose.yaml` output

**Priority**: `P3`
**Status**: Closed
**Source**: `bin/xcind-proxy:424`
**Area**: CLI entrypoints

### Behavior Observed

`xcind-proxy init --help` says it creates `config.sh, docker-compose.yaml, Traefik config`. Current implementation writes `compose.yaml` under the proxy state directory, with legacy `docker-compose.yaml` paths retained only as migration fallbacks.

### Expected Behavior

CLI help should name `compose.yaml` to match current generated files and the engineering CLI reference.

### Impact

Low-risk user confusion when inspecting generated proxy files.

### Recommended Fix

Change the init help line to say `config.sh, compose.yaml, Traefik config`.

### Tests

- Update the proxy help assertion in `test/test-xcind-proxy.sh` to cover the current filename.
- Verify with `make check`.

### Engineering Docs

- No engineering doc update required because `engineering/reference/cli.md` already names `compose.yaml`.

### Resolution

Closed by updating `xcind-proxy init --help` to name `compose.yaml` instead of legacy `docker-compose.yaml`, with proxy help coverage asserting the current filename and rejecting the legacy one.

Validation: `make check`.

## CLI-ENTRY-DOC-001: Proxy init config overwrite semantics differ between spec and implementation

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-proxy:138`
**Document Source**: `engineering/specs/proxy-infrastructure.md`

### Current Document Claim

The proxy infrastructure spec says `xcind-proxy init` creates `config.sh` only if it does not exist and never overwrites user config.

### Actual Implementation Behavior

The CLI init path sources any existing config, applies CLI flag overrides, calls `__xcind-proxy-write-config`, and therefore rewrites `config.sh` on each init invocation while preserving known current values as defaults.

### Authority Decision

Code correct, docs stale. The CLI reference and configuration schema already describe set-and-persist / always-regenerated behavior.

### Proposed Documentation Update

Update `engineering/specs/proxy-infrastructure.md` to say `config.sh` is regenerated from known `XCIND_PROXY_*` values, with existing known values used as defaults and CLI flags persisted.

### Related Finding

None.

### Resolution

Closed by updating the proxy infrastructure spec to document that `xcind-proxy init` sources existing known values, applies CLI flag overrides, and regenerates `config.sh` on each invocation. The spec now also distinguishes CLI init from the lower-level auto-init helper, which only creates missing config before regenerating state files.

Validation: `make check`.

## CLI-ENTRY-DOC-002: Project layout omits current entrypoints and libraries

**Status**: Closed
**Layer**: Implementation
**Implementation Source**: `bin/xcind-workspace:1`
**Document Source**: `engineering/implementation/project-layout.md`

### Current Document Claim

The implementation layout shows only three executables (`xcind-compose`, `xcind-config`, `xcind-proxy`) and a small subset of `lib/xcind` files.

### Actual Implementation Behavior

The maintained executable set includes `xcind-workspace` and `xcind-application`, and the library set includes app identity, assigned ports, bootstrap, completions, host gateway, registry, and other installed files.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Refresh the tree in `engineering/implementation/project-layout.md` to match the current installed source map or replace the brittle tree with a shorter responsibility table.

### Related Finding

None.

### Resolution

Closed by replacing the brittle directory tree in `engineering/implementation/project-layout.md` with responsibility tables covering the current top-level areas, all five installed entrypoints, and the installed shared libraries. The built-in hook list was also refreshed to include current app identity, host gateway, and assigned-port hooks.

Validation: `make check`.

## CLI-ENTRY-DOC-003: Configuration schema still says there are no registries

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-workspace:679`
**Document Source**: `engineering/specs/configuration-schemas.md`

### Current Document Claim

The stateless configuration rationale says there are no state files, manifests, or registries.

### Actual Implementation Behavior

Xcind currently maintains `proxy/assigned-ports.tsv` and `workspaces.tsv`, and `xcind-workspace list --prune` rewrites the workspace registry.

### Authority Decision

Code correct, docs stale. `engineering/specs/workspace-lifecycle.md` already documents these state files.

### Proposed Documentation Update

Update `engineering/specs/configuration-schemas.md` to distinguish declarative configuration from narrow runtime state and link to the workspace lifecycle state section.

### Related Finding

None.

### Resolution

Closed by updating the configuration schemas spec to distinguish declarative
configuration from Xcind-owned runtime state and generated artifacts. The spec
now lists `workspaces.tsv`, `proxy/assigned-ports.tsv`, Docker runtime state,
and generated files separately from user-authored configuration, and links to
the workspace lifecycle state section for the state-file contract.

Validation: `make check`.

## CLI-ENTRY-DOC-004: Context detection quick reference has stale `xcind-config` no-arg behavior

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-config:208`
**Document Source**: `engineering/specs/context-detection.md`

### Current Document Claim

The context-detection quick reference says bare `xcind-config` shows JSON output with `appRoot`.

### Actual Implementation Behavior

Bare `xcind-config` sets help mode when no action is provided. JSON output requires `xcind-config --json`.

### Authority Decision

Code correct, docs stale. The CLI reference documents the same no-argument help behavior as the implementation.

### Proposed Documentation Update

Change the quick reference to `xcind-config --json` for JSON output with `appRoot`, leaving bare `xcind-config` as help.

### Related Finding

None.

### Resolution

Closed by updating the context-detection quick reference so bare `xcind-config` is shown as help and `xcind-config --json` is documented as the JSON-output-with-`appRoot` form, matching `bin/xcind-config` no-action handling and `engineering/reference/cli.md`.

Validation: `make check`.
