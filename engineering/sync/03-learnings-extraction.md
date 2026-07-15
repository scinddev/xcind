# P3 — Extract Xcind Learnings, Classified by Destination

**Prerequisite**: [P2](./02-correspondence-map.md) correspondence map exists.
**Read first**: [`00-global-context.md`](./00-global-context.md) — §2 (operating
model / directionality) is the crux of this plan.
**Feeds**: P6 (reconciliation), P7 (divergence registry).

---

## Goal

Surface everything building Xcind **taught** — bugs found, assumptions broken,
compromises made, features that behaved differently than designed — and route
each learning to exactly one destination using the operating-model rule.

This is the plan that most directly serves your original goal #1. Its defining
discipline is **classification**, not mere listing.

## The classification (every learning gets exactly one label)

| Label | Definition | Destination |
|-------|------------|-------------|
| **CANON-CHANGE** | Xcind proved Scind's *design* wrong, incomplete, or naïve. | Propose/file a change to `scind/docs/`. → P6 |
| **DIVERGENCE** | Xcind made an intentional compromise Scind should **not** adopt (Bash-ism, shortcut, scope cut). | Record in registry. → P7 |
| **PROCESS-ONLY** | Learning about *how to build/test/document*, not about the product design. | Note in P6's procedure or Xcind maintenance docs; does not touch Scind design. |
| **CANON-CONFIRM** | Xcind validated a Scind decision that was previously unproven. | Annotate the Scind ADR/spec as "validated by Xcind." → P6 (low priority) |

Apply the global-context §2 test to each: *"Design was wrong → CANON-CHANGE.
Only how Xcind implemented it → DIVERGENCE."*

### Protecting learnings from misclassification (global-context §2a)

**DIVERGENCE is the label that must be earned**, not the fallback. Enforce three
things so a real learning is never paved into a divergence:

- **Ambiguity routes up, not to DIVERGENCE.** If you cannot cleanly apply the §2
  test, use a fifth, temporary label **ESCALATE** for a human product call —
  never default-file the item as a divergence.
- **Adversarial re-check on every DIVERGENCE candidate.** Before a learning is
  finalized as DIVERGENCE, a *separate* subagent must try to argue it is actually
  a CANON-CHANGE — that Xcind's difference reveals a broken Scind assumption. The
  divergence label survives only if that challenge fails. Spend this effort on
  **design-assumption** differences (what the thing does/promises); **Bash /
  build / structural** and **process** differences are low-risk and need only a
  one-line justification.
- **Record the rejected canon-change reasoning** on every DIVERGENCE. The P7
  entry schema requires this field, so even when the divergence label stands, the
  learning it was tested against is never discarded and a later round can reopen
  it.

## Where learnings hide (evidence sources)

Mine these in Xcind, then map each candidate learning back to the affected Scind
canon via the P2 map:

1. **ADRs 0012, 0015, 0016, 0018** (Xcind-only per global-context §4a) — each
   likely encodes a learning. Why did Xcind need a decision Scind never made?
2. **`engineering/archive/`** — PRDs and `research-scind-proxy.md` record the
   gap between plan and reality; `code-review-findings.md` and dated sync-audits
   record what broke.
3. **`engineering/maintenance/source-review-*.md`** — five ledgers of findings
   (`CLI-ENTRY-*`, `CORE-RUNTIME-*`, `PROXY-ROUTING-*`, `WAI-*`). Each closed
   finding is a candidate learning; the *reason* it was a finding is the lesson.
4. **`DIVERGED` / `PARTIAL` rows** from the P2 map — each is a place Xcind and
   Scind already disagree; determine which way the learning flows.
5. **Xcind-only specs** (`hook-lifecycle`, `application-lifecycle`) — the spec
   exists because building forced a design Scind didn't anticipate.
6. **`git log`** on `lib/xcind/` — commits with "fix", "actually", "turns out",
   revert/redesign patterns often mark a broken assumption.
7. **The recent instance/worktree + host-env work** — fresh, likely un-extracted
   learnings about isolation and host/container env symmetry.

## Subagent fan-out

Split by **evidence source × subsystem** so agents don't re-mine the same ground:

1. **ADR-archaeology agent** — Xcind-only ADRs + `DIVERGED` ADR rows: why each
   decision was needed; classify.
2. **Source-review-ledger agent** — the five `source-review-*.md` ledgers:
   distill each finding cluster into a learning; classify.
3. **Proxy/networking agent** — proxy, host-gateway, TLS, apex, service
   discovery lessons (the area with the most Scind-vs-reality friction).
4. **Identity/lifecycle agent** — project naming, instance/worktree isolation,
   workspace/app identity, hooks, generation cache.
5. **Config/env agent** — config resolution, env files, host-env symmetry,
   variable expansion.

Each agent returns a list of learning records (schema below). A synthesis pass
de-duplicates (the same lesson often shows up in multiple sources) and resolves
any classification disagreements against the §2 rule.

## Output artifact

Write **`engineering/sync/artifacts/learnings.md`** (human) plus
**`learnings.json`** (machine, feeds P6/P7). One record per learning:

```json
{
  "id": "L-0007",
  "title": "Assigned-port generation must not be cached with the compose overlay",
  "what_xcind_learned": "Caching assigned-port overlays with the generation SHA served stale host ports after release/prune.",
  "scind_canon_ref": "docs/specs/port-types.md#assigned",
  "xcind_evidence": ["engineering/maintenance/source-review-core-runtime.md#CORE-RUNTIME-002"],
  "classification": "CANON-CHANGE",
  "rationale": "Scind's port spec is silent on cache invalidation for live host-port state — a design gap, not a Bash quirk.",
  "proposed_action": "Add cache-invalidation requirement to Scind port-types spec + note in state-management.",
  "confidence": "high"
}
```

For every `CANON-CHANGE`, name the **specific Scind file** to change and sketch
the change (P6 executes it). For every `DIVERGENCE`, write the one-line registry
entry P7 will absorb.

## Done criteria

- [ ] Every evidence source above mined; each Xcind-only ADR accounted for.
- [ ] Every learning has exactly one classification with a stated rationale
      referencing the §2 rule.
- [ ] Every `CANON-CHANGE` names a target Scind file + sketched change.
- [ ] Every `DIVERGENCE` has a ready-to-file registry line.
- [ ] Duplicates merged; `learnings.md` + `learnings.json` committed.
