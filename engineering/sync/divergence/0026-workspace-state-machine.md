# Divergence 0026: Workspace state machine

**Status**: Active
**Scind canon**: `docs/specs/workspace-lifecycle.md` (an explicit workspace state machine + generate/destroy transitions)
**Xcind reality**: status inferred from Docker live state; no persisted state machine; `bin/xcind-workspace`, `engineering/specs/application-lifecycle.md`
**Category**: Design
**Origin**: P5 SA-0010

## What differs
Scind documents an explicit workspace **state machine** (dormant / starting / running
/ …) with generate and destroy transitions. Xcind persists no state machine — it
**infers** status from Docker's live state at runtime.

## Why Xcind diverges
Xcind is deliberately stateless (divergence 0017): rather than persist and advance a
state machine, it asks Docker what is actually running and reports that.

## Why Scind should NOT simply adopt Xcind's approach
There is nothing to *un-adopt* — Scind's state machine is a **descriptive doc model
of observable states**, and Scind's own spec already says state is *inferred at
runtime, not stored*. So Scind and Xcind actually **agree** that state is inferred;
the "machine" is essentially free documentation of the states an observer sees. It is
not persisted ceremony Xcind disproved.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind infers status from Docker live and needs
no state machine — the dormant/starting/running machine is ceremony." **Why rejected
(adversarial re-check PERFORMED — P7):** the reviewer found Scind's own
`state-management.md:51` says *"State is not explicitly stored; it is inferred from
the environment at runtime"* — Scind and Xcind **agree**, so there is no contradiction
to exploit. The machine is a descriptive model, not stored state. Verdict:
**SURVIVES-AS-DIVERGENCE** (the difference is only that Scind *documents* the observed
states as a machine; Xcind does not persist one — a doc/mechanism divergence). Its
CLI facets are divergences 0033 (generate) and 0034 (destroy).

## Revisit conditions
None substantive — both infer state. Would only reopen if Scind moved to *persisted*
state (it explicitly does not). Re-audit each round.

## Links
- Origin finding: P5 SA-0010; CLI facets SA-0023 (divergence 0033), SA-0024
  (divergence 0034). Tied to divergence 0017.
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `workspace-lifecycle.md`
- Correspondence-map row(s): `specs/workspace-lifecycle.md` (PARTIAL),
  `specs/application-lifecycle.md` (XCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0010
