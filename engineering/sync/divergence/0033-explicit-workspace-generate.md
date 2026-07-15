# Divergence 0033: Explicit `workspace generate`

**Status**: Active
**Scind canon**: `docs/reference/cli.md`, `docs/specs/workspace-lifecycle.md` (explicit `workspace generate` command)
**Xcind reality**: generation folded into on-demand / SHA-cached derivation; no standalone `generate` verb; `lib/xcind/` hook pipeline
**Category**: Design
**Origin**: P5 SA-0023

## What differs
Scind exposes an explicit `workspace generate` command that materializes override
files as a distinct step. Xcind **folds generation** into on-demand, SHA-cached
derivation — the override is produced as a side effect of the operations that need
it, with no standalone `generate` verb.

## Why Xcind diverges
Xcind's content-addressed cache regenerates overlays automatically when inputs change
(by SHA), so a manual `generate` step was unnecessary — the CLI facet of its stateless
generation model (divergence 0026).

## Why Scind should NOT simply adopt Xcind's approach
Both tools must emit override YAML for `docker compose`; the divergence is only *when*
(Scind persists + mtime-caches, Xcind derives + SHA-caches). An explicit `generate`
for **inspection/debugging** is a normal affordance (cf. `terraform plan`), and Scind
already auto-runs it inside `up`. It is not gold-plated — removing it would drop a
useful inspection point.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind folds generation invisibly and is fine, so
a separate command is ceremony." **Why rejected (adversarial re-check PERFORMED —
P7):** the explicit verb is a normal inspection/debugging affordance already auto-run
inside `up`; the *when-to-generate* difference is a consequence of the stateless-model
divergence (0026), not proof the command is redundant. Verdict:
**SURVIVES-AS-DIVERGENCE** (CLI facet of the stateless model).

## Revisit conditions
None substantive — CLI facet of divergence 0026 (workspace state machine); resolves
only if that does.

## Links
- Origin finding: P5 SA-0023 (CLI facet of SA-0010 / divergence 0026)
- Related ADR(s): Xcind ADR-0012 (unified generate-flag semantics); Scind
  `workspace-lifecycle.md`
- Correspondence-map row(s): `reference/cli.md` (PARTIAL),
  `specs/workspace-lifecycle.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0023. Facet of divergence 0026.
