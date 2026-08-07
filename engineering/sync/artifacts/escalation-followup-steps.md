# Escalation Follow-up — Remaining Steps (ordered)

**Companion to**: [`escalation-decision-brief.md`](./escalation-decision-brief.md)
**Date**: 2026-08-05

Each step below has a short prompt you can paste into a fresh Claude session in
the xcind repo. Steps 1–4 are sequential (3b and 4 both wait on Step 3). Steps
5–6 can run in parallel with steps 2–4. Step 7 closes the effort.

---

## Step 0 — Review the brief (you, no agent)

Read `escalation-decision-brief.md` and mark each of the 18 `DECISION:` lines
accept or reject. Add a short note wherever you reject or want a different
outcome — the later steps execute exactly what the boxes say.

## Step 1 — Commit the sync artifacts

> Commit the two new untracked files `engineering/sync/artifacts/escalation-decision-brief.md` and `engineering/sync/artifacts/escalation-followup-steps.md` to main in the xcind repo, following the pre-commit-check procedure. Docs-only change; use a commit message like `docs(sync): escalation decision brief + follow-up steps`. Do not touch the other untracked files at the repo root.

## Step 2 — Bookkeeping pass (Xcind PR: ledger + divergence registry)

> Read `engineering/sync/artifacts/escalation-decision-brief.md` and execute only the rows whose DECISION box is marked accept. Flip the matching ESCALATED rows in `reconciliation-ledger.md` and `.json` to resolved with a one-line resolution note referencing the brief. In `engineering/sync/divergence/`: extend entry 0032 with the label-schema deltas (dropped `proxy.` segment, no assigned-port labels); update the revisit-condition notes on 0017, 0020, 0022, 0023, 0024 per the brief; correct 0007's unsupported `path:` claim; and file new entries (TEMPLATE.md shape, plus `registry.json` and the README index) for each accepted DIVERGENCE: XA-0026 (proxy-init flags), XA-0021 (workspaceless mode), and the XA-0022/L-0037 self-declaration half of RL-098. Also annotate ledger backlog rows RL-080…RL-086 with their Linear ids BDS-112…BDS-118. Docs-only; run `make check` before committing anyway.

## Step 3 — Scind canon PR (batched accepted edits)

> In the scind repo (`/Users/beausimensen/Code/scind`): reset the checkout to origin/main (`241c991`), branch, and apply the accepted Scind edits from `xcind/engineering/sync/artifacts/escalation-decision-brief.md`: RL-107 (apex opt-out mechanism + fix the stale `behaviors/*.feature` and `naming-conventions.md:46` text that contradicts the hybrid apex rule), the RL-098 canon-change half (allow absolute/external `applications.path`, targeting via `-w`/`-a`), RL-106 (export-conditional proxy start + `proxy.auto_start` knob), RL-109 (per-app `diagnose` command at intent level), RL-110 (zero-config compose/env defaults), and the small cleanup riders from RL-095 (visibility enum + `workspace.visibility` label name + advisory-metadata wording) and RL-096 (the stale manifest "Caching" bullet). Check first whether pending PROCESS row RL-094 (drop `behaviors/`) should execute in the same PR — if yes, skip the feature-file fixes. Open one PR; reference the brief in the description.

## Step 3b — RL-112 Scind binary PR (created by Step 5; after Step 3 merges)

> In the scind repo, from a fresh main: execute ledger row `RL-112`, now a CANON-CHANGE. Replace the sourced `scind-compose` shell function and the `compose-prefix` eval contract in `docs/specs/shell-integration.md` with a real `scind-compose` binary that resolves context internally and execs `docker compose`, and retire the empty-output error-detection workaround. Keep `compose-prefix` only if scripting consumers want the prefix text; keep wrapper generation as-is. Carry over a hardcoded completion fallback for hosts whose `docker` CLI lacks Cobra `__complete`. Reference `xcind/engineering/sync/artifacts/escalation-decision-brief.md` (§RL-112, FLIP APPLIED) and the xcind evidence in `test/test-xcind-completion.sh`. Then flip §3.1's `RL-112` entry in the xcind ledger from PLANNED to APPLIED with the PR reference.

**Why this is a separate step:** the flip happened during Step 5, after Step 3's
batch was already defined, so this edit is *not* in
[scinddev/scind#3](https://github.com/scinddev/scind/pull/3). Step 7 will not
catch the omission on its own — `RL-112`'s row status is already terminal
(RESOLVED); only the §3.1 planned-edits list still shows it as PLANNED.

## Step 4 — RL-038 rename PR (after Step 3 merges)

> In the scind repo, from a fresh main: `git mv docs engineering`, fix every relative link and path reference repo-wide, and add a placeholder `docs/README.md` stating the intent to house a future user-facing Diátaxis track (per XA-0043). Then in xcind, add a one-line path-alias rule ("scind `docs/` ≡ `engineering/` as of this PR") to `engineering/maintenance/cross-project-sync.md` and flip ledger row RL-038 to APPLIED with the PR reference. Do not mass-rewrite the existing sync artifacts' `docs/` paths — the alias rule covers them.

## Step 5 — RL-080: completion-function tests (decides RL-112) — ✅ DONE

> Execute ledger row RL-080 (P1, latent-bug): write behavioral tests in `test/` for the shell completion functions of `xcind-config`, `xcind-proxy`, and especially `xcind-compose`'s delegated docker-compose completion — the claim at `docs/guides/tools-ide-integration.md:17` is currently untested. Run them via `make test` and report pass/fail per function. Then apply the RL-112 flip recorded in the decision brief: if delegation works, note that RL-112 should become a CANON-CHANGE (Scind simplifies to a binary); if it fails, note the canon validation and fix the overstated Xcind doc claim.

**Done.** `test/test-xcind-completion.sh` — 137 assertions, all passing, wired into
`make test`, `contrib/test-all`, and CI (including the Bash 3.2 matrix). Every
shipped function passes: bash `_xcind_compose_completions` (delegated and
fallback), `_xcind_config_completions`, `_xcind_proxy_completions`,
`_xcind_workspace_completions`, `_xcind_application_completions`, plus all six
zsh `_xcind-*` functions. (The last two pairs were outside the row's named scope
but cost little once the harness existed.) No latent bug
found. Delegation is real — the binary's completion offers `docker compose`
subcommands absent from the fallback (`ls`, `watch`, `cp`), per-subcommand flags,
and compose-file service names — so the `tools-ide-integration.md:17` claim
stands unchanged and **RL-112 flipped to CANON-CHANGE**. Ledger rows RL-080 and
RL-112 and the decision brief are updated.

**New work this created:** RL-112 is now a PLANNED Scind canon change
(ledger §3.1) and is *not* in [scinddev/scind#3](https://github.com/scinddev/scind/pull/3).
It needs its own Scind PR, now written up as **Step 3b** above. Step 7's "no
PLANNED rows remain" check will *not* catch it — the row's status is already
terminal (RESOLVED); only §3.1's planned-edits list still carries it.

## Step 6 — Xcind small fixes (parallel-safe)

> Four small Xcind items from the escalation brief, one commit each: (1) inject `XCIND_HOST_GATEWAY` into `environment:` in `lib/xcind/xcind-host-gateway-lib.bash` (value already computed) and flip divergence 0022 to Resolved; (2) fix the guard gap where an app `.xcind.sh` setting `XCIND_WORKSPACE` silently overwrites the discovered workspace name in `__xcind-load-config`, matching `self-declaration.feature:17-22`, with a test; (3) document the `XCIND_CACHE_SCHEMA` SHA input in `engineering/specs/generated-override-files.md` and `hook-lifecycle.md`; (4) execute PROCESS rows RL-092 (explicit flavors-deferral sentence in ADR-0005) and RL-093 (new ADR recording the targeting-model deviation, per divergence 0021's note). Run `make check` before each commit.

## Step 7 — Close out the effort

> Verify every reconciliation-ledger row now has a terminal status (no ESCALATED or PLANNED remaining), the divergence `registry.json` and README index match the entry files, and `engineering/sync/00-global-context.md` §10 success criteria all hold. Update the ledger header status line, note the completion date, and summarize what closed in this pass. Flag anything still open (e.g. BDS-104, remaining Linear backlog) as explicitly outside the sync effort.

---

**Not part of this effort but still open** (from the project status memory):
BDS-104 (`xcind-workspace status` is instance-blind) and the Linear backlog rows
BDS-112…BDS-118 (executed opportunistically; RL-080 = BDS-112-range item is
Step 5 above).
