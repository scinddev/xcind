# Divergence 0020: Per-app SHA-keyed `config.json` introspection artifact

**Status**: Active
**Scind canon**: `docs/specs/generated-manifest.md` (aggregated workspace `manifest.yaml` introspection surface)
**Xcind reality**: per-app SHA-keyed `config.json` under the content-addressed cache dir; `lib/xcind/`, `engineering/implementation/handoffs/config-json-cache-staleness.md`
**Category**: Design
**Origin**: P4 XA-0032

## What differs
Xcind writes a per-app **`config.json`** introspection artifact, keyed by the SHA of
its inputs, inside its content-addressed cache directory. Scind's introspection
surface is an **aggregated workspace `manifest.yaml`** covering the whole workspace.

## Why Xcind diverges
The `config.json` is shaped to Xcind's content-addressed cache — the SHA that names
it *is* the cache key. It fell out of the caching design as the per-app materialized
view.

## Why Scind should NOT simply adopt Xcind's approach
Scind already has an **equivalent-or-broader introspection surface** — the aggregated
`manifest.yaml`. Adopting Xcind's per-app SHA JSON would **duplicate** the manifest
rather than add capability, and would drag in the content-addressed-cache shaping
that only Xcind needs. The generalizable insight (a single `--json` contract backing
labels + introspection, side-effect-free) is a separate learning.

## Canon-change test (required)
**Strongest canon-change argument:** "A per-app machine-readable JSON introspection
contract is valuable for tooling." **Why rejected (adversarial re-check PERFORMED —
P7):** the reviewer confirmed the transferable insight — *one `--json` contract
backing labels + introspection, read-only/side-effect-free* — is **already promoted
as L-0012** (→ P6). The residual SHA-keyed per-app file is cache-shaped and would
duplicate Scind's manifest. In fact the promote direction is *reversed*: Xcind
**lacks** the aggregated manifest (a Scind-ahead item), and the manifest-vs-per-app
question is escalated as **L-0035**. Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen with L-0035 (aggregated-manifest necessity) — that decides Scind's manifest,
not adoption of Xcind's SHA JSON. Tied to divergence 0017 (stateless registry).

## Links
- Origin finding: P4 XA-0032 (`--json` contract insight → L-0012 → P6; manifest
  question → ESCALATE L-0035)
- Related ADR(s): Xcind ADR-0015 (application-export introspection)
- Correspondence-map row(s): `specs/generated-manifest.md` (SCIND-ONLY); ADR-topic
  "Application export introspection" (XCIND-ONLY, ADR-0015)
- Reconciliation-ledger ID(s): P6 keys off XA-0032; cross-linked to L-0012, L-0035
