# Divergence 0019: Internal 4-phase hook vocabulary

**Status**: Active (contingent — see Revisit conditions)
**Scind canon**: `docs/architecture/overview.md` (monolithic generator; separates generate from up without named phase arrays)
**Xcind reality**: internal 4-array phase vocabulary CONFIGURED / RESOLVED / GENERATE / EXECUTE; `lib/xcind/` hook pipeline, `engineering/specs/hook-lifecycle.md`
**Category**: Design
**Origin**: P4 XA-0031

## What differs
Xcind's generation engine is organized around an **internal 4-array phase
vocabulary** — CONFIGURED, RESOLVED, GENERATE, EXECUTE — that hooks register into.
Scind's generator is monolithic and simply separates "generate the override" from
"up the stack" without a named phase-array vocabulary.

## Why Xcind diverges
The named phases gave Xcind's Bash hook pipeline internal structure — a place to
register each generation concern in order. It is an internal organizing device, not
an external contract.

## Why Scind should NOT simply adopt Xcind's approach
The vocabulary is **internal ceremony with no consumer** absent a user-registrable
extensibility surface. Scind's monolithic generator already separates the two phases
a *consumer* actually sees (generate vs. up). Adding four named internal arrays would
add structure with nothing consuming it — **unless** Scind exposes a first-class
generation-extensibility surface, which is a separate, undecided question.

## Canon-change test (required)
**Strongest canon-change argument:** "Named, explicit generation phases are more
testable and extensible than a monolithic generator." **Why rejected (adversarial
re-check PERFORMED — P7):** the reviewer confirmed this is an *internal* Bash
hook-array vocabulary, not an external contract, and it earns its keep **only** with
a user-registrable extensibility surface — which is **exactly XA-0019, a separate
open ESCALATE**. The learning is fully absorbed by XA-0019's escalation. Verdict:
**SURVIVES-AS-DIVERGENCE (contingent).**

## Revisit conditions
**⚠ Contingent on XA-0019.** If the XA-0019 ESCALATE resolves toward Scind exposing a
first-class generation-extensibility surface (plugin API or hook-directory contract),
**this entry must be re-opened** — a named phase vocabulary may then become a genuine
canon need, flipping this to a CANON-CHANGE. Carry this flag on every sync round.

## Links
- Origin finding: P4 XA-0031; **contingent on ESCALATE XA-0019** (generation
  extensibility → human/P4/P6)
- Related ADR(s): Xcind `hook-lifecycle.md` (XCIND-ONLY spec); Xcind ADR-0012
  (unified generate-flag semantics)
- Correspondence-map row(s): `specs/hook-lifecycle.md` (XCIND-ONLY),
  `architecture/overview.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0031; **re-open trigger = XA-0019**
