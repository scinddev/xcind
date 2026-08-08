# Round 5 — Reconciliation Ledger (RL-150 backlog closes: restart, `-a` targeting, `down --volumes`)

**Status**: **Closed** 2026-08-08 — no Scind-affecting rows; no Scind PR needed.
**Date**: 2026-08-08
**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../../maintenance/cross-project-sync.md) (Steps 3–5 output).
**Scope**: The xcind range `12737f8..HEAD` contains the round-4 bookkeeping commit (`5f4bd5f`, already accounted) plus three inputs: `1357d8a` (#89, yq-portability fix), `a663573` (#90, `feat(workspace): add restart subcommand`), and `b3b7fa7` (#91, `feat(workspace): per-app -a targeting and down --volumes`). The scind range `c63cbc6..origin/main` is empty (verified by fetch). Together #90 and #91 ship every item of the round-4 RL-150 backlog; the round records that closure (round-4 ledger stays closed — no edits there) and re-checks divergence 0021/ADR-0023.
**Step-1 gate**: `make check` green at `b3b7fa7` (932 + 727 + 189 + 171 assertions, 0 failures). Both feature PRs updated the eng-docs comparison surface in the same commit (`engineering/reference/cli.md`, `engineering/specs/workspace-lifecycle.md`) — spot-checked against `bin/xcind-workspace` as-built (`-a` unknown-name error before any action, `--volumes` rejected by `up`/`restart`, `restart` never forwards `-v`): faithful. `1357d8a` touched only `lib/`; no eng-doc describes that expression (verified by grep), so no mirror update was owed. No areas excluded.
**Machine companion**: [`reconciliation-ledger-round-5.json`](./reconciliation-ledger-round-5.json) (same rows, `meta` + `rows[]`, P6 field names and vocabulary).

`RL-` IDs continue the **global sequence** from the [round-4 ledger](./reconciliation-ledger-round-4.md) (`RL-147..RL-151`); this round allocates `RL-152..RL-156`. Join keys are round-5 finding IDs (`F5-*`).

### Directionality (global-context §2)

> Scind is canon. Xcind's lessons **upgrade** the canon. Divergence is the claim that must be **earned**; ambiguity routes to CANON-CHANGE or ESCALATE, never silently to DIVERGENCE.

## 1. Summary

| Action type | Count | Destination / status |
|-------------|------:|----------------------|
| **CANON-CONFIRM** | 1 | RL-150 backlog closed by convergence (#90/#91); canon validated, unchanged |
| **XCIND-DOC-FIX** | 1 | ADR-0023 clarification: `-a` is a loop filter, not name targeting |
| **REGISTRY-UPDATE** | 1 | Divergence 0021 re-audited → **STILL-JUSTIFIED** (Step 5 outcome) |
| **NO-ACTION** | 1 | `1357d8a` (#89) triaged: no doc, canon, or registry impact |
| **PROCESS** | 1 | Sync-artifact bookkeeping |
| **Total** | **5** | |

Notable: **zero canon impact** — #90/#91 build exactly what canon's `workspace up/down/restart` spec already says (`scind/engineering/reference/cli.md`: `restart` "Equivalent to `down` followed by `up`. Volumes are always preserved"; repeatable `-a, --app` on all three verbs; `down --volumes`). Canon is validated a second time on this surface, not edited. No CANON-CHANGE, PROMOTE, or new DIVERGENCE rows; Scind's tree is untouched this round.

## 2. Rows

| ID | Join key | Action | P | Status | Title |
|----|----------|--------|---|--------|-------|
| RL-152 | `F5-rl150-closure` | CANON-CONFIRM | P1 | DONE | RL-150 backlog closed by convergence: #90 `restart` + #91 `-a` targeting / `down --volumes` |
| RL-153 | `F5-adr-0023-wording` | XCIND-DOC-FIX | P2 | DONE | ADR-0023 literal wording stale: workspace verbs now accept `--app` (as a loop filter) |
| RL-154 | `F5-0021-reaudit` | REGISTRY-UPDATE | P2 | DONE | Divergence 0021 re-audit: `-a` does not trigger the revisit condition — STILL-JUSTIFIED |
| RL-155 | `F5-yq-portability-triage` | NO-ACTION | P3 | DONE | `1357d8a` (#89) yq-portability fix: no drift — eng-docs do not describe the expression |
| RL-156 | `F5-artifacts-refresh` | PROCESS | P1 | DONE | Round-5 artifact refresh: ledger, report, registry stamps, map rows, baseline entry |

## 3. Row detail

### RL-152 — RL-150 backlog closed by convergence: #90 `restart` + #91 `-a` targeting / `down --volumes`

**Join key**: `F5-rl150-closure` · **Action**: CANON-CONFIRM · **Priority**: P1 · **Status**: DONE
**Target**: this ledger row (closure record) + engineering/sync/divergence/0028-workspace-orchestration-up-down.md addendum + registry.json 0028 notes

Round 4 filed RL-150 (`XCIND-BACKLOG`): canon's residual workspace surface — a `restart` verb, repeatable `-a`/`--app` targeting, `down --volumes`. Both items shipped the next day. #90 (`a663573`) adds `restart` as exactly canon's definition: a full `down` pass then a full `up` pass over the same per-app loop, volumes always preserved (`-v` never forwarded), confirmation before the down pass, the up pass unconditional on down failures, failures from both passes reported together with a non-zero exit. #91 (`b3b7fa7`) adds repeatable `-a NAME`/`--app NAME` on all three verbs (basename filter over the enumerated app directories; unknown name errors before anything runs) and `down --volumes` (forwards `-v` per app; prompt states the data loss; `up`/`restart` reject the flag). All three match canon's spec point for point — **Xcind converged; canon validated, unchanged.** Per procedure the closure is recorded here as a new row — the round-4 ledger is closed and RL-150's row is not edited; this row is the join (`RL-152 closes RL-150`). A Scind annotation is beneath threshold, consistent with the round-4 pure-convergence precedent (no Scind PR). Divergence 0028's resolution note gains a dated addendum so its "residuals filed as RL-150" sentence does not read as still-open.

### RL-153 — ADR-0023 literal wording stale: workspace verbs now accept `--app` (as a loop filter)

**Join key**: `F5-adr-0023-wording` · **Action**: XCIND-DOC-FIX · **Priority**: P2 · **Status**: DONE
**Target**: xcind: engineering/decisions/0023-location-based-targeting.md (Decision section clarification)

ADR-0023's decision statement read "It does not accept `--workspace NAME` or `--app NAME`" — literally false since #91, which adds `-a`/`--app` to `xcind-workspace up`/`down`/`restart`. The decision's substance is untouched: the option is a filter over the per-app pass loop **inside a workspace already located** by walk-up or `[DIR]`; no name→location resolution exists (an unrecognized name is an error against the enumerated directories, not a registry lookup). A dated clarification paragraph in the Decision section records exactly that, so a literal reader of the ADR is not misled by `xcind-workspace down -a api`. #91's own spec text (`workspace-lifecycle.md`) already cross-references ADR-0023 and divergence 0021 correctly; only the ADR itself lagged.

### RL-154 — Divergence 0021 re-audit: `-a` does not trigger the revisit condition — STILL-JUSTIFIED

**Join key**: `F5-0021-reaudit` · **Action**: REGISTRY-UPDATE · **Priority**: P2 · **Status**: DONE
**Target**: xcind: engineering/sync/divergence/0021-options-based-targeting-by-name.md + registry.json 0021 entry

The only standing divergence #90/#91 could plausibly touch is 0021 (options-based targeting by name, ↔ ADR-0023). Full re-check performed: 0021's revisit condition is "Xcind adds a name→location registry" — #91 adds none. `-a` filters which applications of the located workspace the loop visits; workspace discovery stays purely location-based, and nothing resolves a bare name from anywhere. The canon-neutrality sentence still holds unchanged (Scind's registry makes name-targeting a coherent superset Xcind genuinely lacks). Entry re-stamped **2026-08-08 round-5: STILL-JUSTIFIED**; the entry's "zero targeting flags" wording is refreshed to "zero name-targeting flags" with the loop-filter carve-out, so the entry stays literally true. The other 19 Active Design/Scope entries carry their round-2/3 stamps; this round's inputs touch no other canon-neutrality test (the yq fix is inside the Bash/yq substrate, §5 territory).

### RL-155 — `1357d8a` (#89) yq-portability fix: no drift — eng-docs do not describe the expression

**Join key**: `F5-yq-portability-triage` · **Action**: NO-ACTION · **Priority**: P3 · **Status**: DONE
**Target**: none (triage record only)

#89 makes `__xcind-service-has-host-gateway-env`'s yq expression jq-portable (`tag` → `type` matching both spellings, `sub(…, …)` → `sub(…; …)`) so kislyuk/yq no longer silently fails env detection. Host-gateway detection is a listed high-drift area, so it was checked rather than waved through: grep confirms no eng-doc describes the expression's internals (`has-host-gateway-env`, `!!map`, `sub(` appear nowhere outside archives), and the documented *behavior* — inject `XCIND_HOST_GATEWAY` unless the service already has it — was the intended behavior all along; the fix repairs it under one yq flavor. Canon side: a Go implementation parses YAML natively and never inherits a yq-expression bug — permanent Go-vs-Bash substrate (§5, divergence 0001 territory). No doc, canon, or registry impact.

### RL-156 — Round-5 artifact refresh: ledger, report, registry stamps, map rows, baseline entry

**Join key**: `F5-artifacts-refresh` · **Action**: PROCESS · **Priority**: P1 · **Status**: DONE
**Target**: xcind: engineering/sync/artifacts/* + sync/divergence/{0021,0028,registry.json,README.md} + engineering/archive/ report

This ledger pair, the round-5 report, the 0021 re-audit stamp and wording refresh, the 0028 addendum (file, registry.json notes/reality, README index note), two correspondence-map row refreshes (`specs/workspace-lifecycle.md`, `reference/cli.md` — both stay PARTIAL; the R5 notes record full orchestration convergence and narrow the Scind-only workspace surface to `clone`/`generate` and the lifecycle residue to state machine/flavors/clone/generate), and the round-5 baseline entry. No ADR-table change: ADR-0023 ↔ ADR-0011 stays the recorded DIVERGED-DECISION pair; the clarification amends wording, not the decision.
