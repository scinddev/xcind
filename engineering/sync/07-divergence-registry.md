# P7 — Divergence Registry Design

**Prerequisite for content**: P3, P4, P5, P6 (they populate it).
**Design may start**: as soon as [P2](./02-correspondence-map.md) exists.
**Read first**: [`00-global-context.md`](./00-global-context.md) — §2, §6.

---

## Goal

Design and stand up the **durable, living record of intentional Scind↔Xcind
divergences** — the places Xcind knowingly differs from canon and intends to keep
differing. This is where "Xcind will continue to diverge from Scind" gets
documented so it is not mistaken for drift on the next sync round.

This serves your original goal #5. Per your direction, the registry lives in the
**Xcind repo** (Xcind is the one that diverges), and is substantial enough to be
its **own subdirectory**, not a single file.

## Where it lives

```
engineering/
  sync/
    divergence/               ← the registry (this plan's deliverable)
      README.md               ← index + how the registry works
      0001-bash-vs-go-tech-stack.md
      0002-two-track-documentation.md
      NNNN-{slug}.md          ← one file per divergence
      registry.json           ← machine-readable roll-up
```

Rationale for a directory over one file: divergences carry real rationale
(context, why Scind should *not* adopt it, revisit conditions), they accrete over
time, and they need stable IDs for cross-referencing from ADRs and the
correspondence map — the same reasons ADRs are one-file-each.

> **Relationship to `engineering/decisions/`**: an ADR records *why Xcind decided
> something*; a divergence entry records *why that decision differs from Scind and
> stays that way*. Xcind-only ADRs (e.g. two-track-documentation) will each have a
> corresponding divergence entry that links to the ADR — the ADR is the decision,
> the divergence entry is the standing exception to canon.

## Admission gate: a divergence must be *earned*

Per [global-context §2a](./00-global-context.md), this registry is **not** a
catch-all for "things that differ." An item is admitted **only if it passes both
tests**:

1. **Intent test** — the difference is either *forced* (Bash/structural) or a
   *deliberate product-scope choice*, stated in one sentence.
2. **Canon-neutrality test** — adopting Xcind's approach into Scind would **not**
   improve the design. You must be able to write the "Why Scind should NOT adopt"
   field convincingly. **If you cannot, the item is a CANON-CHANGE (a learning),
   not a divergence** — send it back to P3/P6; do not admit it here.

**High-risk entries require an adversarial second opinion.** For any entry in the
**Design** or **Scope** category, a second reviewer (subagent) must attempt to
prove it is a *mislabeled learning* before it is admitted; the entry is recorded
only if that attempt fails. **Structural** and **Process** entries (Bash vs Go,
config-file format vs env-vars, two-track docs) are low-risk and admitted on a
one-line justification. This matches the guiding intuition: implementation-shape
divergences are safe; **design-assumption divergences are where lost learnings
hide.**

## Entry schema

Each `NNNN-{slug}.md`:

```markdown
# Divergence NNNN: {short title}

**Status**: Active | Superseded | Resolved (canon changed to match)
**Scind canon**: docs/{path} (or "none — Scind is silent")
**Xcind reality**: bin/… , lib/… , engineering/{path}
**Category**: Structural | Design | Scope | Process
**Origin**: {P3 L-xxxx | P4 XA-xxxx | P5 SA-xxxx | pre-existing}

## What differs
{One paragraph: what Scind says/implies vs what Xcind does.}

## Why Xcind diverges
{The reason. For Bash-isms: the language forced it. For scope: deliberate cut.}

## Why Scind should NOT simply adopt Xcind's approach
{The key field — this is what makes it a *divergence* and not a learning.
If you cannot write this convincingly, STOP: this is a CANON-CHANGE, not a
divergence. Route it back to P3/P6.}

## Canon-change test (required)
{Was this seriously considered as a CANON-CHANGE? State the strongest argument
that it proves a Scind assumption wrong, and why that argument was rejected. For
Design/Scope entries, name the adversarial reviewer/pass that challenged it. This
field guarantees the learning is never silently lost — a later round can reopen
it from here.}

## Revisit conditions
{What would make us reconsider — e.g. "when Scind's Go impl exists," "if users ask."}

## Links
- Related ADR(s), correspondence-map row(s), reconciliation-ledger ID(s).
```

The machine-readable `registry.json` mirrors the frontmatter fields so P6's
cross-project sync procedure can diff "known divergences" against "newly observed
deltas" and only surface *unexpected* ones.

## Seed entries (known before P3–P5 finish)

These are certain enough to draft during design:

1. **Bash vs Go tech stack** — the permanent structural divergence
   (global-context §5). Category: Structural. Scind should not adopt Bash; Xcind
   will not rewrite in Go (it is the *prototype*).
2. **Two-track documentation** (Xcind ADR-0014) — Xcind splits user/engineering
   docs; Scind (docs-only) has no user track. Category: Process.
3. Any `DIVERGED` ADR rows from P2 where the decision genuinely differs.

## Categories (for filtering + triage)

| Category | Meaning | Typical fate |
|----------|---------|--------------|
| **Structural** | Language/build/packaging — permanent by nature. | Permanent. |
| **Design** | A design choice Xcind made against canon on purpose. | Long-lived; revisit if canon evolves. |
| **Scope** | Xcind deliberately doesn't do something Scind specifies. | May resolve when Xcind catches up — or stay. |
| **Process** | Docs/workflow/tooling difference. | Permanent-ish. |

## How the registry stays alive

Wire it into the standing process (P6's `cross-project-sync.md`):

- Every sync round diffs observed deltas against `registry.json`. A delta that
  matches an **Active** entry is *expected* — skip it. A delta with no entry is
  *new* and must be triaged (learning vs new divergence).
- **Re-audit Design/Scope entries each round (the reverse path).** Structural and
  Process divergences are stable, but Design/Scope entries can turn out to be
  learnings as the Scind design matures or new Xcind evidence arrives. Every sync
  round re-runs the canon-neutrality test on every **Active** Design/Scope entry;
  if one no longer justifies itself, it is a *newly surfaced learning* — flip it
  to `CANON-CHANGE` and route to P6. This is the guaranteed
  **divergence → learning → canon** path, so nothing stays paved over.
- When a divergence is **resolved** (Scind changed to match, or Xcind adopted
  canon), flip status to `Resolved`/`Superseded` — keep the record for history.
- Link every registry entry from the relevant Xcind ADR and correspondence-map
  row so a reader landing on either finds the exception.

## Subagent fan-out

1. **Schema/skeleton agent** — create `divergence/README.md`, the entry
   template, `registry.json` skeleton, and the seed entries above.
2. **Population agents** (after P3/P4/P5) — one per source: convert each
   `DIVERGENCE` / `DELIBERATELY-DEFERRED` finding into an entry. Partition by
   source file to avoid ID collisions; assign IDs from a single sequence.

## Done criteria

- [ ] `engineering/sync/divergence/` exists with README, template, `registry.json`.
- [ ] Seed entries (Bash/Go, two-track docs, any `DIVERGED` ADRs) written.
- [ ] Every P3 `DIVERGENCE`, P4 `DIVERGENCE`, P5 `DELIBERATELY-DEFERRED` has an entry.
- [ ] Each entry links back to its origin finding + related ADR + map row.
- [ ] The registry is referenced by P6's `cross-project-sync.md` as the
      expected-divergence baseline.
