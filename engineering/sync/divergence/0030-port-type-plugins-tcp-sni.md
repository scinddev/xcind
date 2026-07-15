# Divergence 0030: Port-type plugins + tcp/SNI routing

**Status**: Active
**Scind canon**: `docs/specs/port-types.md`, `docs/product/roadmap.md` (port-type plugins + tcp/SNI routing — marked **(Future)** in Scind's own roadmap)
**Xcind reality**: test-enforced rejection of the capability; `test/test-xcind-proxy.sh`, `engineering/product/roadmap.md` (dropped)
**Category**: Scope
**Origin**: P5 SA-0015

## What differs
Scind's roadmap anticipates **port-type plugins** and **tcp/SNI-based routing** (e.g.
routing databases by SNI). It is marked **(Future)** in Scind's *own* canon. Xcind
dropped it from its roadmap and **test-enforces rejection**.

## Why Xcind diverges
Xcind narrowed its roadmap to the HTTP(S) proxy + assigned-port model it actually
needed, and enforced that boundary in tests rather than leave a half-built extension
point.

## Why Scind should NOT simply adopt Xcind's approach
A **(Future)** roadmap item has **no implementation for Xcind to have proven wrong** —
it is speculative in *both* projects. SNI-based routing is a real, Traefik-supported
capability Scind may still pursue. Xcind's rejection is "not now," not "bad idea";
Scind should keep its future intent.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind test-enforces rejection, so Scind should
drop the future plan." **Why rejected (adversarial re-check PERFORMED — P7):**
deferred-in-both; there is no built artifact to disprove the design, and the
capability is legitimate. Xcind's test-enforcement is a scope boundary, not a
disproof. Verdict: **SURVIVES-AS-DIVERGENCE** (a permanent subset divergence — Scind
keeps the future item, Xcind will not build it).

## Revisit conditions
If Scind promotes tcp/SNI from (Future) to active design, re-evaluate whether Xcind's
rejection is still a divergence or becomes a genuine gap. Re-audit each round.

## Links
- Origin finding: P5 SA-0015 (roadmap-futures; permanent subset)
- Related ADR(s): Xcind/Scind ADR-0007 (port type system); Scind roadmap
- Correspondence-map row(s): `specs/port-types.md` (PARTIAL), `product/roadmap.md`
  (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0015
