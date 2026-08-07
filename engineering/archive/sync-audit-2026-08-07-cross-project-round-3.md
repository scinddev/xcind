# Cross-Project Sync Report — 2026-08-07 (Round 3)

**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../maintenance/cross-project-sync.md)
**Scope**: A quiet round. The xcind range `ce0da4c..HEAD` contains only round 2's
own bookkeeping commits (`afec2a5`, `14f0ab7`); the scind range
`c63cbc6..origin/main` is empty (verified by fetch, not assumed). The round's
work is therefore the two follow-ups round 2 carried forward — divergence 0026's
destroy-facet wording and divergence 0028's re-test — plus a defensive
spot-check of the five recurring high-drift areas (P3 `L-0033`), per the
guardrail that the commit range scopes but never decides.
**Scind canon**: `c63cbc6`, unchanged since round 2 closed.
**Ledger**: [`reconciliation-ledger-round-3.{md,json}`](../sync/artifacts/reconciliation-ledger-round-3.md)
(RL-143…RL-146, global sequence).

| Category | New deltas | Applied to Scind | To P7 | Xcind backlog | Escalated |
|----------|-----------:|-----------------:|------:|--------------:|----------:|
| CANON-CHANGE | 0 | — | — | — | — |
| PROMOTE | 0 | — | — | — | — |
| CANON-OVERREACH | 0 | — | — | — | — |
| DIVERGENCE / DEFERRED | 0 | — | 0 | — | — |
| NOT-IMPL / UNTESTED | 0 | — | — | 0 | — |
| ESCALATE | 0 | — | — | — | 0 |

Plus two REGISTRY-UPDATEs (the carried follow-ups), one XCIND-DOC-FIX (RL-145),
and one PROCESS row (this refresh).

- **Precondition**: Xcind self-sync green — no content commits since the
  round-2 close, whose gate was green; `make check` re-run 137/137. No areas
  excluded.
- **Correspondence-map delta**: 0 rows. No rebuild needed: both repos sit at
  the exact commits the committed map reflects, the working tree matched the
  committed artifacts (no hand edits), and there are no submodules. In place of
  a rebuild, a subagent spot-checked the five recurring high-drift areas
  (cache-key inputs, hook label ownership, project-layout trees, "stateless"
  wording, apex/TLS): **4 CLEAN, 1 DRIFT** — see RL-145 below.
- **Standing divergences re-audited**: 2 with fresh re-checks (0026, 0028 —
  the carried follow-ups); both **STILL-JUSTIFIED**, wording refreshed. The
  other 20 Active Design/Scope entries carry their round-2 stamps: that
  re-audit ran earlier the same day and zero commits have landed in either repo
  since, so no canon-neutrality input changed. **0 flipped to CANON-CHANGE**.
- **Scind PR(s)**: none — zero canon-affecting rows; Scind's tree is untouched.

## Highlights

- **Divergence 0026** (workspace state machine): the carried follow-up. Its
  canon-change test cited "CLI facets 0033 and 0034" as if both were Active;
  0034 resolved by convergence in round 2. The wording now marks the facets'
  statuses and records why 0034's resolution leaves 0026 intact — both projects
  still infer state; Xcind gaining an explicit destroy *transition* validates
  canon's transition vocabulary without persisting any state machine (RL-143).
- **Divergence 0028** (workspace up/down orchestration): re-tested against the
  as-built. `xcind-workspace` still has no `up`/`down`/`restart`
  (`bin/xcind-workspace:1083-1092`), so the divergence stands — but `dispose`
  (PR #86) now proves the exact enumerate/invoke/collect-failures loop a
  workspace up/down needs (`bin/xcind-workspace:1033-1053`). The entry is one
  proven loop away from closing; still the highest-value Xcind-backlog easy
  win (RL-144).
- **The spot-check earned its keep** (RL-145):
  `engineering/implementation/project-layout.md` omitted
  `lib/xcind/xcind-discovery-lib.bash` from its Shared Libraries table and
  built-in hooks list, even though the hook is registered
  (`xcind-lib.bash:93,102`), spec-documented, and packaged. Pre-existing
  self-drift in a P3 `L-0033` recurring area, invisible to commit-range
  scoping — exactly why the procedure forbids trusting an empty range. Fixed
  in both tables; no canon impact.
