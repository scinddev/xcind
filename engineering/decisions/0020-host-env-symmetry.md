# ADR-0020: Host/Container Environment Symmetry (`XCIND_HOST_ENV_FILE`)

**Status**: Accepted

## Context

[ADR-0018](0018-service-discovery-env-injection.md) injects
`XCIND_{APP}_{EXPORT}_*` discovery variables into each **container's**
`environment:`, with **container-flavored** values: an assigned export's `_HOST`
is the in-network host and `_PORT` the container port, while `_HOST_PORT` carries
the host-published port.

But developers also run processes **on the host** — `mise`, `direnv`, a test
runner, a language server — that need to reach the very same services. On the
host, an assigned export lives at `127.0.0.1:<host_port>`, not at the in-network
`host:port` a container uses. A single committed expression like
`DATABASE_URL=postgres://…@${XCIND_APP_DB_HOST}:${XCIND_APP_DB_PORT}/…` therefore
could not resolve correctly in **both** places: the container view and the host
view disagree. Application authors were left hardcoding two forms or maintaining
a hand-written host `.env` in parallel with the generated container values —
exactly the drift ADR-0018 set out to eliminate, reintroduced at the host
boundary.

## Decision

Add an **opt-in EXECUTE hook** (`xcind-hostenv-lib.bash`) that writes a
**host-view env file**: the same discovery variable set as ADR-0018, but with
**host-flavored** values for assigned exports — `_HOST=127.0.0.1` plus the
allocated host port — while proxied/apex hosts stay the routable proxied
hostname (which resolves identically from host and container).

The variable set is built from the **shared
`__xcind-discovery-build-pairs` seam** (`xcind-discovery-lib.bash`), the same
source the container injection uses, so the host and container views **never
drift** — they are two renderings of one computation.

### Why one committed expression now resolves correctly everywhere

Two layering facts make symmetry work without per-environment forks:

- dotenv loaders (mise/direnv) **never override a real OS environment variable**, and
- Compose `environment:` **beats** `env_file:`.

So the host-view file supplies the host endpoint to host processes, while inside
a container the injected `environment:` wins — one committed
`${XCIND_APP_DB_HOST}` expression yields the container endpoint in a container
and the host endpoint on the host.

### Opt-in and write modes

- **Opt-in only.** The hook is active **iff `XCIND_HOST_ENV_FILE` is set
  non-empty** (typically in `.xcind.sh`). Unset ⇒ no-op, **zero** working-tree
  writes for existing users.
- **Explicit mode, never inferred from the filename.**
  `XCIND_HOST_ENV_MODE` ∈ {`own`, `block`}, default `own`:
  - `own` — xcind owns the entire file (writes a "do not edit" header).
  - `block` — xcind manages only a marked region delimited by
    `# >>> xcind >>>` / `# <<< xcind <<<`, preserving the user's surrounding
    content.
- Registered in **`XCIND_HOOKS_EXECUTE`**, running **after assigned-port
  allocation**, so the host ports are live on every invocation. `jq` is required
  when assigned exports are configured.

## Relationship to Scind canon (P6)

Scind's service-discovery design (its ADR-0018 analog) specs the **container**
view only. Host/container symmetry is a **POC-surfaced extension** — a candidate
`PROMOTE` to Scind canon, not an obvious Bash-ism. It is deliberately **not**
pre-classified as a divergence here; the
[P4 capability analysis](../sync/04-xcind-capabilities-missing-from-scind.md)
and [P6 reconciliation](../sync/06-reconciliation-and-sync-procedure.md) decide
whether Scind adopts it. Recorded now so the capability and its rationale are not
lost.

## Consequences

### Positive

- One committed connection string / env expression works identically for
  host-run and containerized processes — no forks, no hand-maintained host
  `.env`.
- Host and container values share a single source (`__xcind-discovery-build-pairs`),
  so they cannot drift.
- Fully opt-in with an explicit mode: existing users are untouched, and `block`
  mode coexists with hand-authored env files.

### Negative

- Writes a file into the working tree when enabled — users must gitignore it (or
  commit it deliberately). Mitigated by opt-in + the "do not edit" header.
- Adds a third `XCIND_HOOKS_EXECUTE` member and a `jq` dependency when assigned
  exports are present.

### Neutral

- Mode is a distinct variable (`XCIND_HOST_ENV_MODE`), never derived from the
  target filename, to keep behavior explicit and predictable.

## Related Documents

- [ADR-0018: Service-Discovery Environment Variable Injection](0018-service-discovery-env-injection.md) — the container-view counterpart
- [Environment Variables](../specs/environment-variables.md) — Host-View Env File section
- [Hook Lifecycle](../specs/hook-lifecycle.md) — EXECUTE phase / `__xcind-hostenv-execute-hook`
- [Sync: P4 Xcind-ahead capabilities](../sync/04-xcind-capabilities-missing-from-scind.md) — PROMOTE-vs-divergence decision
