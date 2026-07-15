# P2 — Correspondence Map (the "Rosetta Stone")

**Prerequisite**: [P1](./01-phase-0-xcind-self-sync.md) reports clean.
**Prerequisite for**: P3, P4, P5 (all consume this artifact).
**Read first**: [`00-global-context.md`](./00-global-context.md) — §3 (comparison
surface), §4 (seed divergences), §5 (Go/Bash), §7 (vocabulary).

---

## Goal

Produce the **shared factual substrate** every downstream plan depends on: a
verified, file-level map between **Scind canon** (`scind/docs/`) and **Xcind
eng-docs** (`xcind/engineering/`), plus an ADR reconciliation table and a
presence/status matrix. This is discovery, **not** judgment — do not decide what
*should* change here (that is P3–P6). Just establish *what corresponds to what*
and *where the gaps are*.

## Access to both repos

This plan reads two working trees:

- Xcind: `/Users/beausimensen/Code/xcind` (this repo).
- Scind: `/Users/beausimensen/Code/scind`.

Confirm both are present and on their intended branches before starting.

## Research questions

1. **File correspondence.** For every file in `scind/docs/` and every file in
   `xcind/engineering/`, what is its counterpart in the other tree (by topic,
   not just filename)? Which files are unique to one side?
2. **ADR reconciliation.** For each ADR topic, what number does each repo assign,
   and do the two ADRs express the **same decision**, a **diverged decision**, or
   is one **absent**? (Seed table in global-context §4a — verify and complete it.)
3. **Spec correspondence.** Same, per spec, including appendices.
4. **Behavior correspondence.** Map `.feature` files; note where Xcind has
   executable behaviors with no Scind counterpart and vice versa.
5. **Reference correspondence.** CLI + configuration reference — note that Xcind
   *intends* the user-track `docs/reference/` to be slimmer than eng-reference
   (ADR-0014); compare eng-reference to Scind reference only.
6. **The Go target.** Confirm whether Scind commits to Go (per
   `implementation/` scaffolds) or is language-agnostic. This calibrates what
   counts as permanent structural divergence (global-context §5).
7. **Structural deltas.** Where does one tree have a whole layer/subdir/appendix
   the other lacks?

## Method

For each correspondence, classify the relationship with a controlled vocabulary:

| Code | Meaning |
|------|---------|
| `MATCH` | Same topic, same substance (may differ in wording/detail). |
| `PARTIAL` | Same topic, materially different substance or depth. |
| `DIVERGED` | Same topic, conflicting decision/behavior. |
| `SCIND-ONLY` | Exists in canon, no Xcind counterpart. → feeds **P5**. |
| `XCIND-ONLY` | Exists in eng-docs, no Scind counterpart. → feeds **P4**. |
| `RENUMBERED` | Same decision, different ADR number. → feeds **P6**. |

Every non-`MATCH` row must cite the specific files (and line ranges where
useful) on both sides. Do **not** rely on filename equality — open both files.
For any Xcind eng-doc claim marked "Unverified" by P1, re-verify against
`bin/`/`lib/xcind/` before treating it as ground truth.

## Subagent fan-out

Split by LDS layer — each agent owns one layer across **both** repos and returns
that layer's rows. Layers are independent, so run in parallel:

1. **Decisions agent** — reconcile all ADRs; produce the full ADR table
   (supersedes the seed table). Highest priority; numbering collision is known.
2. **Specs agent** — every spec + appendix on both sides.
3. **Behaviors agent** — every `.feature` file.
4. **Reference agent** — CLI + configuration (eng-reference vs Scind reference).
5. **Architecture + product agent** — `architecture/`, `product/` (vision,
   comparison, roadmap, glossary).
6. **Implementation agent** — `implementation/` incl. the Go-target question (Q6).

Reserve `maintenance/` for P6 (it owns process docs). `etymology/` (Scind) and
`archive/` (Xcind) are out of scope (global-context §3).

## Output artifact

Write **`engineering/sync/artifacts/correspondence-map.md`** with three sections:

### 1. File correspondence matrix

| Layer | Scind path | Xcind path | Rel | Notes / feeds |
|-------|-----------|-----------|-----|---------------|
| specs | `specs/state-management.md` | — | SCIND-ONLY | → P5 |
| specs | — | `specs/hook-lifecycle.md` | XCIND-ONLY | → P4 |
| decisions | `decisions/0014-host-docker-internal-normalization.md` | `decisions/0013-host-docker-internal-normalization.md` | RENUMBERED | → P6 |

### 2. ADR reconciliation table (keyed by topic)

| Topic | Scind ADR | Xcind ADR | Same decision? | Action owner |
|-------|-----------|-----------|----------------|--------------|

### 3. Structural deltas + open questions

Whole-layer/appendix gaps; the Go-target answer; anything needing a human call.

Also emit a machine-readable companion **`correspondence-map.json`** (same rows)
so P3–P6 can filter programmatically:

```json
{ "layer": "specs", "scind": "specs/state-management.md",
  "xcind": null, "rel": "SCIND-ONLY", "feeds": ["P5"], "notes": "..." }
```

## Done criteria

- [ ] Every file in both comparison trees appears in exactly one matrix row.
- [ ] ADR table covers every ADR in both repos; seed table (§4a) confirmed/fixed.
- [ ] Go-target question answered.
- [ ] Every `SCIND-ONLY`/`XCIND-ONLY`/`DIVERGED` row tagged with which plan it feeds.
- [ ] `correspondence-map.md` + `.json` committed.
