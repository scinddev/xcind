# Divergence 0028: Workspace-wide up/down/restart orchestration

**Status**: Resolved (2026-08-07, round 4 — Xcind converged; see below)
**Scind canon**: `docs/reference/cli.md`, `docs/specs/workspace-lifecycle.md` (one command brings the whole workspace up/down/restart)
**Xcind reality**: workspace-wide `xcind-workspace up` / `down` since `12737f8`; per-app path via `xcind-compose` remains
**Category**: Scope
**Origin**: P5 SA-0013

## What differs
Scind orchestrates the whole workspace with one command — `up`/`down`/`restart`
across all apps. Xcind operates **per app directory** (each app up/down'd via
`xcind-compose`); its workspace command surface is `init`, `dispose`, `status`,
`list`, `register`, `forget` — no workspace-level up/down loop.

## Why Xcind diverges
Xcind kept workspace-level operations minimal; bringing apps up/down was left to the
per-app path. It is genuinely absent, not designed-against — the highest-value
"reconsider" candidate in P5.

## Why Scind should NOT simply adopt Xcind's approach
Nothing to adopt — this is the **inverse of a divergence-to-canon**. One-command
orchestration of a multi-app workspace is a **core value proposition** of a workspace
tool. Xcind **already loops every app** in two places: `status` enumerates the app
dirs (`bin/xcind-workspace:318-352`) and — since PR #86 — `dispose` iterates them
running a per-app subcommand with per-app failure collection
(`bin/xcind-workspace:1033-1053`). That second loop is exactly the shape a workspace
`up`/`down` needs: enumerate, invoke `xcind-compose <verb>` per app, collect
failures. Xcind's deferral reveals Xcind **under-built** — it *reinforces* Scind's
spec.

## Canon-change test (required)
**Strongest canon-change argument (attempted):** "Xcind operates per-app fine, so
maybe Scind demands orchestration Xcind proved unnecessary." **Why it collapsed
(adversarial re-check PERFORMED — P7, special scrutiny):** the reviewer found this is
the exact inverse of overreach — orchestration is core value, and Xcind's `status`
already loops apps, so the up/down loop is a natural win Xcind simply hasn't built.
There is **no signal Scind over-specified.** Verdict: **SURVIVES-AS-DIVERGENCE
(strong)** — and it is really a **NOT-IMPLEMENTED-flavored easy win for Xcind's
backlog**, never a canon defect.

## Revisit conditions
This should **resolve** when Xcind adds the workspace up/down loop (a thin iteration
over app dirs — `dispose` already proves the exact enumerate/invoke/collect-failures
pattern, so the remaining work is wiring `xcind-compose up|down` into it). Re-tested
2026-08-07 (round 3): `xcind-workspace` still has no `up`/`down`/`restart`
subcommand, so the divergence stands, now one proven loop away from closing.
Highest-value reconsider candidate — re-check each round; likely a short-lived
divergence.

## Resolution (2026-08-07, round 4 — RL-147)

The revisit condition triggered exactly as predicted. Xcind commit `12737f8`
(2026-08-07) shipped `xcind-workspace up` and `xcind-workspace down`: the
enumerate/invoke/collect-failures loop `dispose` proved, wired to
`xcind-compose up -d` / `down` per application, with `down` confirming first
(`--yes` to skip). This is the shape canon's `workspace up`/`down` specify —
per-app compose execution across the whole workspace with per-app failure
reporting. **Xcind converged to canon; canon was validated, not disproven — no
Scind edit.** Residual differences stay beneath registry granularity, recorded
as Xcind backlog instead (ledger RL-150): the `restart` verb (canon defines it
as exactly `down` followed by `up`, so it is a composition Xcind has not
wrapped), per-app `-a` targeting, and `down --volumes`. None contradicts the
resolved core claim — Xcind now has one-command workspace orchestration.

## Links
- Origin finding: P5 SA-0013 (P5's highest-value reconsider candidate; Xcind backlog)
- Related ADR(s): Scind/Xcind ADR-0010 (up/down verb semantics — the *verbs* MATCH)
- Correspondence-map row(s): `reference/cli.md` (PARTIAL),
  `specs/workspace-lifecycle.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0013
