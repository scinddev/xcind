# Divergence 0022: `*_HOST_GATEWAY` env-var injection into containers

**Status**: Resolved (Xcind adopted canon, 2026-08)
**Scind canon**: `docs/specs/host-gateway-resolution.md` (mandates exposing the resolved host as a `SCIND_HOST_GATEWAY` env var *inside containers* — Xdebug `client_host` use case)
**Xcind reality**: `xcind-host-gateway-hook` now writes both halves — `services.<name>.extra_hosts: host.docker.internal:<value>` and `services.<name>.environment: XCIND_HOST_GATEWAY: <value>`; `lib/xcind/xcind-host-gateway-lib.bash`

> **Resolved.** Read the sections below as the historical record of the
> divergence. The revisit condition named in this entry was executed: see
> [Resolution](#resolution) at the end.
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
The 2026-08 escalation decision confirmed that Scind keeps the env-var mandate and
Xcind may defer it. Reopen only for implementation: adding
`environment: - XCIND_HOST_GATEWAY=<value>` (already computed in-hook; unblocks
Xdebug) resolves this entry because Xcind then adopts canon.

## Resolution
**2026-08-07 — Xcind adopted canon** (escalation follow-up Step 6, item 1).
`xcind-host-gateway-hook` now emits `environment: XCIND_HOST_GATEWAY: <value>`
next to the `extra_hosts` mapping, using the value it already computed. The two
halves are independent per service: a service that already has the
`host.docker.internal` mapping still receives the variable, and a service that
already sets `XCIND_HOST_GATEWAY` itself keeps its own value. The overlay is
skipped for a service only when it has both.

**One residual gap, deliberately not closed here.** On Docker Desktop
`__xcind-detect-host-gateway` returns nothing — `host.docker.internal` resolves
via DNS there — so the hook returns before generating any file, and no variable
reaches the containers on that platform. Closing it means generating an
env-only overlay carrying the literal `host.docker.internal`, which changes the
compose invocation on every Docker Desktop host. That is a separate decision,
not part of this entry.

## Links
- Origin finding: P5 SA-0002 (human product-call); confirms correspondence-map §3
  human-call #2 and P4 reverse-gap RG-0001
- Related ADR(s): Xcind ADR-0013 (host-docker-internal normalization); Scind
  `host-gateway-resolution.md`
- Correspondence-map row(s): `specs/host-gateway-resolution.md` (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0002 (note: the earlier "soften Scind's
  mandate" note was **withdrawn** per the product-call)
