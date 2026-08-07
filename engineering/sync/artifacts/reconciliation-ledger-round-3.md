# Round 3 — Reconciliation Ledger (quiet round: carried follow-ups + drift spot-check)

**Status**: **Closed** 2026-08-07 — no Scind-affecting rows; no Scind PR needed.
**Date**: 2026-08-07
**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../../maintenance/cross-project-sync.md) (Steps 3–5 output).
**Scope**: Empty commit ranges on both sides. `ce0da4c..HEAD` contains only the round-2 bookkeeping commits (`afec2a5`, `14f0ab7`); Scind `c63cbc6..origin/main` is empty (canon did not move independently). The round's work is the two follow-ups round 2 carried forward (divergences 0026 and 0028) plus a defensive spot-check of the five recurring high-drift areas, which the guardrail "never trust the commit range alone" requires even when the range is empty.
**Step-1 gate**: No content commits since the round-2 close, whose self-sync gate was green; `make check` re-run green (137/137). No areas excluded.
**Machine companion**: [`reconciliation-ledger-round-3.json`](./reconciliation-ledger-round-3.json) (same rows, `meta` + `rows[]`, P6 field names and vocabulary).

`RL-` IDs continue the **global sequence** from the [round-2 ledger](./reconciliation-ledger-round-2.md) (`RL-116..RL-142`); this round allocates `RL-143..RL-146`. Join keys are round-3 finding IDs (`F3-*`).

### Directionality (global-context §2)

> Scind is canon. Xcind's lessons **upgrade** the canon. Divergence is the claim that must be **earned**; ambiguity routes to CANON-CHANGE or ESCALATE, never silently to DIVERGENCE.

## 1. Summary

| Action type | Count | Destination / status |
|-------------|------:|----------------------|
| **REGISTRY-UPDATE** | 2 | P7 registry wording/stamp refreshes (Step 5 outcome) |
| **XCIND-DOC-FIX** | 1 | Xcind self-drift correction (Step 4, Xcind-side flow) |
| **PROCESS** | 1 | Sync-artifact bookkeeping |
| **Total** | **4** | |

Notable: **zero canon impact** — no CANON-CHANGE, PROMOTE, or new DIVERGENCE rows; Scind's tree is untouched this round. The spot-check justified itself: it caught one stale Xcind doc table (RL-145) that the empty commit range could never have surfaced.

## 2. Rows

| ID | Join key | Action | P | Status | Title |
|----|----------|--------|---|--------|-------|
| RL-143 | `F3-0026-destroy-facet-wording` | REGISTRY-UPDATE | P3 | DONE | Divergence 0026: refresh destroy-facet wording after 0034's round-2 resolution |
| RL-144 | `F3-0028-retest-vs-dispose` | REGISTRY-UPDATE | P2 | DONE | Divergence 0028: re-test against as-built — still no up/down; dispose proves the loop |
| RL-145 | `F3-project-layout-missing-discovery-lib` | XCIND-DOC-FIX | P3 | DONE | project-layout.md omits xcind-discovery-lib.bash from library and hook tables |
| RL-146 | `F3-artifacts-refresh` | PROCESS | P1 | DONE | Round-3 artifact refresh: ledger, report, registry stamps, baseline entry |

## 3. Row detail

### RL-143 — Divergence 0026: refresh destroy-facet wording after 0034's round-2 resolution

**Join key**: `F3-0026-destroy-facet-wording` · **Action**: REGISTRY-UPDATE · **Priority**: P3 · **Status**: DONE
**Target**: xcind: engineering/sync/divergence/0026-workspace-state-machine.md + registry.json

Carried follow-up from round 2 (recorded in divergence 0034's resolution note). 0026 cited "CLI facets 0033 (generate) and 0034 (destroy)" as if both were Active; 0034 resolved by convergence in round 2 (Xcind PR #86's `dispose` cascade). Wording now marks 0033 Active / 0034 Resolved and states why the resolution does not weaken 0026's core claim: both projects still infer state; Xcind gaining an explicit destroy *transition* validates canon's transition vocabulary without persisting any state machine. Canon-neutrality re-test: **STILL-JUSTIFIED**.

### RL-144 — Divergence 0028: re-test against as-built — still no up/down; dispose proves the loop

**Join key**: `F3-0028-retest-vs-dispose` · **Action**: REGISTRY-UPDATE · **Priority**: P2 · **Status**: DONE
**Target**: xcind: engineering/sync/divergence/0028-workspace-orchestration-up-down.md + registry.json

Carried follow-up from round 2 (watch item). Re-tested against `bin/xcind-workspace`: the surface is `init/dispose/status/list/register/forget` (bin/xcind-workspace:1083-1092) — no `up`/`down`/`restart`, so the revisit condition has not triggered and the divergence stands (**STILL-JUSTIFIED**, SURVIVES-STRONG). Wording refreshed: `dispose` (PR #86) now proves the exact enumerate/invoke/collect-failures loop a workspace up/down needs (bin/xcind-workspace:1033-1053), replacing the weaker "status already loops apps" evidence and its stale `:393-533` line reference. Remains the highest-value Xcind-backlog easy win; likely closes next time workspace features land.

### RL-145 — project-layout.md omits xcind-discovery-lib.bash from library and hook tables

**Join key**: `F3-project-layout-missing-discovery-lib` · **Action**: XCIND-DOC-FIX · **Priority**: P3 · **Status**: DONE
**Target**: xcind: engineering/implementation/project-layout.md (Shared Libraries table + built-in hooks list)

Found by this round's high-drift spot-check (area 3, project-layout trees — a recurring drifter per P3 `L-0033`). `lib/xcind/xcind-discovery-lib.bash` is a real, registered GENERATE+ALWAYS hook (`xcind-lib.bash:93,102`), correctly documented in the specs and packaged in the Makefile, but absent from project-layout.md's Shared Libraries table and built-in hooks list. Both tables now carry it. Pre-existing self-drift (the lib predates round 2's watermark), invisible to commit-range scoping — exactly the case the "map diff decides" guardrail exists for. No canon impact: Scind's discovery spec already matched Xcind's behavior (round-1/2 territory); only Xcind's own layout doc was stale.

### RL-146 — Round-3 artifact refresh: ledger, report, registry stamps, baseline entry

**Join key**: `F3-artifacts-refresh` · **Action**: PROCESS · **Priority**: P1 · **Status**: DONE
**Target**: xcind: engineering/sync/artifacts/* + sync/divergence/registry.json + engineering/archive/ report

This ledger pair, the round-3 report, round-3 re-audit stamps for 0026/0028, and the round-3 baseline entry. Correspondence map **unchanged** (no content commits on either side; working tree matched the committed artifacts; spot-check of the five high-drift areas found only RL-145, an Xcind-internal doc fix that changes no map row's status). The other 20 Active Design/Scope divergences carry their round-2 stamps: that re-audit ran earlier the same day and no input to any canon-neutrality test has changed since (zero commits in both repos).
