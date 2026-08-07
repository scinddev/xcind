# Cross-Project Sync Report — 2026-08-07 (Round 2)

**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../maintenance/cross-project-sync.md)
**Scope**: Xcind PRs [#82](https://github.com/scinddev/xcind/pull/82) `07de51f`,
[#83](https://github.com/scinddev/xcind/pull/83) `5b4b9f4`,
[#85](https://github.com/scinddev/xcind/pull/85) `63223d3`,
[#86](https://github.com/scinddev/xcind/pull/86) `d9d9a8f`,
[#87](https://github.com/scinddev/xcind/pull/87) `a5f9494`,
[#88](https://github.com/scinddev/xcind/pull/88) `92b0ea5` — round 1's
`known_excluded` set — plus post-close docs commits `d7afbd3`/`ce0da4c`.
**Scind canon**: `ca156eb`, unchanged since round 1 closed (every intervening
commit was round 1's own output).
**Ledger**: [`reconciliation-ledger-round-2.{md,json}`](../sync/artifacts/reconciliation-ledger-round-2.md)
(RL-116…RL-142, global sequence).

| Category | New deltas | Applied to Scind | To P7 | Xcind backlog | Escalated |
|----------|-----------:|-----------------:|------:|--------------:|----------:|
| CANON-CHANGE | 1 | 1 | — | — | — |
| PROMOTE | 17 | 17 | 0 | — | 0 |
| CANON-OVERREACH | 0 | — | — | — | — |
| CANON-CONFIRM | 3 | 1 (footnote) | — | — | — |
| DIVERGENCE / DEFERRED | 3 | — | 0 new (all already covered) | — | — |
| NOT-IMPL / UNTESTED | 0 | — | — | 0 | — |
| ESCALATE | 0 | — | — | — | 0 |

Plus one REGISTRY-UPDATE (divergence 0034 → Resolved), one NO-DELTA (PR #87
resolve-help), one PROCESS row (this round's artifact refresh).

- **Precondition**: Xcind self-sync green — the `ce0da4c` LDS audit covered
  exactly this round's PRs ("all drift was docs-stale; no code changed") and
  `make check` passed 137/137. No areas excluded.
- **Correspondence-map delta**: 11 rows refreshed with `R2:` clauses, 2 rows
  added (Xcind ADRs 0021, 0022). ADR table: targeting flips
  SCIND-ONLY → **DIVERGED-DECISION** (Scind 0011 ↔ Xcind 0023, same class as the
  0013/0017 apex row); **External proxy mode** lands as MATCH after promotion
  (Scind ADR-0017 ↔ Xcind ADR-0022).
- **Standing divergences re-audited**: 22 Active Design/Scope entries. 21
  STILL-JUSTIFIED (stamped in `registry.json`); **0 flipped to CANON-CHANGE**;
  **1 resolved by convergence** — 0034 (explicit `workspace destroy`): Xcind PR
  #86's `dispose` cascade falsified the "Xcind needs less teardown" premise;
  Xcind converged to canon, canon unchanged. Follow-up: re-check 0026's
  destroy-facet wording next round. Watch item: 0028 (workspace up/down
  orchestration) is increasingly likely to close soon — `workspace dispose`
  proves the per-app iteration pattern it needs.
- **Scind PR(s)**: [scinddev/scind#8](https://github.com/scinddev/scind/pull/8)
  (branch `sync/round-2-canon`, commit `b82b9b1`) — **open at round close**;
  merge is pending a human action (the sandbox denied `gh pr merge`). All 19
  Scind-affecting ledger rows are APPLIED in that PR.

## Highlights

- **External proxy mode is the headline PROMOTE** (RL-116…RL-130, new Scind
  **ADR-0017**): canon's `proxy.auto_start: false` names the
  externally-managed-proxy case but couldn't deliver it — the hardcoded network
  name, entrypoint names, and missing certresolver made the emitted labels
  unconsumable by a foreign Traefik. Xcind proved the gap is three configurable
  values wide. `proxy.certresolver` is also canon's first ACME path, deliberately
  mode-independent.
- **`scind proxy destroy`** (RL-131): canon had no proxy teardown verb at all,
  and the port-inventory model never accounted for a proxy-state wipe; the
  "proxy destroyed" event is now a third port-release trigger.
- **`scind app get <path>`** (RL-136): single-value resolved-config lookup,
  adopting Xcind's path grammar and exit-code contract but not its
  `--cached`/`--hooks-ttl` cache mechanics (those stay divergence-0020-shaped).
- **One CANON-CHANGE** (RL-140): the Traefik dashboard is not an entrypoint —
  the spec's `dashboard | 8080` entrypoint row described a mechanism that
  doesn't exist; also fixed the blanket "HTTP redirects to HTTPS" wording to
  per-export `tls: require`.
- **Nothing from PRs #82/#87/#88 changed canon**: yq compatibility is inside the
  Bash-vs-Go divergence (0001); resolve-help is a hand-rolled-parser artifact;
  the cache-refresh fix confirms an ordering rule canon already stated
  (Generation Logic step 10 gains a one-clause second confirmation).
