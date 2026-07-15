# P1 — Phase 0 Gate: Reconcile Xcind Eng-Docs ↔ As-Built

**Prerequisite for**: everything. Do not start P2 until this gate reports clean.
**Read first**: [`00-global-context.md`](./00-global-context.md), especially §8
(trust prerequisite) and §7 (vocabulary — "self-drift").

---

## Why this exists

The entire cross-project effort compares Xcind's **eng-docs** (`engineering/`)
against Scind's **canon** (`docs/`). That comparison is only meaningful if
Xcind's eng-docs actually describe Xcind's **as-built** code (`bin/`,
`lib/xcind/`). Source-review Rounds 1–5 closed in May 2026, but work has landed
since (host-env symmetry, `XCIND_INSTANCE` worktree isolation, apex-url
reporting, and more). Assume **self-drift is present** until proven otherwise.

**Gate rule:** cross-project findings in P2–P7 may only rely on eng-doc areas
this phase has verified. Anything left unverified here must be re-verified
against code at point of use downstream.

## The process to run

Run Xcind's existing LDS sync process end to end:

> **`engineering/maintenance/sync.md`** — the authoritative docs↔code
> reconciliation process. It audits reference docs, runs behavior tests,
> verifies cross-links, checks specs against implementation, reviews ADR
> currency, resolves drift, and produces an audit report.

Supplement with `engineering/maintenance/audit.md` (inventory/completeness) only
if `sync.md` surfaces structural gaps. Do **not** substitute `update.md` or
`refine.md` — those are for known changes and quality polish, not drift
discovery.

This is a **docs-fixing** pass: where eng-docs are wrong and code is right,
update the eng-docs (canonical for *Xcind*). Where code appears wrong versus a
still-valid ADR, file it as an implementation bug — **do not** silently rewrite
the ADR.

## Scope emphasis — verify the recently changed surface first

`sync.md` is comprehensive, but prioritize the areas most likely to have drifted
since the last source review. Confirm the current set from git, then focus:

- **Instance / worktree isolation** — `XCIND_INSTANCE`, project-name folding,
  workspace network naming.
- **Host env symmetry** — `XCIND_HOST_ENV_FILE` and the host-view env file.
- **Apex URL reporting** — ADR-0017 and its spec/behavior/reference surface.
- **Assigned ports** — release/prune lifecycle, generation-cache interaction.
- **Hook lifecycle** — the seven hooks, ownership, SHA cache key scope
  (flagged as understated in the 2026-04-11 audit).

Cross-check every `bin/xcind-*` `--help` and every user-facing variable in
`lib/xcind/*.bash` against `engineering/reference/cli.md` and
`engineering/reference/configuration.md`.

## How to parallelize (subagent fan-out)

Split by **LDS layer × code area** so write scopes don't collide. Suggested
`Explore`/`general-purpose` agents (read-only discovery first, then a focused
editing pass):

1. **Reference auditor** — `reference/cli.md` + `reference/configuration.md` vs
   `bin/*` `--help` and `lib/xcind/*` variables.
2. **Specs auditor A** — proxy, ports, docker-labels, host-gateway vs
   `xcind-proxy-lib.bash`, `xcind-host-gateway-lib.bash`.
3. **Specs auditor B** — config-resolution, context-detection, env vars,
   generated overrides, naming vs `xcind-lib.bash`, `xcind-discovery-lib.bash`,
   `xcind-naming-lib.bash`, `xcind-app-env-lib.bash`.
4. **Lifecycle auditor** — workspace-lifecycle, application-lifecycle,
   hook-lifecycle vs `xcind-workspace-lib.bash`, `xcind-app-lib.bash`,
   `xcind-registry-lib.bash`, `xcind-bootstrap.bash`.
5. **ADR currency auditor** — every ADR's "Accepted" status and implementation
   alignment; flag any superseded-without-marking.

Each agent returns a structured drift list (see output artifact). A single
coordinating pass then applies fixes and runs `make check`.

## Output artifact

Write **`engineering/sync/artifacts/p1-self-sync-report.md`** modeled on the
existing `engineering/archive/sync-audit-YYYY-MM-DD.md` reports:

```markdown
# Xcind Self-Sync Report (Phase 0)

**Date**: {date}     **Commit**: {sha}

| Category | Issues Found | Resolved | Remaining (bug filed) |
|----------|--------------|----------|-----------------------|
| CLI Reference | | | |
| Config Reference | | | |
| Specifications | | | |
| Behaviors (Gherkin) | | | |
| Cross-Links | | | |
| ADRs | | | |

## Verified-clean areas   ← P2+ may trust these
- ...

## Unverified / low-confidence areas   ← P2+ must re-check against code
- ...

## Implementation bugs filed (code wrong vs valid ADR)
- ...
```

The **"Verified-clean" vs "Unverified"** split is the load-bearing output — it
tells every downstream plan which eng-doc claims are trustworthy.

## Done criteria

- [ ] `sync.md` process completed across all LDS layers.
- [ ] `make check` passes (no accidental code changes; behavior tests green).
- [ ] Recently changed surface (§ above) explicitly verified.
- [ ] `p1-self-sync-report.md` committed with the verified/unverified split.
- [ ] Any code-wrong-vs-ADR cases filed as implementation bugs, not doc rewrites.
