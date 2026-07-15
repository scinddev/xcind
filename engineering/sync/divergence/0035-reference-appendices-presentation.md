# Divergence 0035: Reference-appendices presentation

**Status**: Active
**Scind canon**: `docs/reference/appendices/cli/detailed-examples.md`, `.../cli/error-messages.md`, `.../configuration/complete-examples.md` (dedicated reference appendices)
**Xcind reality**: no eng-reference appendices — worked examples folded inline + into the out-of-scope user `docs/` (Diátaxis): `docs/reference/cli.md`, `docs/getting-started/*`, `docs/guides/*` (12 guides)
**Category**: Process
**Origin**: P5 SA-0025 *(source: human product-call)*

## What differs
Scind keeps detailed CLI walkthroughs, an error/exit-code catalog, and complete
config examples as **dedicated `reference/appendices/`** files. Xcind has **no
eng-reference appendices**: it folds worked examples inline into `configuration.md`
and demonstrates real usage in its **user-facing** two-track `docs/` (Diátaxis) — 12
guides + getting-started + reference — which is *out of scope* for cross-project sync.

## Why Xcind diverges
Xcind's two-track model (divergence 0002) puts worked examples where users read them
(the Diátaxis `docs/` track), not in the engineering LDS tree, so the engineering
reference stays lean and the examples live closer to users.

## Why Scind should NOT simply adopt Xcind's approach
The human product-call was explicit: **leave Scind's appendices as-is.** No code
exists behind Scind yet, so its appendices are the right home for worked examples in a
docs-only proposal; and Xcind's inline/user-docs placement depends on having a
*populated user track* Scind does not have (see divergence 0002). This is a
**doc-presentation divergence**, not a gap Xcind must close.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind proves examples belong inline / in user
docs, so Scind's separate appendices are redundant structure." **Why rejected (human
product-call, 2026-07-15):** Scind has no populated user track to fold examples into
(divergence 0002), so its appendices are the correct location for now; the difference
is presentation, not capability. Verdict: **DELIBERATELY-DEFERRED divergence (doc
presentation).** *Note:* the one piece with no Xcind analog — an error/exit-code
**catalog** — is tracked separately as UX-polish backlog under SA-0021 (not a
divergence).

## Revisit conditions
When Scind ships as a real tool with a populated user (Diátaxis) track (ties to
divergence 0002 resolving), the appendices question may be revisited — worked examples
could migrate to the user track then.

## Links
- Origin finding: P5 SA-0025 (human product-call); ties to divergence 0002 (two-track
  docs); error-catalog piece → SA-0021 (Xcind UX-polish backlog, not here)
- Related ADR(s): Xcind ADR-0014 (two-track documentation)
- Correspondence-map row(s): `reference/appendices/cli/detailed-examples.md`,
  `.../error-messages.md`, `.../configuration/complete-examples.md` (all SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0025
