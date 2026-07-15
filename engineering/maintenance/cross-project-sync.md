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

**The comparison surface** is `scind/docs/` (canon) ↔ `xcind/engineering/`
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

1. Rebuild the file↔file map + ADR reconciliation + presence/status matrix over
   `scind/docs/` ↔ `xcind/engineering/`, keying on **topic, not ADR number**
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

Record every delta as a row in the **reconciliation ledger**
([`reconciliation-ledger.md`](../sync/artifacts/reconciliation-ledger.md) +
`.json`), modelled on the `source-review-*.md` ledgers: stable ledger ID, source
finding ID as join key, action type, target file, priority, status. Merge deltas
that two directions surface into one edit (note the `merge_with`).

### Step 4 — Reconcile

- **Apply canon changes to Scind.** For `CANON-CHANGE` / `PROMOTE` /
  `CANON-OVERREACH` / `CANON-CONFIRM`, edit the Scind working tree following
  Scind's own conventions (`DOCUMENTATION-GUIDE.md`, ADR template,
  single-source-of-truth). A promoted capability gets a **new Scind ADR crediting
  Xcind as the validating implementation**. **Land via a Scind branch + PR** — never
  push to Scind `main` directly; put a ledger-row → edit mapping in the PR body.
  Flip each applied ledger row `PLANNED → APPLIED` with the Scind PR reference.
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

---

## Quick reference

### Artifacts this procedure reads/writes

| Artifact | Role |
|----------|------|
| `engineering/sync/artifacts/correspondence-map.{md,json}` | The topic-keyed baseline (incl. ADR table); diffed each round. |
| `engineering/sync/artifacts/reconciliation-ledger.{md,json}` | Authoritative status record of every action item. |
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
- **Never** push to Scind `main` — branch + PR only.
- **Never** flag Go-vs-Bash idiom/build/packaging as drift (§5).
- When two directions surface the same fact, **merge to one edit** — don't apply
  a canon change twice.
