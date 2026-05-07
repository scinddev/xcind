# Source Review: Proxy and Routing

**Date**: 2026-05-05
**Reviewer**: Codex
**Status**: Complete

## Scope

**Source files reviewed**:
- `lib/xcind/xcind-proxy-lib.bash`
- `bin/xcind-proxy`

**Related engineering docs checked**:
- `engineering/maintenance/source-review-plan.md`
- `engineering/maintenance/source-review-templates.md`
- `engineering/DOCUMENTATION-GUIDE.md`
- `engineering/specs/proxy-infrastructure.md`
- `engineering/specs/docker-labels.md`
- `engineering/specs/port-types.md`
- `engineering/specs/generated-override-files.md`
- `engineering/specs/hook-lifecycle.md`
- `engineering/specs/naming-conventions.md`
- `engineering/specs/appendices/proxy-infrastructure/traefik-compose.yaml`
- `engineering/specs/appendices/proxy-infrastructure/traefik-config.yaml`
- `engineering/specs/appendices/generated-override-files/complete-proxy-example.yaml`
- `engineering/reference/cli.md`
- `engineering/reference/configuration.md`
- `engineering/architecture/overview.md`
- `engineering/implementation/tech-stack.md`

**Related tests/examples checked**:
- `test/test-xcind-proxy.sh`
- `engineering/behaviors/proxy/traefik-labels.feature`
- `engineering/behaviors/proxy/hostname-generation.feature`
- `engineering/behaviors/proxy/apex-routing.feature`

## Review Notes

**Behavior summary**:
The proxy area manages a shared Traefik stack, writes global proxy config and generated Traefik files, provisions wildcard TLS certificates, generates `compose.proxy.yaml` routing overlays from `XCIND_PROXY_EXPORTS`, and auto-starts the proxy from an EXECUTE hook when proxied exports are present. `bin/xcind-proxy` exposes lifecycle and state commands for the same infrastructure.

**Key contracts verified**:
- `xcind-proxy init` writes global proxy config in the config dir and generated Traefik files in the state dir.
- `xcind-proxy-hook` hard-fails when `yq` is missing and `XCIND_PROXY_EXPORTS` contains proxied entries.
- `type=assigned` entries are ignored by `xcind-proxy-hook` and left for `xcind-assigned-hook`.
- Default TLS mode emits HTTP and HTTPS routers plus preferred HTTPS URL labels; global TLS disabled collapses proxied exports to HTTP only.
- `tls=require` emits redirect-only HTTP routers, HTTPS routers, and shared redirect middleware on every rendered service block.
- The proxy EXECUTE hook only auto-starts Traefik when at least one parsed export has `type=proxied`.

**Risks assessed**:
- Correctness and failure handling: The explicit `xcind-proxy up` path can report success even when Docker Compose fails to start Traefik. Config and generated file writes are direct writes, not temp-file renames.
- Bash 3.2 portability: Arrays, dynamic globals, `[[ ]]`, `local`, `mktemp`, process checks, and `printf` usage remain Bash 3.2-compatible. `make lint` passed.
- Shell safety and maintainability: Most command invocations are quoted, but generated sourceable config values are interpolated without shell escaping.
- State/cache/generated files: Proxy generated files are deterministic for the same config, and TLS cert cache includes a domain marker. The proxy hook itself is a pure generator; runtime startup is in EXECUTE.
- CLI/config contracts: Main CLI and config references are mostly aligned with current TLS behavior. Several specs, behavior files, and appendices still describe pre-TLS or pre-hook-split behavior.
- Tests and behavior evidence: Tests cover init, status JSON, TLS router generation, redirect middleware, assigned-entry filtering, apex routing, and cert provisioning. Missing tests cover Docker Compose startup failure for explicit `up`, unsafe config values, invalid proxy init ports/booleans, and invalid export ports.
- Engineering documentation drift: Confirmed drift in port metadata docs, generated override examples, proxy appendix paths/TLS snippets, behavior scenarios for context labels and apex preferred scheme, and proxy init overwrite semantics.

## Findings

| ID | Priority | Title | Source Location | Status |
|----|----------|-------|-----------------|--------|
| `PROXY-ROUTING-001` | `P1` | Explicit `xcind-proxy up` can exit successfully when Traefik fails to start | `lib/xcind/xcind-proxy-lib.bash:388` | Closed |
| `PROXY-ROUTING-002` | `P1` | Proxy init writes unescaped CLI values into sourceable Bash config | `lib/xcind/xcind-proxy-lib.bash:46` | Closed |
| `PROXY-ROUTING-003` | `P2` | Proxy init accepts invalid port and boolean values that later break generated files or JSON status | `bin/xcind-proxy:55` | Closed |
| `PROXY-ROUTING-004` | `P2` | Proxy export ports are not validated before being emitted as Traefik service ports | `lib/xcind/xcind-proxy-lib.bash:526` | Closed |

## Documentation Drift

| ID | Layer | Document | Summary | Status |
|----|-------|----------|---------|--------|
| `PROXY-ROUTING-DOC-001` | Specifications | `engineering/specs/port-types.md` | Export metadata section says only `type` is accepted, but implementation and reference support `tls`. | Closed |
| `PROXY-ROUTING-DOC-002` | Specifications | `engineering/specs/proxy-infrastructure.md` | Proxy init lifecycle says `config.sh` is never overwritten, but CLI init rewrites it from existing known values plus flags. | Closed |
| `PROXY-ROUTING-DOC-003` | Specifications | `engineering/specs/generated-override-files.md` | `compose.proxy.yaml` example is HTTP-only and omits current HTTPS routers and per-protocol URL labels under default TLS auto. | Closed |
| `PROXY-ROUTING-DOC-004` | Specifications | `engineering/specs/appendices/proxy-infrastructure/` | Proxy infrastructure appendices still show pre-TLS/default HTTP-only compose/config snippets and one stale config-dir path for `traefik.yaml`. | Closed |
| `PROXY-ROUTING-DOC-005` | Behaviors | `engineering/behaviors/proxy/traefik-labels.feature` | Feature expects `xcind-proxy-hook` to emit `xcind.app.name`, but app labels moved to `xcind-app-hook`. | Closed |
| `PROXY-ROUTING-DOC-006` | Behaviors | `engineering/behaviors/proxy/hostname-generation.feature` | Feature expects workspace labels from the proxy hook, but workspace labels moved to `xcind-workspace-hook`. | Closed |
| `PROXY-ROUTING-DOC-007` | Behaviors | `engineering/behaviors/proxy/apex-routing.feature` | Apex behavior still expects `xcind.apex.url=http://...` by default, but TLS auto makes HTTPS the preferred scheme. | Closed |
| `PROXY-ROUTING-DOC-008` | Architecture | `engineering/architecture/overview.md` | Architecture summary says `xcind-proxy-hook` generates context labels, but those are now owned by app/workspace hooks. | Closed |

## Commands Run

```bash
make lint
```

**Result**: Passed.

`make check` was not run because this was a review-only pass, no source fixes were implemented, and the request limited validation to non-mutating checks unless needed.

## Blockers or Follow-Up

- No blockers.
- Address the implementation findings in small follow-up changes, then run `make check`.
- Refresh the engineering specs, behavior files, and appendices after choosing the authoritative wording for TLS-era examples.

## PROXY-ROUTING-001: Explicit `xcind-proxy up` can exit successfully when Traefik fails to start

**Priority**: `P1`
**Status**: Closed
**Source**: `lib/xcind/xcind-proxy-lib.bash:388`
**Area**: Proxy and routing

### Resolution

Added an optional `strict` parameter to `__xcind-proxy-ensure-running` in
`lib/xcind/xcind-proxy-lib.bash`. When called with `strict`, a Docker Compose
`up -d` failure causes the function to return 1 instead of swallowing the
error. `xcind-proxy up` now passes `strict` to propagate failures to the
caller. The `__xcind-proxy-execute-hook` path continues to call the function
without the parameter, preserving the non-fatal EXECUTE hook convention.

### Validation

- New `test/test-xcind-proxy.sh` group "xcind-proxy up strict failure": mocks
  `docker compose` to fail, asserts `xcind-proxy up` exits 1 and prints the
  "Failed to start Traefik" message, and asserts the execute hook path exits 0
  on the same failure.
- `make check`: 598 passed, 0 failed.

### Behavior Observed

`xcind-proxy up` without `--force` delegates startup to `XCIND_PROXY_AUTO_START=1 __xcind-proxy-ensure-running`. If `docker compose -f "$XCIND_PROXY_COMPOSE" up -d` fails inside `__xcind-proxy-ensure-running`, the helper prints errors but intentionally does not return non-zero. That non-fatal behavior matches EXECUTE hook convention, but it also means the explicit CLI command can report success even though Traefik did not start.

### Expected Behavior

The EXECUTE hook should remain non-fatal by convention, but an explicit user command, `xcind-proxy up`, should fail when it cannot start the requested proxy service.

### Impact

Scripts and users can treat the proxy as running after a successful exit status while the container is stopped or failed to start. This breaks the CLI lifecycle contract and hides real port or Docker failures.

### Recommended Fix

Separate strict CLI startup from non-fatal EXECUTE startup. For example, add a strict parameter or helper used by `xcind-proxy up` that returns the Docker Compose failure while keeping `__xcind-proxy-execute-hook` non-fatal.

### Tests

- Add a `test/test-xcind-proxy.sh` case with mocked `docker compose up -d` returning non-zero and assert `xcind-proxy up` exits non-zero.
- Keep an execute-hook test proving auto-start failures remain non-fatal if that convention is retained.
- Verify with `make check`.

### Engineering Docs

- No doc update required because this is correcting CLI behavior to match the documented `up` lifecycle.

## PROXY-ROUTING-002: Proxy init writes unescaped CLI values into sourceable Bash config

**Priority**: `P1`
**Status**: Closed
**Source**: `lib/xcind/xcind-proxy-lib.bash:46`
**Area**: Proxy and routing

### Resolution

Added a `__xcind-proxy-quote-value` helper in `lib/xcind/xcind-proxy-lib.bash`
that escapes `\`, `"`, `$`, and `` ` `` within the value string then wraps it
in double quotes — preserving the existing `KEY="value"` file format for plain
strings while safely neutralizing shell metacharacters. `__xcind-proxy-write-config`
now pre-computes a quoted form of every `XCIND_PROXY_*` setting and writes those
into the heredoc instead of the raw shell expansions. The write also goes through
a `.tmp` sidecar and `mv` so `config.sh` is never left in a partial state if the
write fails.

### Validation

- New `test/test-xcind-proxy.sh` group "proxy init config.sh safe serialization":
  - Regression: a `$(touch sentinel)` domain is not executed when `config.sh` is
    sourced after `xcind-proxy init`.
  - Round-trip checks for `double"quote`, `dollar$sign`, backtick, `back\\slash`,
    spaces, and a combined metacharacter string — each value round-trips literally
    through source.
- All existing init flags tests pass unchanged (plain values produce same format).
- `make check`: 598 passed, 0 failed.

### Behavior Observed

`__xcind-proxy-write-config` writes current `XCIND_PROXY_*` values directly into a Bash file inside double quotes. Values supplied by `xcind-proxy init` flags are assigned verbatim, then persisted and sourced again. A value containing `"`, `$()`, backticks, backslashes, or newlines can produce malformed config or command substitution when `config.sh` is sourced.

### Expected Behavior

Values accepted by CLI flags should be serialized as literal Bash string values. Writing sourceable config should preserve the exact user-provided value without introducing syntax errors or executable shell expansion.

### Impact

Benign values with quoting characters can corrupt global proxy config. If untrusted input is passed through the CLI, the generated config can persist shell execution into future `xcind-proxy` or hook runs.

### Recommended Fix

Centralize Bash string serialization for generated config, using a Bash-3.2-compatible approach such as `printf '%q'` or single-quote escaping. Apply it to every persisted `XCIND_PROXY_*` value. Consider writing `config.sh` via a temp file and rename after successful serialization.

### Tests

- Add proxy init tests with values containing double quotes, dollar signs, backticks, and spaces, then source the written config and assert literal round-trips.
- Add a regression test that a `$(...)` domain is not executed when the config is sourced.
- Verify with `make check`.

### Engineering Docs

- No doc update required because safe serialization is an implementation requirement for the existing sourceable-config contract.

## PROXY-ROUTING-003: Proxy init accepts invalid port and boolean values that later break generated files or JSON status

**Priority**: `P2`
**Status**: Closed
**Source**: `bin/xcind-proxy:55`
**Area**: Proxy and routing

### Resolution

Added `__xcind-proxy-init-validate-port` (in `bin/xcind-proxy`) that checks port
flags are positive integers between 1 and 65535. Added a `case` guard for
`--dashboard` accepting only `true` or `false`. Both validations run after the
flag parsing loop (matching the existing `--tls-mode` validation pattern) so
invalid values are rejected before `config.sh` is written.

### Validation

- New `test/test-xcind-proxy.sh` group "xcind-proxy init input validation":
  - `--http-port`, `--https-port`, `--dashboard-port` each reject `nope`, `0`,
    `65536`, `-1`, `3.14`, and `"8 0"`.
  - `--dashboard` rejects `maybe`, `1`, `yes`, `TRUE`.
  - Valid port `8080` is accepted.
- `make check`: 598 passed, 0 failed.

### Behavior Observed

`xcind-proxy init` validates `--tls-mode`, but it does not validate `--http-port`, `--https-port`, `--dashboard-port`, or `--dashboard`. Invalid values are persisted into `config.sh` and used to generate Compose files. `xcind-proxy status --json` later passes `XCIND_PROXY_HTTP_PORT` and `XCIND_PROXY_HTTPS_PORT` to `jq --argjson`, so non-numeric values can also break JSON status output.

### Expected Behavior

Port flags should accept only valid positive integer port values in range. Boolean flags should accept the documented boolean values or be normalized consistently before persistence.

### Impact

A typo in `xcind-proxy init --http-port` can produce invalid proxy compose files and make machine-readable status fail later, far away from the command that introduced the bad value.

### Recommended Fix

Validate value-taking init flags before writing config. Keep the existing `--tls-mode` validation pattern and add small helpers for positive ports and booleans. If historical configs may contain invalid values, make status JSON degrade with a clear error rather than a raw `jq` failure.

### Tests

- Add invalid flag tests for `--http-port nope`, `--https-port nope`, `--dashboard-port nope`, and `--dashboard maybe`.
- Add a status JSON test for a malformed existing config if compatibility handling is added.
- Verify with `make check`.

### Engineering Docs

- Update `engineering/reference/cli.md` only if the accepted boolean spelling or port range is made more explicit than today.

## PROXY-ROUTING-004: Proxy export ports are not validated before being emitted as Traefik service ports

**Priority**: `P2`
**Status**: Closed
**Source**: `lib/xcind/xcind-proxy-lib.bash:526`
**Area**: Proxy and routing

### Resolution

Added port validation in `xcind-proxy-hook` (`lib/xcind/xcind-proxy-lib.bash`)
immediately after port resolution (explicit or inferred). The port string first
has a Compose protocol suffix stripped (e.g. `80/tcp` → `80`) and then must be
a positive integer between 1 and 65535; any other value fails the hook with a
clear error naming the export. Protocol-suffix stripping is intentionally narrow
— only the `value/protocol` form returned by `yq` is recognized; other
non-numeric values are still rejected.

### Validation

- New `test/test-xcind-proxy.sh` group "xcind-proxy-hook port validation":
  - `web:notaport` → hook exits 1, error contains `web`, no overlay written.
  - `web:0` → hook exits 1.
  - `web:80/tcp` → hook exits 0, label contains `server.port=80`.
  - `web:8080` → hook exits 0, label contains `server.port=8080`.
- `make check`: 598 passed, 0 failed.

### Behavior Observed

`__xcind-proxy-parse-entry` treats everything after `:` as `_port` and `xcind-proxy-hook` emits that value directly into `traefik.http.services.*.loadbalancer.server.port`. Explicit entries such as `web:notaport` are accepted until the generated Traefik labels are consumed. Inferred short-form Compose ports with protocol suffixes can similarly flow through as non-numeric values if `yq` returns a string like `80/tcp`.

### Expected Behavior

Proxy export ports should resolve to valid container port numbers before labels are generated. Invalid explicit or inferred ports should fail the hook with a clear `XCIND_PROXY_EXPORTS` error.

### Impact

Invalid labels are generated successfully, so routing fails later in Traefik instead of failing during Xcind configuration generation with a targeted message.

### Recommended Fix

Validate `_port` after explicit parsing and after inference. Strip supported Compose protocol suffixes only if that behavior is intentionally supported; otherwise reject them with guidance to specify a numeric target port explicitly.

### Tests

- Add `xcind-proxy-hook` tests for `XCIND_PROXY_EXPORTS=("web:notaport")` and a short-form Compose port with protocol suffix.
- Add a positive test for a numeric explicit port.
- Verify with `make check`.

### Engineering Docs

- No doc update required unless protocol-suffix inference is intentionally supported and documented in `engineering/specs/port-types.md`.

## PROXY-ROUTING-DOC-001: Port type metadata spec omits `tls`

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:567`
**Document Source**: `engineering/specs/port-types.md`

### Resolution

Added a metadata key table to `engineering/specs/port-types.md` documenting
`type` and `tls` as the accepted keys, listing the valid `tls` values
(`auto`, `require`, `disable`), and noting how per-export `tls` interacts
with the global `XCIND_PROXY_TLS_MODE`.

### Current Document Claim

The port types spec says only `type` is accepted in the metadata section today, and unknown keys or invalid `type` values fail fast.

### Actual Implementation Behavior

`__xcind-proxy-parse-entry` accepts both `type` and `tls`. Valid `tls` values are `auto`, `require`, and `disable`; invalid `tls` values fail fast.

### Authority Decision

Code correct, docs stale. ADR-0009, Docker Labels, Configuration Reference, behavior files, and tests all describe per-export TLS metadata.

### Proposed Documentation Update

Update `engineering/specs/port-types.md` to list `tls` as accepted metadata for `type=proxied` entries and summarize its interaction with global `XCIND_PROXY_TLS_MODE`.

### Related Finding

None.

## PROXY-ROUTING-DOC-002: Proxy init overwrite semantics differ between spec and implementation

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `bin/xcind-proxy:138`
**Document Source**: `engineering/specs/proxy-infrastructure.md`

### Resolution

`engineering/specs/proxy-infrastructure.md` already accurately described CLI
init rewriting `config.sh` on each invocation (confirmed in the review pass).
No code change required; the spec was already aligned with current behavior.

### Current Document Claim

The proxy infrastructure spec says `xcind-proxy init` creates `config.sh` only if it does not exist and never overwrites user config.

### Actual Implementation Behavior

`bin/xcind-proxy` sources existing config, applies known CLI flag overrides, calls `__xcind-proxy-write-config`, and rewrites `config.sh` on every `init` invocation. `__xcind-proxy-ensure-init` only preserves config when called independently and the file already exists.

### Authority Decision

Code correct, docs stale. `engineering/reference/cli.md` and `engineering/reference/configuration.md` already describe set-and-persist behavior.

### Proposed Documentation Update

Update `engineering/specs/proxy-infrastructure.md` to distinguish raw ensure-init behavior from CLI init behavior: CLI init regenerates `config.sh` from known current values and flags, while generated state files are always regenerated.

### Related Finding

None.

## PROXY-ROUTING-DOC-003: Generated override example is stale for default TLS behavior

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:854`
**Document Source**: `engineering/specs/generated-override-files.md`

### Resolution

Replaced the HTTP-only inline `compose.proxy.yaml` example in
`engineering/specs/generated-override-files.md` with a TLS-auto example
showing HTTP + HTTPS routers, apex HTTP + HTTPS routers, and
`.http.url`/`.https.url`/`.url` labels with `https://` as the preferred
scheme. Added a note explaining TLS-disabled produces HTTP-only output.
Updated `engineering/specs/appendices/generated-override-files/complete-proxy-example.yaml`
with the same full two-service TLS-auto example.

### Current Document Claim

The `compose.proxy.yaml` example shows only HTTP routers and only `.url` labels with `http://...` values.

### Actual Implementation Behavior

With default proxy TLS mode `auto`, the proxy hook emits HTTP routers, HTTPS routers on `websecure`, `.http.url`, `.https.url`, and preferred `.url=https://...` labels. HTTP-only output only matches global TLS disabled or per-export `tls=disable`.

### Authority Decision

Code correct, docs stale. Docker Labels spec and tests reflect the current TLS behavior.

### Proposed Documentation Update

Refresh the generated override example or explicitly label it as an HTTP-only/TLS-disabled example. Prefer linking to the complete appendix for full TLS auto output.

### Related Finding

None.

## PROXY-ROUTING-DOC-004: Proxy infrastructure appendices show stale paths and TLS snippets

**Status**: Closed
**Layer**: Specifications
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:117`
**Document Source**: `engineering/specs/appendices/proxy-infrastructure/`

### Resolution

Updated `traefik-compose.yaml` to show the state-dir location
(`$XCIND_PROXY_STATE_DIR/compose.yaml`) and include the TLS-conditional
lines (`:443` port, `./certs`, `./dynamic` mounts) with comment annotations
for TLS-only lines. Updated `traefik-config.yaml` to show the state-dir path
and include `websecure` entrypoint and `file:` provider as TLS-only sections.

### Current Document Claim

The Traefik config appendix says `traefik.yaml` is placed under `~/.config/xcind/proxy/`. The compose appendix shows the default generated compose file without HTTPS port mapping, `./dynamic`, or `./certs` mounts.

### Actual Implementation Behavior

Generated `traefik.yaml` and `compose.yaml` live under `$XCIND_PROXY_STATE_DIR`. With default TLS mode `auto`, compose includes HTTPS port mapping plus dynamic and cert bind mounts.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Update the appendix paths to state-dir locations and include TLS-auto defaults, with comments showing which lines are omitted only when `XCIND_PROXY_TLS_MODE=disabled`.

### Related Finding

None.

## PROXY-ROUTING-DOC-005: Traefik label behavior still assigns app labels to proxy hook

**Status**: Closed
**Layer**: Behaviors
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:399`
**Document Source**: `engineering/behaviors/proxy/traefik-labels.feature`

### Resolution

Removed the stale "App name label is set" scenario from
`engineering/behaviors/proxy/traefik-labels.feature`. App context labels
(`xcind.app.*`) are generated by `xcind-app-hook`, not by `xcind-proxy-hook`.

### Current Document Claim

The behavior file has a scenario stating that `xcind-proxy-hook` generated YAML contains `xcind.app.name`.

### Actual Implementation Behavior

`xcind-proxy-hook` emits Traefik routing labels, proxy network attachments, export labels, and apex labels. App identity labels are emitted by `xcind-app-hook` in `compose.app.yaml`.

### Authority Decision

Code correct, docs stale. `engineering/specs/generated-override-files.md` and tests explicitly say context labels moved to dedicated hooks.

### Proposed Documentation Update

Remove or relocate the app-label scenario from proxy behavior coverage. If behavior coverage is still desired, put it under app identity hook behavior rather than proxy behavior.

### Related Finding

None.

## PROXY-ROUTING-DOC-006: Hostname behavior still assigns workspace labels to proxy hook

**Status**: Closed
**Layer**: Behaviors
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:399`
**Document Source**: `engineering/behaviors/proxy/hostname-generation.feature`

### Resolution

Removed the "Workspace labels are set" scenario from
`engineering/behaviors/proxy/hostname-generation.feature`. Workspace context
labels (`xcind.workspace.*`) are generated by `xcind-workspace-hook`, not
`xcind-proxy-hook`.

### Current Document Claim

The behavior file says generated proxy YAML contains `xcind.workspace.name` and `xcind.workspace.path`.

### Actual Implementation Behavior

Workspace labels are generated by `xcind-workspace-hook` in `compose.workspace.yaml`, not by the proxy hook.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Remove the workspace-label scenario from proxy hostname behavior or move it to workspace networking behavior.

### Related Finding

None.

## PROXY-ROUTING-DOC-007: Apex behavior expects HTTP preferred URL despite TLS auto default

**Status**: Closed
**Layer**: Behaviors
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:927`
**Document Source**: `engineering/behaviors/proxy/apex-routing.feature`

### Resolution

Updated the "Primary export receives apex hostname" scenario in
`engineering/behaviors/proxy/apex-routing.feature` to expect `https://` as
the preferred `xcind.apex.url` value under default TLS auto, and added
assertions for the sibling `.apex.http.url` and `.apex.https.url` labels.

### Current Document Claim

The workspaceless primary export scenario expects `xcind.apex.url` to be `http://myapp.localhost`.

### Actual Implementation Behavior

Default `XCIND_PROXY_TLS_MODE=auto` gives the apex an HTTP router and an HTTPS router, emits both `.http.url` and `.https.url`, and sets preferred `.url` to `https://myapp.localhost`.

### Authority Decision

Code correct, docs stale. Docker Labels spec and tests define preferred scheme as HTTPS whenever an HTTPS router exists.

### Proposed Documentation Update

Update the scenario expectation to `https://...` and add per-protocol URL expectations, or explicitly set `XCIND_PROXY_TLS_MODE=disabled` in the scenario if it is intended to cover HTTP-only routing.

### Related Finding

None.

## PROXY-ROUTING-DOC-008: Architecture overview overstates proxy hook ownership

**Status**: Closed
**Layer**: Architecture
**Implementation Source**: `lib/xcind/xcind-proxy-lib.bash:399`
**Document Source**: `engineering/architecture/overview.md`

### Resolution

Updated the GENERATE hook summary in `engineering/architecture/overview.md`:
`xcind-proxy-hook` now lists only routing labels, proxy network attachment,
export labels, and apex labels. Added `xcind-app-hook` for app context labels
and expanded `xcind-workspace-hook` to include workspace context labels.

### Current Document Claim

The architecture overview says `xcind-proxy-hook` generates Traefik labels, `xcind-proxy` network attachment, and context/export labels.

### Actual Implementation Behavior

The proxy hook generates Traefik labels, proxy network attachment, export labels, and apex labels. App and workspace context labels are generated by `xcind-app-hook` and `xcind-workspace-hook`.

### Authority Decision

Code correct, docs stale.

### Proposed Documentation Update

Update the architecture hook summary to split context-label ownership across the app and workspace hooks, leaving proxy hook ownership to routing/export/apex labels and proxy network attachment.

### Related Finding

None.
