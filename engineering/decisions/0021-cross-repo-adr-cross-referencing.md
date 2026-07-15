# ADR-0021: Cross-Repo ADR Numbering & Cross-Referencing (Scind ↔ Xcind)

**Status**: Accepted

## Context

Xcind's `engineering/decisions/` and Scind's `docs/decisions/` are two independent
ADR series that describe **the same system** from two sides — Scind the design
canon, Xcind the Bash proof-of-concept. Their numbers were aligned for
`0001`–`0010`, then drifted (see
[sync global-context §4a](../sync/00-global-context.md#4a-adr-numbering-has-already-collided)):

| Scind ADR | Xcind ADR | Relationship |
|-----------|-----------|--------------|
| 0011 options-based-targeting | *(none)* | Scind-only number |
| 0012 layered-documentation-system | 0011 layered-documentation-system | Same decision, **off-by-one** |
| 0013 apex-url-primary-designation | 0017 apex-url-reporting | Related topic, **different number and different decision** |
| 0014 host-docker-internal-normalization | 0013 host-docker-internal-normalization | Same decision, different number |
| — | 0012, 0014, 0015, 0016, 0018, 0019, 0020 | **Xcind-only** |

So **"same ADR number" no longer means "same decision"** across the two repos,
and several decisions that *are* the same wear different numbers. Any
reconciliation (P6) or divergence tracking (P7) that keys on ADR *number* will
mis-join. We need one written, durable policy for how the two ADR series refer to
each other. This ADR decides that policy. Per the P6 plan (§A2) it lives in Xcind
because the cross-repo sync tooling lives here.

Three options were considered:

- **Option A — Topic-keyed cross-reference table.** Numbers stay divergent; a
  maintained table maps Scind ADR ↔ Xcind ADR **by topic**, marking each row
  aligned / diverged-decision / repo-only. Lowest churn, no renumbering, no
  broken links.
- **Option B — Renumber one repo to match the other.** E.g. Xcind adopts Scind's
  numbers. Cleanest long-term single namespace, but high churn: it breaks every
  inbound link (commits, PRs, handoffs, the source-review ledgers, prior sync
  artifacts), and it cannot fully succeed — each repo has decisions the other
  lacks (Xcind-only ADRs, Scind-only ADR-0011), so gaps or renumber-cascades are
  unavoidable. ADR-0014 accepted link breakage at *within-repo* scale; doing it
  *across* two repos multiplies that cost.
- **Option C — Shared ADR registry** in `engineering/sync/` that both repos
  reference as the single index of decisions.

## Decision

Adopt **Option A: a topic-keyed cross-reference table, with no renumbering.**
Each repo keeps its own ADR series and its own numbers; correspondence is
expressed **by topic** in a single maintained table, the **ADR correspondence
map**, hosted in Xcind (where the sync effort lives) as part of the P2
correspondence map — `engineering/sync/artifacts/correspondence-map.{md,json}` —
and refreshed by the standing procedure
([`cross-project-sync.md`](../maintenance/cross-project-sync.md)).

Option A **subsumes Option C**: the cross-reference table *is* the shared
registry, but it lives in the sync tree rather than as a third parallel ADR
directory, so neither repo's `decisions/` layout changes. Option B is rejected —
the churn and broken-link cost is not justified by a benefit the table already
delivers.

### Rules

1. **Number by repo, join by topic.** Never assume Scind-N ↔ Xcind-N. The
   correspondence table's topic key is authoritative; the ADR title is the
   stable join, not the number.
2. **Every cross-repo ADR reference is explicit and qualified.** Write
   "Scind ADR-0013" / "Xcind ADR-0017", never a bare "ADR-0013", whenever the
   two series could be confused. Within a repo, a bare "ADR-NNNN" continues to
   mean *that repo's* ADR.
3. **The correspondence table classifies each pair.** Each row is one of:
   `ALIGNED` (same decision, possibly different number),
   `DIVERGED-DECISION` (same topic, different decision → P7),
   `SCIND-ONLY`, or `XCIND-ONLY`.
4. **Divergence-encoding ADRs are marked and point at P7.** An Xcind ADR (or an
   Xcind-only *scope* within a shared ADR) that records a decision Scind will
   **not** adopt carries a short "**Divergence (→ P7)**" annotation linking the
   [divergence registry](../sync/divergence/) (P7's directory). Examples flagged
   by the P6 reconciliation ledger: **ADR-0005** (stateless scope — flavors and
   `state.yaml` dropped; see P5 `SA-0007`/`SA-0008`/`SA-0009`/`SA-0010` and P4
   `XA-0033`) and **ADR-0018** (own-app-only service-discovery scope; see P3
   `L-0026`). A *learning* ADR (e.g. ADR-0019 worktree isolation → Scind
   CANON-CHANGE) is the opposite and must **not** be annotated as a divergence —
   doing so would pave over the learning (§2a).
5. **Canon-change ADRs cite their Scind counterpart.** When an Xcind ADR drives a
   Scind change (P6 `CANON-CHANGE`/`PROMOTE`), it links the reconciliation ledger
   row and, once landed, the Scind ADR/PR that adopted it — as ADR-0019 already
   does in its "Relationship to Scind canon (P6)" section. New Scind ADRs created
   by promotion **credit Xcind as the validating implementation**.

## Consequences

### Positive

- **Zero renumbering, zero broken links.** Every existing inbound reference
  (handoffs, source-review ledgers, prior sync artifacts, git history) stays
  valid.
- One authoritative topic-keyed join, reused by P6 (reconciliation) and P7
  (registry), so both plans mis-join nothing.
- Divergence-vs-learning intent is visible **on the ADR itself**, protecting the
  §2a safeguard against silently paving learnings into divergences.

### Negative

- The correspondence table is a maintained artifact — a new ADR in either repo
  must be added to it (folded into the standing `cross-project-sync.md` cadence).
- Two number spaces persist, so readers must qualify cross-repo references by
  hand; mitigated by rule 2.

### Neutral

- Scind is unaffected structurally; if Scind later wants a reciprocal note, it
  links back to this table rather than renumbering.

## Related Documents

- [Sync: Global Context §4a](../sync/00-global-context.md) — the ADR collision this resolves
- [P6 Reconciliation Ledger](../sync/artifacts/reconciliation-ledger.md) — row `RL-115` records this decision
- [Cross-Project Sync Procedure](../maintenance/cross-project-sync.md) — refreshes the correspondence table each round
- [Correspondence Map](../sync/artifacts/correspondence-map.md) — hosts the topic-keyed ADR table
- [ADR-0019: Per-Worktree Instance Isolation](0019-worktree-instance-isolation.md) — model for a learning ADR citing its Scind counterpart
