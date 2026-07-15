# Divergence 0015: Default proxy domain `localhost.scind.io`

**Status**: Active
**Scind canon**: `docs/decisions/0009-flexible-tls-configuration.md`, `docs/specs/proxy-infrastructure.md` (default `.scind.test`)
**Xcind reality**: default proxy domain `localhost.scind.io` (a real public registration resolving to `127.0.0.1`); `engineering/decisions/0016-proxy-domain-wildcard-constraint.md`, `lib/xcind/`
**Category**: Design
**Origin**: P4 XA-0034

## What differs
Xcind's default proxy domain is `localhost.scind.io` — an author-owned **public**
registration whose wildcard `*.localhost.scind.io` resolves to `127.0.0.1`. Scind's
default is `.scind.test`, a reserved special-use TLD.

## Why Xcind diverges
A live public wildcard record gives true zero-setup DNS: users get working
`*.localhost.scind.io` resolution without wiring up `/etc/hosts` or dnsmasq. It was
the most frictionless default for a tool people run today.

## Why Scind should NOT simply adopt Xcind's approach
`.test` is an **RFC 6761 reserved special-use TLD**, guaranteed never delegated —
purpose-built for local development. `localhost.scind.io` carries three real costs a
canonical default should not impose: (1) **hostname leakage** to public resolvers
(privacy), (2) an **external-registration upkeep dependency** — a lapsed domain or
changed record breaks every user, and (3) the public-A-record→`127.0.0.1` pattern is
textbook **DNS-rebinding**, which many resolvers and browsers actively block →
intermittent failures. `.scind.test` is the legitimate, self-contained default.

## Canon-change test (required)
**Strongest canon-change argument:** "A live public wildcard is a materially better
zero-config default than a reserved TLD that still needs local resolution wired up."
**Why rejected (adversarial re-check PERFORMED — P7):** the reviewer confirmed the
promotable insight — that the proxy domain **must be multi-label** for wildcard TLS —
is *already split out and PROMOTED as XA-0002*. What remains at this entry is only the
**public-domain default**, whose privacy/upkeep/DNS-rebinding downsides make the
reserved-TLD default legitimate. Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
If Scind decided to operate its own guaranteed-stable public dev domain with
rebinding protections, or if the multi-label requirement (XA-0002) landing in canon
changed the default calculus. Re-audit each round.

## Links
- Origin finding: P4 XA-0034 (multi-label rule promoted separately as XA-0002 → P6)
- Related ADR(s): Xcind ADR-0016 (proxy-domain wildcard constraint); Scind ADR-0009
- Correspondence-map row(s): `specs/proxy-infrastructure.md` (PARTIAL); ADR-topic
  "Proxy domain wildcard constraint" (XCIND-ONLY, ADR-0016)
- Reconciliation-ledger ID(s): P6 keys off XA-0034; multi-label insight → XA-0002
