# Divergence 0017: Stateless identity/registry (path+timestamp TSV)

**Status**: Active
**Scind canon**: `docs/specs/state-management.md`, `docs/specs/generated-manifest.md` (persisted `state.yaml`, computed `manifest.yaml`, label-reconstructable registry, flavor state)
**Xcind reality**: flat path+timestamp TSV registry + `assigned-ports.tsv`; no `state.yaml`, no `manifest.yaml`; `lib/xcind/xcind-registry-lib.bash`, `xcind-assigned-lib.bash`
**Category**: Design
**Origin**: P4 XA-0033

## What differs
Xcind's identity/registry state is a **flat TSV** of workspace paths + timestamps
(plus a separate assigned-ports TSV) — no `state.yaml`, no computed workspace
`manifest.yaml`. Scind persists richer state: a `state.yaml`, a computed
`manifest.yaml`, flavor state, and a registry reconstructable from Docker labels.

## Why Xcind diverges
Xcind aimed to be as stateless as possible — the minimum persisted state to make
naming and port assignment sticky, serialized as jq/yq-free TSV lines that Bash can
read without a parser.

## Why Scind should NOT simply adopt Xcind's approach
Scind's richer persistence is **intentional infrastructure** its own design relies
on: flavor state (the flavor system, 0024), a computed manifest for at-rest topology
(0023), and a label-reconstructable registry for staleness and dashboards.
Downgrading to a metadata-free TSV would drop capabilities Scind's tooling depends
on. Notably, Xcind did **not** actually go stateless — it kept two TSV state files —
so "adopt statelessness" misreads what Xcind actually did.

## Canon-change test (required)
**Strongest canon-change argument:** "If Xcind runs on flat TSVs, Scind's
`state.yaml` + computed `manifest.yaml` is over-built." **Why rejected (adversarial
re-check PERFORMED — P7):** the reviewer found **CANON-CONFIRM L-0022** records that
Xcind's attempt to *out-stateless* Scind **failed** — it kept load-bearing registry
and assigned-port state — which *strengthens* ADR-0005 rather than challenging it.
The only genuine deltas are (1) TSV-vs-YAML serialization (an excluded Bash idiom,
§5) and (2) the absence of an aggregated `manifest.yaml` — and lacking that manifest
is a **Scind-ahead gap** whose necessity is escalated as **L-0035**, not a divergence
Xcind proved. Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen if L-0035 (is the aggregated manifest necessary?) concludes Scind's manifest
is redundant — that would trim *Scind's* state, not adopt Xcind's TSV. Re-audit each
round.

## Links
- Origin finding: P4 XA-0033; confirms CANON-CONFIRM L-0022; manifest question →
  ESCALATE L-0035 (→ P6). Cross-listed with divergences 0023, 0025, 0026.
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `state-management.md` /
  `generated-manifest.md`
- Correspondence-map row(s): `specs/state-management.md` (SCIND-ONLY),
  `specs/generated-manifest.md` (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off XA-0033; cross-linked to L-0022, L-0035
