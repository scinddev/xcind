# Divergence 0022: `*_HOST_GATEWAY` env-var injection into containers

**Status**: Active
**Scind canon**: `docs/specs/host-gateway-resolution.md` (mandates exposing the resolved host as a `SCIND_HOST_GATEWAY` env var *inside containers* — Xdebug `client_host` use case)
**Xcind reality**: writes only `services.<name>.extra_hosts: host.docker.internal:<value>`; no `environment:` block, no named gateway variable reaches any container; `lib/xcind/xcind-host-gateway-lib.bash:200-224`
**Category**: Scope
**Origin**: P5 SA-0002 *(source: human product-call)*

## What differs
Scind mandates (SHOULD) that the resolved workstation host be exposed **as an
environment variable inside containers** (`SCIND_HOST_GATEWAY`), for tools like Xdebug
that read `client_host` from the environment. Xcind builds **only** an `extra_hosts`
entry (`host.docker.internal:<resolved>`) — no env var reaches any container.

## Why Xcind diverges
Xcind's host-gateway hook solves the DNS-name half (`host.docker.internal`
resolvability across WSL2/Docker Desktop) and stopped there; it never added the
`environment:` injection. The resolved value is already computed in-hook, so adding it
later is cheap — but v1 shipped without it.

## Why Scind should NOT simply adopt Xcind's approach
This is the reverse framing: **Scind keeps mandating the env-var exposure — canon is
NOT softened.** The human product-call was explicit that this is a **documented known
divergence, NOT canon-overreach**: Xcind's `extra_hosts`-only behavior is an accepted
gap, not evidence Scind over-specified. Scind should *not* drop the env-var mandate
just because Xcind hasn't implemented it.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind proves `extra_hosts` alone is enough, so
Scind's env-var mandate is gold-plating." **Why rejected (human product-call,
2026-07-15):** the env var serves a concrete use case (Xdebug `client_host`) that
`extra_hosts` does not cover; a DNS name in `/etc/hosts` is not readable as an
env-var value by tools that want one. The product-call **explicitly ruled this NOT
canon-overreach** and kept Scind mandating the exposure. So the divergence is Xcind's
deliberate v1 scope-out, cleanly earned. Verdict: **DELIBERATELY-DEFERRED
divergence.**

## Revisit conditions
Xcind *may optionally* add `environment: - XCIND_HOST_GATEWAY=<value>` later (value
already computed in-hook; unblocks Xdebug) — at which point this **resolves** (Xcind
adopts canon). It is an *optional* Xcind backlog item, not a required gap.

## Links
- Origin finding: P5 SA-0002 (human product-call); confirms correspondence-map §3
  human-call #2 and P4 reverse-gap RG-0001
- Related ADR(s): Xcind ADR-0013 (host-docker-internal normalization); Scind
  `host-gateway-resolution.md`
- Correspondence-map row(s): `specs/host-gateway-resolution.md` (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0002 (note: the earlier "soften Scind's
  mandate" note was **withdrawn** per the product-call)
