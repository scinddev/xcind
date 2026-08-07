# Cross-Project Sync — Scind ↔ Xcind (Standing Procedure)

**For AI Agents**: This is the **repeatable** procedure for reconciling the Scind
design canon with the Xcind implementation. It is the cross-repo analog of
[`sync.md`](./sync.md) (which syncs docs↔code *within* Xcind) and
[`audit.md`](./audit.md). Run it in rounds; each round produces a dated report.

**Relationship to `engineering/sync/`**: the `sync/` tree holds the **one-time**
P1–P7 planning effort (global context, per-plan docs, and the generated
artifacts). **This** document is the **standing process** distilled from that
effort — run it when you need to sync the two projects again, without re-reading
all the plans.

**Path alias**: Scind `docs/` ≡ `engineering/` as of [scinddev/scind#5](https://github.com/scinddev/scind/pull/5) — read any `scind/docs/…` path in an older sync artifact as `scind/engineering/…`; do not mass-rewrite those artifacts (`RL-038`).

---

## 0. Directionality — read this first (global-context §2)

> **Scind is canon. Xcind's lessons upgrade the canon.**
>
> For every difference you find, ask: *Does this teach that the **design** was
> wrong → change Scind (a **learning**). Or does it only reflect **how Xcind
> chose to implement** it → record a **divergence**?*
>
> **DIVERGENCE must be earned.** To file something as a divergence you must state,
> in one sentence, **why Scind should NOT adopt Xcind's approach.** If you can't,
> it is a **CANON-CHANGE**, not a divergence. When genuinely unsure, route to
> **CANON-CHANGE** or **ESCALATE** — **never** silently to DIVERGENCE. A false
> learning is cheap and reversible (a rejected Scind proposal); a false
> divergence permanently buries an insight (§2a).

**The comparison surface** is `scind/engineering/` (canon; was `scind/docs/`
before the rename — see the path alias above) ↔ `xcind/engineering/`
(eng-docs), backed by Xcind's as-built `bin/` + `lib/xcind/`. Xcind's user-facing
`docs/` (Diátaxis) is out of scope except as corroborating behavior evidence.
**Go-vs-Bash** language/build/packaging differences are a permanent expected
divergence (§5) — never flag them as drift.

### Decision tree (mirrors `sync.md`'s, for the cross-repo case)

```
Divergence found between Scind canon and Xcind as-built/eng-docs:
├─ Xcind proved the design wrong? ........... change Scind        (CANON-CHANGE)
├─ Xcind built something better/new? ........ promote to Scind    (PROMOTE)
│                                              or record divergence (if earned)
├─ Scind over-specified / gold-plated? ...... trim Scind          (CANON-OVERREACH)
├─ Xcind intentionally differs? ............. divergence registry (DIVERGENCE /
│                                              DELIBERATELY-DEFERRED → P7)
└─ Xcind just behind? ....................... Xcind backlog        (NOT-IMPLEMENTED /
                                               IMPLEMENTED-UNTESTED)
```

---

## When to run (cadence)

| Trigger | Why |
|---------|-----|
| **Before a Scind milestone** | Fold accumulated Xcind learnings into canon before it is built for real. |
| **After major Xcind features** | New as-built capability is the richest source of learnings/divergences. |
| **Per the success criteria** | Keep the correspondence map, registry, and ADR table current (global-context §10). |
| **Quarterly, in maintenance mode** | Catch slow drift and re-audit standing divergences (Step 5). |

Do **not** run mid-feature; wait until Xcind's as-built is stable enough that
eng-docs describe it faithfully (that is what Step 1 gates on).

---

## The procedure

### Step 1 — Precondition: Xcind self-sync must be green (the P1 gate, generalized)

Every cross-project finding assumes Xcind's eng-docs faithfully describe Xcind's
as-built code. If they have self-drifted, you would be comparing Scind against a
**stale mirror** and manufacturing false learnings and false divergences.

1. Run [`sync.md`](./sync.md) end-to-end (or confirm a recent green run). Resolve
   all reference/spec/ADR drift **first**.
2. Run `make check` — it must pass with **no** code changes (docs-only round).
3. For any area you could not verify, mark it **untrusted** and exclude it from
   this round's comparison (note the exclusion in the report). Only trust
   eng-docs for the areas Step 1 verified.

> **Do not proceed** to Step 2 until Xcind eng-docs ↔ as-built is reconciled for
> the areas you intend to compare.

### Step 2 — Refresh the correspondence map

Re-run the P2 method and **diff against the committed baseline** to find *new*
divergence since the last round.

**First, read the watermark.**
[`engineering/sync/artifacts/sync-baseline.json`](../sync/artifacts/sync-baseline.json)
records, per round, the commit in each repo that the committed artifacts reflect.
The **last entry** is this round's starting point, and it carries the two `git
log` commands that list exactly what changed since. Use that range to **scope**
the rebuild — it tells you which files can possibly have moved, so you compare
those instead of all ~165.

> The range is a focusing device, **not** the source of truth. The map diff in
> substep 2 is what decides the round's work: a file the range misses (a
> submodule bump, a change landed outside the range, an artifact edited by hand)
> still shows up there. Never skip the diff because the range looked empty.

1. Rebuild the file↔file map + ADR reconciliation + presence/status matrix over
   `scind/engineering/` ↔ `xcind/engineering/`, keying on **topic, not ADR number**
   (see [ADR-0021](../decisions/0021-cross-repo-adr-cross-referencing.md)).
2. Diff the new map against the committed
   [`engineering/sync/artifacts/correspondence-map.json`](../sync/artifacts/correspondence-map.json).
   Only the **new/changed** rows are this round's work.
3. Update the topic-keyed **ADR correspondence table** (ADR-0021): add any new
   ADR in either repo; classify each pair `ALIGNED` / `DIVERGED-DECISION` /
   `SCIND-ONLY` / `XCIND-ONLY`.

### Step 3 — Triage the new deltas

Classify each new/changed delta with the P3/P4/P5 vocabulary. Use the decision
tree above; apply the §2a burden-of-proof (earn every DIVERGENCE).

| Direction | Labels | Destination |
|-----------|--------|-------------|
| Xcind reveals a canon defect | `CANON-CHANGE` | Change Scind (Step 4) |
| Xcind has a capability Scind lacks | `PROMOTE` (adopt) or `DIVERGENCE` (if earned) | Scind (Step 4) or P7 |
| Scind over-specified | `CANON-OVERREACH` | Trim Scind (Step 4) |
| Xcind validated an unproven decision | `CANON-CONFIRM` | Annotate Scind (low priority) |
| Xcind intentionally differs | `DIVERGENCE` / `DELIBERATELY-DEFERRED` | P7 registry |
| Scind spec unbuilt in Xcind | `NOT-IMPLEMENTED` / `IMPLEMENTED-UNTESTED` | Xcind backlog |
| §2 not cleanly applicable | `ESCALATE` | Human product call |

Record every delta as a row in **this round's reconciliation ledger**, modelled
on the `source-review-*.md` ledgers: stable ledger ID, source finding ID as join
key, action type, target file, priority, status. Merge deltas that two directions
surface into one edit (note the `merge_with`).

**One ledger per round.** The P6 ledger
([`reconciliation-ledger.md`](../sync/artifacts/reconciliation-ledger.md) +
`.json`) is **closed** — it is the historical record of the one-time P1–P7
effort, and no new rows go into it. Each later round writes a new pair:

```
engineering/sync/artifacts/reconciliation-ledger-round-{N}.{md,json}
```

Copy the P6 ledger's structure (`meta` + `rows[]`, same field names and status
vocabulary) so the rounds stay diffable against each other.

**`RL-` IDs are global and never reused.** Allocate from one sequence across all
rounds, so a row ID identifies a finding unambiguously no matter which ledger
holds it. Find the next ID with:

```bash
grep -ho 'RL-[0-9]\+' engineering/sync/artifacts/reconciliation-ledger*.json \
  | sort -u | tail -1
```

Round 2 therefore starts at **`RL-116`** (P6 ended at `RL-115`). Never renumber a
row from an earlier round; if a finding recurs, reference the original ID rather
than minting a second one.

### Step 4 — Reconcile

- **Apply canon changes to Scind.** For `CANON-CHANGE` / `PROMOTE` /
  `CANON-OVERREACH` / `CANON-CONFIRM`, edit the Scind working tree following
  Scind's own conventions (`DOCUMENTATION-GUIDE.md`, ADR template,
  single-source-of-truth). A promoted capability gets a **new Scind ADR crediting
  Xcind as the validating implementation**. **Land via a Scind branch + PR** — never
  push to Scind `main` directly; put a ledger-row → edit mapping in the PR body.
  Flip each applied row in **this round's** ledger `PLANNED → APPLIED` with the
  Scind PR reference.
- **Record divergences in the P7 registry.** Each must pass the P7 admission gate
  (an earned "why Scind should NOT adopt"); design/scope divergences get the
  adversarial re-check. **Do not** pave a learning into a divergence.
- **File Xcind backlog items** for `NOT-IMPLEMENTED` / `IMPLEMENTED-UNTESTED`
  (the latter is a ⚠️ latent-bug flag — prioritize tests).
- **Xcind doc corrections** (reverse learnings, self-drift fixes) land here via
  Xcind's normal `make check` + PR flow.

### Step 5 — Re-audit standing divergences (the reverse path)

This is the guaranteed **divergence → learning → canon** path, so no insight
stays paved over as Scind matures.

1. For every **Active** Design/Scope entry in the
   [P7 divergence registry](../sync/divergence/), re-run the **canon-neutrality
   test**: can you *still* write, in one sentence, why Scind should not adopt
   Xcind's approach?
2. If a divergence **no longer justifies itself** (Scind's design moved, or new
   evidence arrived), it is a **newly surfaced learning**: flip it to
   `CANON-CHANGE` and feed it back into Step 4. The registry keeps the original
   canon-change question each divergence was tested against, so this is a lookup,
   not a re-derivation.
3. Leave still-justified divergences Active, but stamp them re-audited this round.

### Step 6 — Report

Write a dated audit report, same shape as `archive/sync-audit-*.md`:

> **Cross-Project Sync Report — {date}**
>
> | Category | New deltas | Applied to Scind | To P7 | Xcind backlog | Escalated |
> |----------|-----------:|-----------------:|------:|--------------:|----------:|
> | CANON-CHANGE | {N} | {N} | — | — | — |
> | PROMOTE | {N} | {N} | {N} | — | {N} |
> | CANON-OVERREACH | {N} | {N} | — | — | — |
> | DIVERGENCE / DEFERRED | {N} | — | {N} | — | — |
> | NOT-IMPL / UNTESTED | {N} | — | — | {N} | — |
> | ESCALATE | {N} | — | — | — | {N} |
>
> - **Precondition**: Xcind self-sync green? {yes/excluded areas}
> - **Correspondence-map delta**: {rows changed}
> - **Standing divergences re-audited**: {N}; **flipped to CANON-CHANGE**: {ids}
> - **Scind PR(s)**: {url(s)}

Commit the report and the updated ledger + correspondence map. Re-check that all
cross-links resolve and (for any Xcind edits) `make check` is green.

**Then stamp the watermark — this is what makes the next round cheap.** Append a
round entry to
[`sync-baseline.json`](../sync/artifacts/sync-baseline.json), following the
`rounds[]` shape already there:

- `xcind.reviewed_through` — the last Xcind commit whose content this round's
  map and ledger actually reflect. **Not** simply `HEAD`: exclude any commit that
  landed after you rebuilt the map, and record it under `known_excluded` with a
  reason so the next round picks it up instead of assuming it was triaged.
- `scind.canon_at_close` — Scind `main` after this round's PRs merged.
- `next_round_diff` — the two `git log` commands, with this round's SHAs
  substituted, so the next round can copy-paste them.

A round is not finished until this entry exists. Skipping it costs the next round
a full 165-file rebuild to rediscover a boundary you already knew.

---

## Quick reference

### Artifacts this procedure reads/writes

| Artifact | Role |
|----------|------|
| `engineering/sync/artifacts/sync-baseline.json` | **Read first, written last.** Per-round commit watermark for both repos + the `git log` commands that scope the round. |
| `engineering/sync/artifacts/correspondence-map.{md,json}` | The topic-keyed baseline (incl. ADR table); diffed each round. |
| `engineering/sync/artifacts/reconciliation-ledger.{md,json}` | **Closed** (P6, the one-time P1–P7 effort). Historical; read-only. |
| `engineering/sync/artifacts/reconciliation-ledger-round-{N}.{md,json}` | This round's action items. New pair per round; `RL-` IDs continue the global sequence. |
| `engineering/sync/divergence/` | **P7-owned** divergence registry; Step 5 re-audits it. |
| `engineering/decisions/0021-*.md` | ADR-numbering / cross-referencing policy. |
| `archive/sync-audit-*.md` | Dated per-round reports. |

### Recurring high-drift areas (checklist — from P3 `L-0033`)

Watch these first each round; they drifted repeatedly in the source-review sweep:

- Cache-key input lists (env files, additional configs, `XCIND_TOOLS`,
  host-gateway detected value).
- Hook label ownership (which hook emits which context label).
- Project-layout trees (missing current entrypoints/libraries).
- "Stateless" wording (Xcind *does* keep a registry + assigned-port state).
- Apex / TLS behavior descriptions lagging the TLS implementation.

### Guardrails

- **Never** run this without Step 1 green — you would compare against a stale
  mirror.
- **Never** invent divergence IDs or write under `engineering/sync/divergence/`
  outside the P7 registry's own process.
- **Never** add rows to the closed P6 ledger, and **never** reuse or renumber an
  `RL-` ID — the sequence is global across rounds.
- **Never** trust the commit range alone to define the round's work. It scopes
  the rebuild; the map diff decides.
- **Never** push to Scind `main` — branch + PR only.
- **Never** flag Go-vs-Bash idiom/build/packaging as drift (§5).
- When two directions surface the same fact, **merge to one edit** — don't apply
  a canon change twice.
