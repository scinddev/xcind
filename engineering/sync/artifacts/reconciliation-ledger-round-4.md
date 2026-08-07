# Round 4 — Reconciliation Ledger (convergence round: workspace up/down resolves divergence 0028)

**Status**: **Closed** 2026-08-07 — no Scind-affecting rows; no Scind PR needed.
**Date**: 2026-08-07
**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../../maintenance/cross-project-sync.md) (Steps 3–5 output).
**Scope**: One substantive input. The xcind range `14f0ab7..HEAD` contains the round-3 bookkeeping commit (`bdfe267`, already accounted) plus `12737f8` — `feat(workspace): add up/down orchestration across workspace applications`. The scind range `c63cbc6..origin/main` is empty (verified by fetch). The round's work is triaging `12737f8` against canon, which triggers divergence 0028's revisit condition — the standing watch item every round since round 2.
**Step-1 gate**: `make check` green after `12737f8` (893 + 727 + 189 + 145 assertions, 0 failures). The feature's eng-doc mirror was stale at round open (`engineering/reference/cli.md`, `engineering/specs/workspace-lifecycle.md` lacked `up`/`down`); fixed this round as RL-148 **before** the canon comparison, so the comparison ran against a faithful mirror. No areas excluded.
**Machine companion**: [`reconciliation-ledger-round-4.json`](./reconciliation-ledger-round-4.json) (same rows, `meta` + `rows[]`, P6 field names and vocabulary).

`RL-` IDs continue the **global sequence** from the [round-3 ledger](./reconciliation-ledger-round-3.md) (`RL-143..RL-146`); this round allocates `RL-147..RL-151`. Join keys are round-4 finding IDs (`F4-*`).

### Directionality (global-context §2)

> Scind is canon. Xcind's lessons **upgrade** the canon. Divergence is the claim that must be **earned**; ambiguity routes to CANON-CHANGE or ESCALATE, never silently to DIVERGENCE.

## 1. Summary

| Action type | Count | Destination / status |
|-------------|------:|----------------------|
| **REGISTRY-UPDATE** | 1 | Divergence 0028 → **Resolved by convergence** (Step 5 outcome) |
| **XCIND-DOC-FIX** | 2 | Xcind self-drift corrections (Step 1/4, Xcind-side flow) |
| **NOT-IMPLEMENTED** | 1 | Xcind backlog: residual `restart` verb + `-a` targeting + `down --volumes` |
| **PROCESS** | 1 | Sync-artifact bookkeeping |
| **Total** | **5** | |

Notable: **zero canon impact** — `12737f8` is a pure convergence: Xcind built what canon already specified, so canon is validated, not edited. No CANON-CHANGE, PROMOTE, or new DIVERGENCE rows; Scind's tree is untouched this round.

## 2. Rows

| ID | Join key | Action | P | Status | Title |
|----|----------|--------|---|--------|-------|
| RL-147 | `F4-0028-up-down-convergence` | REGISTRY-UPDATE | P1 | DONE | Divergence 0028: resolve by convergence — `12737f8` ships workspace `up`/`down` |
| RL-148 | `F4-eng-docs-up-down` | XCIND-DOC-FIX | P2 | DONE | Eng-docs mirror `12737f8`: cli.md + workspace-lifecycle.md gain `up`/`down` |
| RL-149 | `F4-workspace-lifecycle-dispose-drift` | XCIND-DOC-FIX | P3 | DONE | workspace-lifecycle.md never absorbed round-2's `dispose` (surface list + removal section) |
| RL-150 | `F4-restart-residual` | NOT-IMPLEMENTED | P3 | XCIND-BACKLOG | Residual canon surface: `workspace restart` verb, per-app `-a` targeting, `down --volumes` |
| RL-151 | `F4-artifacts-refresh` | PROCESS | P1 | DONE | Round-4 artifact refresh: ledger, report, registry flip, map rows, baseline entry |

## 3. Row detail

### RL-147 — Divergence 0028: resolve by convergence — `12737f8` ships workspace `up`/`down`

**Join key**: `F4-0028-up-down-convergence` · **Action**: REGISTRY-UPDATE · **Priority**: P1 · **Status**: DONE
**Target**: xcind: engineering/sync/divergence/0028-workspace-orchestration-up-down.md + registry.json + README.md index

The watch item standing since round 2 triggered exactly as 0028's revisit condition predicted: `12737f8` wires the enumerate/invoke/collect-failures loop `dispose` proved (round-3 wording, RL-144) to `xcind-compose up -d` / `down` per application, with `down` confirming first. This matches canon's `workspace up`/`down` shape (per-app compose execution across the workspace, per-app failure reporting). **Xcind converged to canon; canon validated, unchanged — no Scind edit.** Same resolution pattern as 0034 in round 2 (RL-135). Residuals routed to RL-150, not left implicit. No follow-up wording check is owed elsewhere: 0028 is not a facet of 0026 (those are 0033/0034), and no other registry entry cites 0028's status.

### RL-148 — Eng-docs mirror `12737f8`: cli.md + workspace-lifecycle.md gain `up`/`down`

**Join key**: `F4-eng-docs-up-down` · **Action**: XCIND-DOC-FIX · **Priority**: P2 · **Status**: DONE
**Target**: xcind: engineering/reference/cli.md (`xcind-workspace` section) + engineering/specs/workspace-lifecycle.md

`12737f8` updated user docs (`docs/`) but not the eng-docs comparison surface — the Step-1 gate caught it at round open. `engineering/reference/cli.md` now lists `up`/`down` in the subcommand table with Down options, usage examples, and a behavior block (walk-up discovery, continue-past-failure, non-zero exit, `down` confirmation). `engineering/specs/workspace-lifecycle.md` gains a "Running the Whole Workspace" section. Fixed before Step 2 so the canon comparison ran against a faithful mirror.

### RL-149 — workspace-lifecycle.md never absorbed round-2's `dispose` (surface list + removal section)

**Join key**: `F4-workspace-lifecycle-dispose-drift` · **Action**: XCIND-DOC-FIX · **Priority**: P3 · **Status**: DONE
**Target**: xcind: engineering/specs/workspace-lifecycle.md (intro surface list + "Removing a Workspace")

Found while applying RL-148: the spec's surface list still read `init/status/list/register/forget` and "Removing a Workspace" still prescribed only manual `rm -rf` — both stale since PR #86 shipped `dispose` (round 2, RL-135 territory). The file had not been touched since the sync kickoff (`5abe3f2`). Pre-existing self-drift in the same family as round 3's RL-145: invisible to commit-range scoping because the drift predates the previous watermark. The section now leads with `xcind-workspace dispose` and keeps manual removal as the documented alternative. No canon impact — Scind's spec was already right; only Xcind's mirror lagged.

### RL-150 — Residual canon surface: `workspace restart` verb, per-app `-a` targeting, `down --volumes`

**Join key**: `F4-restart-residual` · **Action**: NOT-IMPLEMENTED · **Priority**: P3 · **Status**: XCIND-BACKLOG
**Target**: xcind backlog (no doc edit; recorded here and in 0028's resolution note)

What canon's `workspace up/down/restart` spec still has beyond `12737f8`: the `restart` verb (canon defines it as exactly `down` followed by `up`, volumes preserved — a thin composition), repeatable `-a/--app` per-app targeting, and `down --volumes`. None rises to a registry entry: no design disagreement, just surface Xcind has not built — the same "beneath registry granularity" call as round 2's RL-134 flag-shape residue, but recorded as backlog so it is not silently dropped. Low priority: the per-app path (`cd app && xcind-compose …`) already covers each.

### RL-151 — Round-4 artifact refresh: ledger, report, registry flip, map rows, baseline entry

**Join key**: `F4-artifacts-refresh` · **Action**: PROCESS · **Priority**: P1 · **Status**: DONE
**Target**: xcind: engineering/sync/artifacts/* + sync/divergence/{registry.json,README.md} + engineering/archive/ report

This ledger pair, the round-4 report, 0028's registry flip (file, registry.json, README index), two correspondence-map row refreshes (`specs/workspace-lifecycle.md`, `reference/cli.md` — both stay PARTIAL; the R4 note narrows the Scind-only residue), and the round-4 baseline entry. Step-5 re-audit scope: 0028 got the full re-check (→ Resolved); the other 20 Active Design/Scope divergences carry their round-2/3 stamps — the round's only input (`12737f8`) touches no canon-neutrality test except 0028's, and both re-audits ran earlier the same day.
