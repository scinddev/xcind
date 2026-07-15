# Divergence 0018: Concern-split per-hook overlays

**Status**: Active
**Scind canon**: `docs/specs/generated-override-files.md` (one monolithic override, regenerated atomically per app)
**Xcind reality**: 8 per-hook SHA-keyed overlay files merged via multiple `-f`; `lib/xcind/` hook pipeline, `engineering/specs/generated-override-files.md`
**Category**: Scope
**Origin**: P4 XA-0030

## What differs
Xcind splits generated compose configuration into **8 per-hook overlay files** (one
per generation concern), merged by docker compose via multiple `-f` flags. Scind
regenerates **one monolithic override** file per app, atomically.

## Why Xcind diverges
The 8-way split amortizes Xcind's **per-hook content-addressed cache**: each overlay
is keyed by the SHA of its inputs, so a live-state hook can re-run and rewrite only
its own overlay while pure overlays replay from cache. Concern isolation falls out of
the caching design.

## Why Scind should NOT simply adopt Xcind's approach
Docker Compose merges N `-f` files into **byte-identical** final config — the split
produces **zero output difference**. It only pays off *with* Xcind's per-hook cache;
Scind regenerates one override atomically and has **no per-hook cache to amortize**,
so splitting into 8 files would add merge-order sensitivity and filesystem complexity
for no gain.

## Canon-change test (required)
**Strongest canon-change argument:** "Concern-split overlays are cleaner and more
debuggable than one monolithic override." **Why rejected (adversarial re-check
PERFORMED — P7):** the reviewer confirmed the output is identical, so the split is
pure mechanism, and the **one genuinely transferable principle** — *isolate
live-state-derived content from pure config-derived content in staleness detection* —
is **already promoted as XA-0001 / L-0005** (→ P6). With the learning captured
upstream, the file-count split is a safe Scope divergence. Verdict:
**SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
If Scind ever adopts per-hook content-addressed caching (it currently does not), the
split might earn its keep — re-evaluate then. Tied to divergence 0019 (phase
vocabulary) and the XA-0019 extensibility ESCALATE.

## Links
- Origin finding: P4 XA-0030 (live-vs-pure principle promoted as XA-0001 / L-0005 →
  P6)
- Related ADR(s): Xcind ADR-0003 (pure overlay design); Xcind `hook-lifecycle.md`
- Correspondence-map row(s): `specs/generated-override-files.md` (PARTIAL),
  `specs/directory-structure.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0030; live-vs-pure → XA-0001 / L-0005
