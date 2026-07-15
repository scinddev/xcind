# Divergence 0027: `port scan` / `port gc`

**Status**: Active
**Scind canon**: `docs/reference/cli.md`, `docs/specs/state-management.md` (`port scan` + `port gc`)
**Xcind reality**: auto-running `prune` (dead-path GC) only; no `scan`, no unbound reclamation; `lib/xcind/xcind-assigned-lib.bash`
**Category**: Scope
**Origin**: P5 SA-0011

## What differs
Scind offers `port scan` (survey which ports are bound/conflicting) and `port gc`
(reclaim released/unbound reservations). Xcind implements only an **auto-running
`prune`** — the dead-path subset (drop entries whose app dir no longer exists) — and
has neither `scan` nor unbound reclamation.

## Why Xcind diverges
The `scan` and unbound-reclamation halves need the **persisted inventory** Xcind
omits (divergence 0025). Auto-prune is the piece that works without a status
inventory, so it is all Xcind built.

## Why Scind should NOT simply adopt Xcind's approach
`gc`/`scan` serve generic hygiene — reclaim released ports, refresh `last_checked`,
report conflicts — that is reasonable for a **stateful** tool. Xcind's statelessness
makes them moot, which is a valid scope choice, not proof the commands are wrong.
Scind should keep them.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind's auto-prune is the useful subset;
`scan`'s headline use case is literally the remediation step printed in **SA-0005's**
error message ("`scind port scan` # check which ports are conflicting") — so it is
downstream of a **confirmed CANON-OVERREACH**." **Why rejected (adversarial re-check
PERFORMED — P7):** `gc`/`scan` also serve generic hygiene independent of the fail-fast
flow; Xcind's statelessness making them moot is a scope choice, not a disproof.
Verdict: **SURVIVES-AS-DIVERGENCE.** ⚠ **Soft P6 note (carry forward):** revisit
`scan`'s role in the SA-0005 error flow when P6 fixes SA-0005 — that specific framing
inherits the overreach taint.

## Revisit conditions
Reopen alongside P6's SA-0005 fix, or if Xcind adds a persisted inventory (divergence
0025) that makes `scan`/unbound-GC buildable. Re-audit each round.

## Links
- Origin finding: P5 SA-0011; coupled to CANON-OVERREACH SA-0005 (→ P6) and
  divergence 0025 (`port_inventory`).
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `state-management.md`
- Correspondence-map row(s): `reference/cli.md` (PARTIAL), `specs/state-management.md`
  (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0011; re-check trigger = SA-0005 fix
