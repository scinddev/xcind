# P6 — Reconciliation + a Repeatable Cross-Repo Sync Procedure

**Prerequisite**: P3, P4, P5 artifacts exist (learnings, xcind-ahead, scind-ahead).
**Read first**: [`00-global-context.md`](./00-global-context.md) — §2, §4a
(ADR collision), §6 (where outputs live).
**Feeds**: actual changes to the **scind** repo; P7 (registry).

---

## Goal

Two deliverables:

1. **Execute the reconciliation** — turn the classified findings from P3/P4/P5
   into concrete, ordered changes (mostly to Scind canon; some to Xcind), and
   decide the ADR numbering / cross-referencing strategy.
2. **Leave behind a repeatable procedure** — the cross-project analog of
   `engineering/maintenance/sync.md`, so future rounds of "sync Scind ↔ Xcind"
   are a documented process, not a one-off. This is the missing piece: today's
   `sync.md`/`audit.md` only cover docs↔code *within one repo*.

This serves your original goal #4.

## Part A — Execute the reconciliation

### A1. Build the consolidated change ledger

Merge the three inputs into one ordered ledger. Each row = one action:

| Source | Action type | Target | Priority |
|--------|-------------|--------|----------|
| P3 `CANON-CHANGE` | Edit Scind canon | `scind/docs/...` | by blast radius |
| P4 `PROMOTE` | Add to Scind canon | `scind/docs/...` (+ new ADR) | |
| P5 `CANON-OVERREACH` | Trim/fix Scind canon | `scind/docs/...` | |
| P4 `DIVERGENCE`, P5 `DELIBERATELY-DEFERRED`, P3 `DIVERGENCE` | Record | P7 registry | |
| P5 `NOT-IMPLEMENTED` / `IMPLEMENTED-UNTESTED` | Xcind backlog | Xcind issues/todos | |

Model the ledger on the existing `source-review-*.md` ledgers: stable IDs,
status, resolution notes, validation command per row. This ledger is the
authoritative status record for the reconciliation.

### A2. Decide the ADR numbering & cross-referencing strategy

The known collision (global-context §4a) must be resolved with an explicit,
written policy. Evaluate at least these options and **recommend one**:

- **Topic-keyed cross-reference table** (numbers stay divergent; a maintained
  table maps Scind ADR ↔ Xcind ADR by topic). Lowest churn; no renumbering.
- **Renumber one repo to match the other** (e.g. Xcind adopts Scind's numbers).
  High churn, breaks inbound links (ADR-0014 already accepted link breakage at
  this scale), cleanest long-term.
- **Shared ADR registry** in `engineering/sync/` that both repos reference.

Whichever is chosen, ADRs that encode a **divergence** (Xcind-only decisions
Scind won't adopt) must be clearly marked as such and pointed at the P7 registry.
Deliver the policy as a short ADR *in the Xcind repo* (since sync tooling lives
here) and, if it changes Scind, a matching note in Scind.

### A3. Apply changes to Scind

For `CANON-CHANGE` / `PROMOTE` / `CANON-OVERREACH` rows, edit the **scind**
working tree (`/Users/beausimensen/Code/scind`). Follow Scind's own
documentation conventions (its `DOCUMENTATION-GUIDE.md`, ADR template,
single-source-of-truth rules). New capabilities promoted from Xcind get a new
Scind ADR that credits Xcind as the validating implementation. Track each Scind
edit in the ledger; land them via Scind's contribution process.

### A4. Apply the (smaller) set of Xcind changes

Reverse learnings and any doc corrections that belong to Xcind land here, via
Xcind's normal `make check` + PR flow.

## Part B — The repeatable cross-repo sync procedure

Write **`engineering/maintenance/cross-project-sync.md`** (note: in
`maintenance/`, not `sync/` — it becomes a *standing* process doc alongside
`sync.md`/`audit.md`, while `sync/` holds this one-time planning effort). It must
codify, for future rounds:

1. **Preconditions** — Xcind self-sync (`sync.md`) green first (the P1 gate,
   generalized).
2. **Refresh the correspondence map** — re-run P2's method; diff against the
   committed `correspondence-map.json` to find *new* divergence since last round.
3. **Triage new deltas** — the P3/P4/P5 classification vocab (CANON-CHANGE,
   PROMOTE, DIVERGENCE, DELIBERATELY-DEFERRED, CANON-OVERREACH, etc.).
4. **Reconcile** — apply canon changes to Scind, record divergences in the P7
   registry (each must pass the P7 admission gate), file Xcind backlog items.
5. **Re-audit standing divergences (reverse path).** Re-run the canon-neutrality
   test on every **Active** Design/Scope entry in the P7 registry. A divergence
   that no longer justifies itself is a *newly surfaced learning*: flip it to
   `CANON-CHANGE` and feed it back into step 4. This is the guaranteed
   divergence → learning → canon path, so no insight stays paved over as Scind
   matures.
6. **Report** — dated audit report, same shape as `archive/sync-audit-*.md`.
7. **Cadence** — recommend when to run (before a Scind milestone; after major
   Xcind features; per global-context success criteria).

Include a **directionality reminder** at the top (Scind is canon; §2) and a
decision tree mirroring `sync.md`'s, but for the *cross-repo* case:

```
Divergence found between Scind canon and Xcind as-built/eng-docs:
├─ Xcind proved the design wrong? ........... change Scind (CANON-CHANGE)
├─ Xcind built something better/new? ........ promote to Scind, or record divergence
├─ Scind over-specified? .................... trim Scind (CANON-OVERREACH)
├─ Xcind intentionally differs? ............. record in divergence registry
└─ Xcind just behind? ....................... Xcind backlog
```

## Subagent fan-out

1. **Ledger-builder agent** — merge P3/P4/P5 JSON into the consolidated ledger;
   assign IDs, priorities, targets.
2. **ADR-strategy agent** — evaluate the numbering options; draft the policy ADR.
3. **Scind-editor agent(s)** — apply canon changes (partition by Scind layer to
   avoid write conflicts; use worktree isolation if parallel).
4. **Procedure-author agent** — write `cross-project-sync.md`.

## Output artifacts

- `engineering/sync/artifacts/reconciliation-ledger.md` (+ `.json`).
- The ADR-numbering **policy ADR** (Xcind `engineering/decisions/`, + Scind note
  if needed).
- Concrete **Scind repo changes** (tracked in the ledger; landed via Scind PRs).
- `engineering/maintenance/cross-project-sync.md` — the standing procedure.

## Done criteria

- [ ] Every P3/P4/P5 action item appears in the ledger with a status.
- [ ] ADR numbering/cross-ref policy decided and written as an ADR.
- [ ] All `CANON-CHANGE`/`PROMOTE`/`CANON-OVERREACH` items applied to Scind or
      explicitly deferred with reason.
- [ ] `cross-project-sync.md` exists and is runnable by a fresh agent.
- [ ] Xcind `make check` green; Scind changes follow Scind conventions.
