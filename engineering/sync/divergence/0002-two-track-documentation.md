# Divergence 0002: Two-track documentation

**Status**: Active
**Scind canon**: single `docs/` LDS tree (no populated user-facing track)
**Xcind reality**: `docs/` (user-facing Diátaxis: getting-started, 12 guides, reference) **and** `engineering/` (LDS mirror of Scind's design canon); `engineering/decisions/0014-two-track-documentation.md`
**Category**: Process
**Origin**: pre-existing (Xcind ADR-0014); relates to P4 XA-0043, P3 L-0031

## What differs
Xcind splits documentation into two tracks: a **user-facing Diátaxis** track under
`docs/` (tutorials, how-to guides, reference for people *using* the tool) and an
**engineering LDS** track under `engineering/` that mirrors Scind's design canon.
Scind keeps a single `docs/` LDS tree and has **no populated user-facing track** —
because Scind is a design proposal, not yet a shipping tool with users.

## Why Xcind diverges
Xcind is a *working tool* people actually run, so it needs end-user documentation
that a pure design proposal does not. The two audiences (users vs. design
maintainers) evolve on different cadences, so Xcind separated them (ADR-0014).

## Why Scind should NOT simply adopt Xcind's approach
Scind has **no users yet** — it is the proposal for a tool that hasn't been built.
A populated Diátaxis user track would be documentation for software that does not
exist: speculative tutorials and how-to guides with nothing behind them. Until
Scind ships as a real tool (per L-0031, "two-track docs *once a real tool
exists*"), maintaining a second, user-facing track would be premature and would
rot. Scind staying single-track (design-canon-only) is the correct state for its
current lifecycle stage.

> **Nuance preserved (do not pave over):** the *structural* half of two-track —
> renaming Scind's design canon `docs/` → `engineering/` to match Xcind's LDS track
> — was **PROMOTED** to canon as a learning (P4 XA-0043, human product-call), with
> an optional placeholder `docs/README.md` stating intent for a future Diátaxis
> track. What remains a **divergence** is only that Xcind maintains a *populated*
> user Diátaxis track and Scind does not (and should not, yet). The learning half
> is not lost — it is owned by P6.

## Canon-change test (required)
**Strongest canon-change argument:** "Scind should adopt two-track docs — user docs
are clearly valuable." **Why rejected / split:** the argument only holds for the
*structural* rename (engineering/ separation), which was in fact promoted to canon
(XA-0043) — so that insight is captured, not paved. The residual divergence is the
*populated user track*, and here the canon-neutrality test passes cleanly: Scind
adopting a filled-in Diátaxis track today would document a non-existent tool.
Low-risk Process entry — admitted on this justification; the promotable structural
half was routed to P6, so no learning is hidden here.

## Revisit conditions
When Scind ships as a real, runnable tool it will need a user-facing Diátaxis
track — at that point this divergence **resolves** and Scind adopts two-track for
real (L-0031's condition). Flip Status to `Resolved` then.

## Links
- Origin finding: pre-existing (Xcind ADR-0014); P4 XA-0043 (structural half →
  PROMOTE/P6); P3 L-0031 (PROCESS-ONLY, "when it ships")
- Related ADR(s): Xcind ADR-0014 (two-track-documentation)
- Correspondence-map row(s): `DOCUMENTATION-GUIDE.md` (PARTIAL), `README.md`
  (PARTIAL), ADR-topic "Two-track documentation" (XCIND-ONLY, ADR-0014)
- Reconciliation-ledger ID(s): P6 keys off XA-0043 / L-0031
