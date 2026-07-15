# Divergence 0031: Shared volumes

**Status**: Active
**Scind canon**: `docs/product/roadmap.md` (shared volumes across workspace apps — marked **(Future)**)
**Xcind reality**: unbuilt; dropped from Xcind's roadmap; `engineering/product/roadmap.md`
**Category**: Scope
**Origin**: P5 SA-0017

## What differs
Scind's roadmap anticipates **shared volumes** across a workspace's apps (shared
uploads/assets). It is **(Future)** in Scind's own canon. Xcind dropped it from its
roadmap and never built it.

## Why Xcind diverges
Xcind kept its scope to per-app compose orchestration and did not take on
workspace-level shared storage.

## Why Scind should NOT simply adopt Xcind's approach
Nothing to adopt — the feature is **(Future)** in both, with **no implementation** for
Xcind to have disproved. Shared uploads/assets across apps is a legitimate
workspace-level feature Scind may still pursue.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind dropped it, so Scind should too." **Why
rejected (adversarial re-check PERFORMED — P7):** a `(Future)` item unbuilt in both
projects cannot have been proven wrong by Xcind; the feature is legitimate. Verdict:
**SURVIVES-AS-DIVERGENCE** (permanent subset — Scind keeps the future item; Xcind
drops it).

## Revisit conditions
If Scind promotes shared volumes from (Future) to active design. Re-audit each round.

## Links
- Origin finding: P5 SA-0017 (roadmap-futures; permanent subset)
- Related ADR(s): none (roadmap item, no ADR)
- Correspondence-map row(s): `product/roadmap.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0017
