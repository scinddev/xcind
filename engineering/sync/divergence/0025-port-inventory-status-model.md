# Divergence 0025: `port_inventory` status model

**Status**: Active
**Scind canon**: `docs/specs/state-management.md` (`port_inventory` with assigned / unavailable / released status transitions)
**Xcind reality**: assigned-ports TSV tracks only active assignments; path-existence `prune` + manual `release` are the GC subset; `lib/xcind/xcind-assigned-lib.bash`
**Category**: Design
**Origin**: P5 SA-0009

## What differs
Scind models a `port_inventory` with a status lifecycle — ports move through
**assigned / unavailable / released**, and external (non-Scind) ports are tracked
with `first_seen`/`last_checked`. Xcind's TSV records only **active assignments**;
its garbage collection is path-existence `prune` plus a manual `release`.

## Why Xcind diverges
Xcind is deliberately stateless (divergence 0017). A full status-transition inventory
requires persisted state it chose not to keep; tracking only live assignments (with
prune/release) was the minimal practical subset.

## Why Scind should NOT simply adopt Xcind's approach
The assigned-tracking core is legitimate for any stateful tool — and Xcind's TSV does
exactly that. The divergence is **architectural** (Xcind stateless vs. Scind
stateful), not proof the richer model is wrong. Scind's inventory feeds capabilities
Xcind forgoes (`port scan`, unbound reclamation, staleness) that its design relies on.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind's active-only TSV suffices, so the
assigned/unavailable/released model is over-built — especially the `unavailable`
external-port sub-state." **Why rejected (adversarial re-check PERFORMED — P7):** the
stateful inventory is a valid design and Xcind's TSV is the same idea minus the
status transitions; deferral is a scope choice, not a disproof. Verdict:
**SURVIVES-AS-DIVERGENCE.** ⚠ **Soft P6 note (carry forward):** the `unavailable`
external-port sub-state exists partly to feed SA-0005's fail-fast — a **confirmed
CANON-OVERREACH** already routed to P6. When P6 fixes SA-0005, **re-check whether
tracking non-Scind ports still earns its keep**; that slice of the model inherits the
overreach taint.

## Revisit conditions
Reopen alongside P6's SA-0005 fix (the `unavailable` sub-state), or if Xcind adds
persisted state. Re-audit each round (Design entry).

## Links
- Origin finding: P5 SA-0009; coupled to CANON-OVERREACH SA-0005 (→ P6). Tied to
  divergences 0017, 0027.
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `state-management.md`
- Correspondence-map row(s): `specs/state-management.md` (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0009; re-check trigger = SA-0005 fix
