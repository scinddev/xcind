# ADR-0015: Application Export Introspection and Command Placement

**Status**: Accepted

> The core decision — the `ports`/`urls`/`exports` subcommands on
> `xcind-application`, backed by the `xcind-config --json` contract — is
> implemented and shipped (PR #69). The complementary *global* `xcind-proxy
> urls` view described under "Follow-up" remains proposed and out of this ADR's
> accepted scope.

## Context

Xcind computes a lot of per-application routing state — which host port each
`type=assigned` export was allocated, and which URL each `type=proxied` export
is reachable at — but until now there was no ergonomic way to *read* it back.
Assigned host ports lived only in a TSV state file
(`~/.local/state/xcind/proxy/assigned-ports.tsv`); proxied URLs were only
emitted as `xcind.export.*` labels on running containers. Answering "what port
did `db` get?" or "what's the URL for `web`?" meant `docker inspect … | jq …`
gymnastics, or reading a state file by hand. Tooling (editor plugins, scripts,
CI) had no stable contract to consume.

PR #69 added three read-only introspection subcommands to `xcind-application`.
This ADR records that work and resolves the open question raised in review:
**should these commands live on `xcind-proxy` instead of (or in addition to)
`xcind-application`?**

### What we shipped

Three subcommands, all sharing the `[SERVICE] [DIR] [--json]` shape that
`xcind-application status` already uses:

```
xcind-application ports   [SERVICE] [DIR] [--json]   # assigned host ports
xcind-application urls    [SERVICE] [DIR] [--json]   # computed proxied URLs
xcind-application exports [SERVICE] [DIR] [--json]   # unified rich view
```

Design points:

- **Keyed by export name** — the canonical identity (matches the `{export}`
  slot in URL templates and the existing `assignedExports` contract). A
  positional `SERVICE` resolves by export name first, then falls back to the
  compose-service name.
- **`xcind-config --json` is the single source of truth.** A new
  `proxiedExports` map was added alongside the existing `assignedExports`,
  each keyed by export name. The three subcommands are *thin presenters* over
  that JSON — they hold no data-access logic of their own.
- **URLs are computed from config** (`XCIND_APP_URL_TEMPLATE`), not scraped
  from running containers, so they resolve even when nothing is up — symmetric
  with how `ports` reports persisted assignments.
- **Pipeable UX**: with a `SERVICE`, text output is the bare value
  (`PORT=$(xcind-application ports db)`); `--json` uses natural types (port →
  number, URL → string). Wrong-type lookups are *helpful* errors, e.g.
  `ports web` → `Try: xcind-application urls web` rather than "not found".
- **Shared helpers** `__xcind-proxy-export-hostname` and
  `__xcind-proxy-preferred-scheme` are now used by *both* the Traefik label
  generator (`xcind-proxy-hook`) and the introspection path, so generated
  labels and reported URLs cannot drift.

Hardening surfaced by the bash-version CI matrix:

- The introspection query deliberately does **not** request a generated docker
  compose configuration. It only reads the `assignedExports` / `proxiedExports`
  maps, both present in plain `xcind-config --json`. Requesting generation
  triggered the proxy execute path (TLS cert provisioning, proxy startup),
  which is both inappropriate for a read-only query and fails in constrained
  environments (CI containers without `mkcert`/`openssl`).
- `__xcind-application-query-config` now guards its optional-args expansion
  with `${arr[@]+"${arr[@]}"}` — Bash 3.2 errors on an unguarded empty-array
  expansion under `set -u`.
- A new test seam, `XCIND_ASSIGNED_LISTENERS_OVERRIDE`, lets callers supply the
  in-use port set instead of probing the host, so assigned-port allocation is
  deterministic regardless of what is bound locally (documented in
  `docs/reference/cli.md`; also useful for reserving ports).

## Decision

1. **Per-application introspection stays on `xcind-application`**, beside
   `status` and `list`. These commands answer "for *this* application, what are
   its ports/URLs?" — they resolve an app root from the cwd/`DIR`, which is
   exactly `xcind-application`'s scope.

2. **Do not move the commands to `xcind-proxy`.** See the analysis below; the
   short version is that `xcind-proxy` is the wrong scope (infrastructure /
   cross-app, not per-app) and the wrong domain for two of the three commands
   (assigned ports bypass the proxy entirely — ADR-0007).

3. **Placement is a presentation choice, not a data-ownership choice.** Because
   the data lives in the `xcind-config --json` contract, any command —
   including a future `xcind-proxy` view — can consume it without duplicating
   logic. We are not locked in.

4. **A complementary *global* view on `xcind-proxy` is a reasonable future
   addition, but is a different feature, not a move** (proposed, not yet
   scheduled). See "Follow-up" below.

## Analysis: `xcind-application` vs `xcind-proxy`

### Scope: these are app-scoped queries

| Command | Scope | Resolves from | Natural home |
|---|---|---|---|
| `xcind-application status` / `list` | one app / its workspace | cwd → app root | `xcind-application` |
| `xcind-application ports` / `urls` / `exports` | **one app** | cwd → app root | `xcind-application` |
| `xcind-proxy status` | **all apps** (global) | proxy state file | `xcind-proxy` |

`xcind-proxy` manages the Traefik proxy *itself* and already operates globally:
`xcind-proxy status [--json]` lists assigned ports across every app/workspace by
reading the shared TSV. The new commands answer a *per-app* question scoped to
where you're standing. Putting an app-scoped command on the infrastructure-level
tool would blur a scope boundary the CLI currently keeps clean.

### Domain: assigned ports are not a proxy concern

This is the decisive point. Per **ADR-0007 (Port Type System)**:

- `type=proxied` exports route through Traefik by hostname (`xcind-proxy-hook`).
- `type=assigned` exports **bind directly to a host port and never touch the
  proxy** (`xcind-assigned-hook`).

So of the three commands:

- **`ports`** reports *assigned* host ports — these bypass the proxy. Filing
  this under `xcind-proxy` would actively mislead: a `xcind-proxy ports`
  command would be reporting ports that, by design, do not go through the
  proxy.
- **`exports`** spans *both* types, so it cannot live exclusively under a
  proxy-only command without becoming a half-truth.
- **`urls`** is the only one whose domain genuinely *is* the proxy. Even so, it
  is still an app-scoped view, and splitting one of three sibling commands onto
  a different binary would fragment a coherent, consistent trio.

### Discoverability (the one real argument for `xcind-proxy`)

The counter-argument is that someone debugging "routing" might reach for
`xcind-proxy` first and not find `urls`. Mitigations already in place / cheap:

- `xcind-app` is a first-class alias, so `xcind-app urls` is short and
  app-oriented.
- `xcind-application --help` lists all three; per-subcommand `--help` explains
  the `SERVICE` resolution.
- A "see also" cross-reference between `xcind-proxy status` and
  `xcind-application urls` in the CLI reference closes the gap without moving
  code.

The discoverability win does not outweigh the scope/domain mismatch, especially
the assigned-ports-aren't-proxied problem.

### Follow-up: a *global* proxy view (proposed, optional)

If cross-app aggregation is wanted, the right shape is a **global** view on
`xcind-proxy`, distinct from the per-app commands:

- `xcind-proxy urls [--json]` — every *proxied* URL across all known/running
  apps. This is genuinely new (no existing command lists proxied URLs globally)
  and squarely in the proxy's domain.
- A global "ports" view would largely duplicate the existing `xcind-proxy
  status`, so it is not worth a separate command; if anything, `xcind-proxy
  status --json` could be aligned to emit the same field names as the
  `assignedExports` contract.

Both would **reuse the `xcind-config --json` contract** (and the assigned-ports
TSV that `xcind-proxy status` already reads) rather than reimplement anything.
This is a separate, lower-priority feature and is explicitly *not* part of this
ADR's accepted scope — recorded here so the option isn't lost.

## Consequences

### Positive

- App-scoped introspection sits with the other app-scoped commands; the CLI's
  scope boundaries (app vs workspace vs proxy infrastructure) stay clean.
- A single JSON contract (`xcind-config --json`) backs every consumer —
  editor plugins, scripts, and any future `xcind-proxy` view — so there is one
  place to evolve the data model.
- Read-only by construction: introspection never starts the proxy or
  provisions certificates as a side effect.

### Negative

- A user thinking purely in "proxy/routing" terms may not immediately find
  `urls` under `xcind-application`. Mitigated by the `xcind-app` alias, help
  text, and a CLI-reference cross-reference.

### Neutral

- The door is left open for a complementary *global* `xcind-proxy urls`; the
  contract-first architecture means adding it later is cheap and non-duplicative.
- `xcind-proxy status` and `xcind-application ports` now report overlapping
  information at different scopes (global vs per-app). This is intentional and
  parallels `docker ps` (global) vs `docker compose ps` (project-scoped).

## Related Documents

- [ADR-0007: Port Type System](0007-port-type-system.md) — proxied vs assigned;
  assigned ports bypass Traefik (the basis for keeping `ports` off `xcind-proxy`).
- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) — what
  the proxy actually owns.
- [ADR-0012: Unified Generate Flag Semantics](0012-unified-generate-flag-semantics.md)
  — why introspection avoids requesting a generated compose configuration.
- [`docs/reference/cli.md`](../../docs/reference/cli.md) — user-facing command
  and environment reference (includes `XCIND_ASSIGNED_LISTENERS_OVERRIDE`).
- PR #69 — implementation (feature + CI/portability hardening + test stability).
