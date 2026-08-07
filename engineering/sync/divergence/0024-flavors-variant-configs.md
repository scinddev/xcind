# Divergence 0024: Flavors (variant configs)

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/specs/workspace-lifecycle.md`, `docs/reference/cli.md` (variant configs + `default_flavor` + resolution + `flavor` commands)
**Xcind reality**: flat `XCIND_COMPOSE_FILES` list; `${APP_ENV}` file-pattern expansion is the env-driven substitute; `engineering/decisions/0005-structure-vs-state-separation.md` (dropped every flavor row)
**Category**: Scope
**Origin**: P5 SA-0008

## What differs
Scind offers **flavors**: named variant configurations with a `default_flavor`, a
resolution step, and `flavor` CLI commands (list/set). Xcind dropped every flavor row
(ADR-0005) and uses a flat `XCIND_COMPOSE_FILES` list, with `${APP_ENV}` expansion
(divergence 0004/0012) as the env-driven file-selection substitute.

## Why Xcind diverges
Flavors need somewhere to record the **active flavor** — persisted state. Xcind is
deliberately stateless (divergence 0017), so it had no home for active-flavor state
and used shell expansion over file patterns instead (the L-0039 rationale).

## Why Scind should NOT simply adopt Xcind's approach
Named variant configs map directly to an **industry-standard need** — `docker compose
--profile` exists for exactly this. Flavors are a validated, discoverable convenience
layer over the same compose-file primitive Xcind exposes raw; Scind persists
active-flavor state deliberately. Adopting Xcind's flat list + shell expansion would
drop declarative validation/discoverability and reintroduce the arbitrary-shell shape
(0012). Scind should keep flavors.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind dropped flavors and works, so the whole
`default_flavor` + state-resolution + `flavor set` machinery is over-built." **Why
rejected (adversarial re-check PERFORMED — P7):** the reviewer found flavors map to a
standard, well-understood pattern (compose profiles) — not wrong, just higher-level —
and the deeper question of whether flavors' state-coupling is heavier than needed is
**already preserved as ESCALATE L-0039** (→ P6), so nothing is buried. Verdict:
**SURVIVES-AS-DIVERGENCE.** *Soft P6 note (concurs with P5): make the flavors deferral
explicit in Xcind ADR-0005 — **done 2026-08-07** (ledger row `RL-092`): ADR-0005 now
carries a "Flavors are deferred, not rejected" section.*

## Revisit conditions
The 2026-08 escalation decision resolved L-0039: Scind retains stateful flavors and
does not add an env-var selection source now. Reopen if a real CI or scripting
consumer cannot pass `--flavor`, or if Xcind adds persisted state and can implement
flavors. Re-audit each round.

## Links
- Origin finding: P5 SA-0008; the flavor mechanism review is ESCALATE L-0039 (→ P6);
  env-driven substitute is divergences 0004 / 0012. Tied to divergence 0017.
- Related ADR(s): Xcind ADR-0005 (structure-vs-state — flavors dropped)
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL),
  `specs/workspace-lifecycle.md` (PARTIAL), `reference/configuration.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0008; cross-linked to L-0039
