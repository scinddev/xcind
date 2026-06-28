# ADR-0018: Service-Discovery Environment Variable Injection

**Status**: Accepted

## Context

Xcind generates an export's hostname/URL information as Docker **labels**
(`xcind.export.*.host`, `xcind.apex.host`, `xcind.apex.url`) and, in workspace
mode, as DNS network aliases. Labels are discoverable by external tooling that
inspects containers, but **application code inside a container had no way to
read its own export hostnames, ports, or URLs at runtime** — it had to hardcode
them or duplicate the naming convention.

The upstream Scind project specced a solution: inject `SCIND_*` service-discovery
variables into each container's `environment:`. Xcind's docs already *promised*
this (`specs/README.md`, `specs/naming-conventions.md` told app authors to "use
the injected `XCIND_*` variables"), but no hook produced them — the linked
`environment-variables.md` only documented labels. This ADR closes that gap by
porting Scind's design, with refinements learned from building the Xcind POC.

## Decision

Add a `xcind-discovery-hook` (GENERATE) that emits `compose.discovery.yaml`: an
inline `environment:` block of `XCIND_{APP}_{EXPORT}_{SUFFIX}` variables attached
to every service of the current app. Application and export name segments are
independently env-safed (hyphens → underscores, uppercased).

**Variables** (full schema in [Environment Variables](../specs/environment-variables.md)):

- **Proxied exports** — `_HOST`, `_PORT` (proxy entrypoint port), `_SCHEME`,
  `_URL`; plus `_HTTPS_*` / `_HTTP_*` when both schemes serve. Base variables
  default to HTTPS.
- **Apex** (first proxied export) — `XCIND_{APP}_APEX_HOST/_PORT/_SCHEME/_URL`.
- **Assigned exports** — `_HOST` (in-network host), `_PORT` (container port),
  `_HOST_PORT` (allocated host port).
- **Workspace mode** — `XCIND_WORKSPACE_NAME`.

The hook reuses the existing single-source-of-truth helpers so generated values
stay byte-identical with the proxy labels: `__xcind-proxy-export-hostname`,
`__xcind-proxy-preferred-scheme`, `__xcind-proxy-apex-for-app`, and
`__xcind-assigned-json-for-app`.

### Divergences from Scind

1. **Positional apex, not `primary: true`.** Scind ([ADR-0013](https://github.com/scinddev/scind))
   marks the apex export with an explicit `primary: true` field, because its
   exports are unordered YAML maps. Xcind's exports are an ordered bash array, so
   the apex is simply the first `proxied` export (see
   [ADR-0017](0017-apex-url-reporting.md)). No new field is introduced.

2. **Assigned exports gain `_HOST_PORT`.** Scind pairs an assigned export's
   in-network `_HOST` with a single `_PORT`. Xcind splits this: `_HOST` + `_PORT`
   describe the in-network (container-to-container) pair, and a new `_HOST_PORT`
   carries the host-published port for host-side access. Containers reach the
   service in-network; the host port is reachable via `host.docker.internal`.

3. **In-network `_HOST` is mode-aware.** The `{app}-{service}` alias exists only
   on the workspace-internal network. In standalone mode there is no such alias,
   so `_HOST` is the compose service name (reachable on Compose's default
   network).

4. **Own-app scope (v1).** Scind injects every service's discovery variables into
   every container in the workspace. Xcind runs per-application, so v1 injects
   only the current app's exports into its own containers — no workspace-registry
   or cross-app reads. The variable shape is forward-compatible with a later
   workspace-wide v2.

### Hook registration

Registered **last** in `XCIND_HOOKS_GENERATE` (after `xcind-assigned-hook`, so
assigned host ports are already allocated) and also in `XCIND_HOOKS_ALWAYS`:
because `_HOST_PORT` embeds live-allocated host ports that live outside the cache
SHA inputs, a cached replay could otherwise serve a stale value disagreeing with
the re-run `compose.assigned.yaml`. Being merged last also gives the discovery
block precedence on `environment:` key collisions.

## Consequences

### Positive

- Applications read their own hostnames/ports/URLs from the environment — no
  hardcoding, no duplicating the naming convention. The long-standing doc promise
  is now real.
- Reuses existing helpers, so env values never drift from the proxy labels.
- `_HOST_PORT` makes assigned services reachable from the host, which the
  in-network-only Scind design did not express.

### Negative

- One more generated overlay and an `XCIND_HOOKS_ALWAYS` member (re-runs each
  invocation); the hook is kept side-effect-free and cheap to bound the cost.
- Discovery variables for an export removed from `XCIND_PROXY_EXPORTS` can linger
  until the assigned-port state is cleaned, since assigned discovery reads the
  shared state file — the same staleness window as the existing introspection.

### Neutral

- `yq` missing → soft-skip (containers still run, without the convenience
  variables); `jq` missing → assigned variables are omitted while proxied
  variables are unaffected.

## Related Documents

- [Environment Variables](../specs/environment-variables.md) — Full variable schema
- [Generated Override Files](../specs/generated-override-files.md) — `compose.discovery.yaml`
- [Hook Lifecycle](../specs/hook-lifecycle.md) — GENERATE / ALWAYS semantics
- [ADR-0017: Apex URL Reporting](0017-apex-url-reporting.md) — Positional apex rule
- [ADR-0007: Port Type System](0007-port-type-system.md) — Proxied vs. assigned exports
