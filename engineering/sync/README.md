# Scind ↔ Xcind Synchronization

This directory holds the **planning and working artifacts** for synchronizing
[Scind](https://github.com/scinddev/scind) (the design canon) with Xcind (its
Bash proof-of-concept), in preparation for building Scind for real.

**Operating model in one line:** *Scind is canon; Xcind's lessons upgrade the
canon; Xcind records where it intentionally diverges.* Full context and rules
are in [`00-global-context.md`](./00-global-context.md) — **read that first.**

## The plans

Each plan is standalone: hand it to a fresh session, which fans out researcher
subagents. All plans reference the global context and the artifacts of earlier
plans.

| # | Plan | Depends on | Produces |
|---|------|-----------|----------|
| P0 | [Global context + operating model](./00-global-context.md) | — | shared brief |
| P1 | [Phase 0 gate: Xcind self-sync](./01-phase-0-xcind-self-sync.md) | — | `artifacts/p1-self-sync-report.md` |
| P2 | [Correspondence map](./02-correspondence-map.md) | P1 | `artifacts/correspondence-map.{md,json}` |
| P3 | [Learnings extraction](./03-learnings-extraction.md) | P2 | `artifacts/learnings.{md,json}` |
| P4 | [Xcind capabilities missing from Scind](./04-xcind-capabilities-missing-from-scind.md) | P2 | `artifacts/xcind-ahead.{md,json}` |
| P5 | [Scind capabilities unexercised in Xcind](./05-scind-capabilities-unexercised-in-xcind.md) | P2 | `artifacts/scind-ahead.{md,json}` |
| P6 | [Reconciliation + repeatable sync procedure](./06-reconciliation-and-sync-procedure.md) | P3, P4, P5 | ledger + Scind changes + `maintenance/cross-project-sync.md` |
| P7 | [Divergence registry design](./07-divergence-registry.md) | P2 (design); P3–P6 (content) | `divergence/` |

## Execution order

```
P1 ─► P2 ─► { P3 ∥ P4 ∥ P5 } ─► P6
                     └────────────► P7 (design from P2; populate from P3–P6)
```

- **P1 is a hard gate.** Do not compare Xcind eng-docs to Scind until Xcind
  eng-docs are verified against Xcind code. Run
  [`engineering/maintenance/sync.md`](../maintenance/sync.md).
- **P3, P4, P5 run in parallel** once the P2 map exists.
- **P6** applies canon changes to the **scind** repo and leaves behind a standing
  cross-project sync process in `engineering/maintenance/`.
- **P7**'s registry is the durable home for intentional divergences and the
  baseline the standing process diffs against.

## Directory conventions

- `NN-*.md` — the plan documents (this planning effort; relatively static).
- `artifacts/` — generated outputs (maps, ledgers, reports). Created by P1+.
- `divergence/` — the living divergence registry (created by P7).
- The **standing** cross-project process lives in
  `../maintenance/cross-project-sync.md` (created by P6), alongside the existing
  per-repo `sync.md`/`audit.md` — not here, because `sync/` is this one-time
  effort while `maintenance/` is ongoing.

## Repos this effort touches

- **Xcind** (this repo): `/Users/beausimensen/Code/xcind` — eng-docs, code,
  these plans, the registry, the standing procedure.
- **Scind**: `/Users/beausimensen/Code/scind` — canon; receives changes from
  P3/P4/P5 via P6.
