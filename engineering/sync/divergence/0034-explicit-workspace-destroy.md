# Divergence 0034: Explicit `workspace destroy`

**Status**: Active
**Scind canon**: `docs/reference/cli.md`, `docs/specs/workspace-lifecycle.md` (explicit `workspace destroy` — full teardown)
**Xcind reality**: thinner teardown via `forget` / `prune`; no full `destroy` verb; `bin/xcind-workspace`
**Category**: Design
**Origin**: P5 SA-0024

## What differs
Scind exposes an explicit `workspace destroy` that does a **full teardown** — remove
`.generated/`, `workspace.yaml`, release assigned ports, deregister. Xcind has no
`destroy` verb; its thinner state is cleaned via `forget` (drop a registry entry) and
`prune` (dead-path GC).

## Why Xcind diverges
Xcind persists **less state** (divergence 0017), so there is less to tear down —
`forget`/`prune` cover its subset. A full `destroy` had less to do, so it was not
built as a distinct verb.

## Why Scind should NOT simply adopt Xcind's approach
`destroy` does **real cleanup coherent with Scind's *stateful* model** — removing
generated dirs, the registry file, released ports, and deregistration. Xcind needs
less teardown only because it has thinner state; that is a **consequence of the
stateless-model divergence (0026)**, not evidence `destroy` is wrong. Scind should
keep it.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind is leaner-state, so full teardown is
unnecessary — `forget`/`prune` suffice." **Why rejected (adversarial re-check
PERFORMED — P7):** `destroy` maps to real state Scind persists (generated dirs,
`workspace.yaml`, assigned ports, registration); Xcind's thinner cleanup surface is a
direct consequence of it persisting less, not a disproof. Verdict:
**SURVIVES-AS-DIVERGENCE** (CLI facet of the stateless model).

## Revisit conditions
None substantive — CLI facet of divergence 0026 (workspace state machine); resolves
only if that does.

## Links
- Origin finding: P5 SA-0024 (CLI facet of SA-0010 / divergence 0026)
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `workspace-lifecycle.md`
- Correspondence-map row(s): `reference/cli.md` (PARTIAL),
  `specs/workspace-lifecycle.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0024. Facet of divergence 0026.
