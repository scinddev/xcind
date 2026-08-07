# Cross-Project Sync Report — 2026-08-07 (Round 4)

**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../maintenance/cross-project-sync.md)
**Scope**: A convergence round with one substantive input. The xcind range
`14f0ab7..HEAD` contains round 3's bookkeeping commit (`bdfe267`, already
accounted) plus `12737f8` — `feat(workspace): add up/down orchestration across
workspace applications`. The scind range `c63cbc6..origin/main` is empty
(verified by fetch, not assumed). `12737f8` triggers divergence 0028's revisit
condition — the standing watch item carried since round 2.
**Scind canon**: `c63cbc6`, unchanged since round 2 closed.
**Ledger**: [`reconciliation-ledger-round-4.{md,json}`](../sync/artifacts/reconciliation-ledger-round-4.md)
(RL-147…RL-151, global sequence).

| Category | New deltas | Applied to Scind | To P7 | Xcind backlog | Escalated |
|----------|-----------:|-----------------:|------:|--------------:|----------:|
| CANON-CHANGE | 0 | — | — | — | — |
| PROMOTE | 0 | — | — | — | — |
| CANON-OVERREACH | 0 | — | — | — | — |
| DIVERGENCE / DEFERRED | 0 | — | 0 | — | — |
| NOT-IMPL / UNTESTED | 1 | — | — | 1 | — |
| ESCALATE | 0 | — | — | — | 0 |

Plus one REGISTRY-UPDATE (0028 resolved by convergence), two XCIND-DOC-FIXes
(RL-148, RL-149), and one PROCESS row (this refresh).

- **Precondition**: Xcind self-sync green for the compared area — `make check`
  green after `12737f8` (893 + 727 + 189 + 145 assertions, 0 failures). The
  feature's eng-doc mirror was stale at round open; fixed as RL-148/RL-149
  **before** the canon comparison. No areas excluded.
- **Correspondence-map delta**: 2 rows refreshed (`specs/workspace-lifecycle.md`,
  `reference/cli.md`) — both stay PARTIAL; the R4 notes record the workspace
  up/down convergence and narrow the Scind-only residue to state
  machine/flavors/clone/generate + `restart` + per-app `-a` targeting.
- **Standing divergences re-audited**: 1 with a fresh re-check (0028 →
  **RESOLVED-BY-CONVERGENCE**). The other 20 Active Design/Scope entries carry
  their round-2/3 stamps: those re-audits ran earlier the same day and
  `12737f8` — the round's only input — touches no other entry's
  canon-neutrality test. **0 flipped to CANON-CHANGE**.
- **Scind PR(s)**: none — `12737f8` is pure convergence: Xcind built what canon
  already specified, so canon is validated, not edited.

## Highlights

- **Divergence 0028 resolved by convergence** (RL-147): the registry's
  highest-value reconsider candidate closed exactly along its predicted path.
  Round 3 wrote that 0028 was "one proven loop away from closing" — `12737f8`
  wired that loop (`dispose`'s enumerate/invoke/collect-failures shape,
  `bin/xcind-workspace`) to `xcind-compose up -d` / `down` per application,
  with `down` confirming first. Same resolution pattern as 0034 in round 2:
  Xcind converged, canon unchanged. Two of the P5 era's workspace-surface
  divergences (0034 destroy, 0028 up/down) have now closed by Xcind building
  the canon shape.
- **Residuals recorded, not dropped** (RL-150, XCIND-BACKLOG): canon still
  specifies a `restart` verb (defined as exactly `down` then `up`), repeatable
  `-a` per-app targeting, and `down --volumes`. No design disagreement —
  beneath registry granularity, filed as backlog.
- **The Step-1 gate earned its keep twice** (RL-148, RL-149): `12737f8`
  updated user docs but not the eng-docs comparison surface, and while fixing
  that, round 4 found `workspace-lifecycle.md` had *also* never absorbed
  round 2's `dispose` (surface list + "Removing a Workspace" still said only
  `rm -rf`) — pre-existing drift invisible to commit-range scoping, the same
  family as round 3's RL-145. Both fixed before the comparison ran.
