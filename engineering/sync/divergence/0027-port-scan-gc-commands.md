# Divergence 0027: `port scan` / `port gc`

**Status**: Active
**Scind canon**: `docs/reference/cli.md`, `docs/specs/state-management.md` (`port scan` + `port gc`)
**Xcind reality**: explicit-only `prune` (dead-path GC) as of PR #92. Xcind has no auto-prune, `scan`, or unbound reclamation. See `lib/xcind/xcind-assigned-lib.bash`.
**Category**: Scope
**Origin**: P5 SA-0011

## What differs
Scind offers `port scan` (survey which ports are bound/conflicting) and `port gc`
(reclaim released/unbound reservations). Xcind implements only an explicit
`prune` command. The command removes entries whose app directory no longer exists.
Xcind has neither `scan` nor unbound reclamation.

## Why Xcind diverges
The `scan` and unbound-reclamation halves need the **persisted inventory** Xcind
omits (divergence 0025). Dead-path pruning works without a status inventory, so
Xcind implements that subset as a manual command.

## Why Scind should NOT simply adopt Xcind's approach
`gc`/`scan` serve generic hygiene — reclaim released ports, refresh `last_checked`,
report conflicts — that is reasonable for a **stateful** tool. Xcind's statelessness
makes them moot, which is a valid scope choice, not proof the commands are wrong.
Scind should keep them.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind's dead-path prune is the useful subset.
`scan`'s headline use case is literally the remediation step printed in **SA-0005's**
error message ("`scind port scan` # check which ports are conflicting") — so it is
downstream of a **confirmed CANON-OVERREACH**." **Why rejected (adversarial re-check
PERFORMED — P7):** `gc`/`scan` also serve generic hygiene independent of the fail-fast
flow; Xcind's statelessness making them moot is a scope choice, not a disproof.
Verdict: **SURVIVES-AS-DIVERGENCE.** ⚠ **Soft P6 note (carry forward):** revisit
`scan`'s role in the SA-0005 error flow when P6 fixes SA-0005 — that specific framing
inherits the overreach taint.

**Addendum (2026-08-11, pre-round-6 — PR #92)**: auto-prune is gone. PR #92
removed the silent prune from `init`, `up`, and `status` because it made
read-looking commands write state and masked a row-loss bug (fresh allocation
stole assigned-but-idle ports; upsert then deleted the victim's row). `prune`
is now explicit-only and `status` is read-only. This *narrows* Xcind further
from canon's `scan`/`gc` surface, so the Scope divergence stands — but the
"Why Xcind diverges" paragraph above leaned on auto-prune ("the piece that
works without a status inventory") and is now historical: what Xcind built is
the dead-path subset as a manual command only. The next round's Step 5
re-audit must re-test this entry against that reduced reality.

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
