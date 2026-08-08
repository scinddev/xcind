# Cross-Project Sync Report — 2026-08-08 (Round 5)

**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../maintenance/cross-project-sync.md)
**Scope**: A backlog-closure round. The xcind range `12737f8..HEAD` contains
round 4's bookkeeping commit (`5f4bd5f`, already accounted) plus three inputs:
`1357d8a` (#89, yq-portability fix), `a663573` (#90, `feat(workspace): add
restart subcommand`), and `b3b7fa7` (#91, `feat(workspace): per-app -a
targeting and down --volumes`). The scind range `c63cbc6..origin/main` is
empty (verified by fetch, not assumed). Together #90 and #91 ship every item
of the round-4 RL-150 backlog (`restart` verb, repeatable `-a` targeting,
`down --volumes`).
**Scind canon**: `c63cbc6`, unchanged since round 2 closed.
**Ledger**: [`reconciliation-ledger-round-5.{md,json}`](../sync/artifacts/reconciliation-ledger-round-5.md)
(RL-152…RL-156, global sequence).

| Category | New deltas | Applied to Scind | To P7 | Xcind backlog | Escalated |
|----------|-----------:|-----------------:|------:|--------------:|----------:|
| CANON-CHANGE | 0 | — | — | — | — |
| PROMOTE | 0 | — | — | — | — |
| CANON-OVERREACH | 0 | — | — | — | — |
| CANON-CONFIRM | 1 | 0 (beneath threshold) | — | — | — |
| DIVERGENCE / DEFERRED | 0 | — | 0 | — | — |
| NOT-IMPL / UNTESTED | 0 | — | — | 0 | — |
| ESCALATE | 0 | — | — | — | 0 |

Plus one XCIND-DOC-FIX (RL-153, ADR-0023 clarification), one REGISTRY-UPDATE
(RL-154, 0021 re-audit), one NO-ACTION triage record (RL-155, #89), and one
PROCESS row (this refresh).

- **Precondition**: Xcind self-sync green for the compared area — `make check`
  green at `b3b7fa7` (932 + 727 + 189 + 171 assertions, 0 failures). Unlike
  rounds 3–4, **no stale mirror at round open**: #90 and #91 each updated
  `engineering/reference/cli.md` and `engineering/specs/workspace-lifecycle.md`
  in the same commit as the code, and a spot-check against `bin/xcind-workspace`
  confirmed the mirror faithful (`-a` unknown-name error before any action,
  `--volumes` rejected by `up`/`restart`, `restart` never forwards `-v`).
  `1357d8a` touched only `lib/`; grep confirms no eng-doc describes that
  expression, so no mirror update was owed. No areas excluded.
- **Correspondence-map delta**: 2 rows refreshed (`specs/workspace-lifecycle.md`,
  `reference/cli.md`) — both stay PARTIAL; the R5 notes record full workspace
  orchestration convergence and narrow the Scind-only workspace surface to
  `clone`/`generate` (lifecycle residue: state machine/flavors/clone/generate).
  ADR table unchanged: ADR-0023 ↔ ADR-0011 stays DIVERGED-DECISION.
- **Standing divergences re-audited**: 1 with a fresh full re-check (0021 →
  **STILL-JUSTIFIED**: `-a` is a per-app loop filter inside a located
  workspace; no name→location resolution was added, so 0021's revisit
  condition did not trigger). The other 19 Active Design/Scope entries keep
  their round-2/3 stamps — this round's inputs touch no other entry's
  canon-neutrality test. **0 flipped to CANON-CHANGE**. Divergence 0028
  (Resolved, round 4) gains a dated addendum recording the RL-150 closure.
- **Scind PR(s)**: none — #90/#91 are pure convergence: Xcind built exactly
  what canon's `workspace up/down/restart` spec already says, so canon is
  validated a second time on this surface, not edited.

## Highlights

- **The RL-150 backlog closed in one day** (RL-152, CANON-CONFIRM): round 4
  filed `restart`, `-a` targeting, and `down --volumes` as backlog; #90 and
  #91 shipped all three matching canon point for point — `restart` as exactly
  `down` then `up` with volumes always preserved, repeatable `-a`/`--app` on
  all three verbs, `down --volumes` with the data-loss line in the prompt.
  Per procedure, the closure is a **new** round-5 row joined to RL-150; the
  closed round-4 ledger is not edited. With this, the entire workspace
  orchestration surface that P5 flagged (divergence 0028) has converged.
- **A convergence PR can still leave a stale ADR** (RL-153): #91's spec text
  correctly explained that `-a` is not name targeting, but ADR-0023's own
  decision statement ("does not accept `--workspace NAME` or `--app NAME`")
  became literally false. A dated clarification paragraph now records that
  `-a` filters the pass loop inside an already-located workspace — the
  decision's substance is unchanged. Same lesson as rounds 3–4's mirror
  fixes: the drift hides where the commit range doesn't point.
- **Divergence 0021 survived its most direct test** (RL-154): the first
  Xcind flag spelled `--app` is precisely what 0021/ADR-0023 diverge over,
  and the re-audit confirmed it changes nothing — the revisit condition is a
  name→location registry, and none was added. The entry's wording ("zero
  targeting flags" → "zero name-targeting flags" + carve-out) was refreshed
  so it stays literally true.
- **A high-drift area triaged to no action, with evidence** (RL-155): #89's
  host-gateway yq fix sits in a listed high-drift area, so it was grepped
  rather than waved through — no eng-doc describes the expression's
  internals, and the documented behavior was the intent all along. Go canon
  parses YAML natively; permanent §5 substrate territory.
