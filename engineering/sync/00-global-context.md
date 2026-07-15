# Scind ↔ Xcind Synchronization — Global Context

**Status**: Active planning brief
**Audience**: AI agents and contributors executing any plan in this directory
**Read this first.** Every other document in `engineering/sync/` assumes the
facts, vocabulary, and operating model defined here.

---

## 1. Why this effort exists

[Scind](https://github.com/scinddev/scind) is an **engineering-documentation-only
project**: a design proposal for a CLI that manages multiple Docker
Compose–backed development environments on one host. [Xcind](https://github.com/scinddev/xcind)
is a **Bash proof-of-concept implementation** of that proposal. Building Xcind
produced real lessons and forced real compromises.

This effort brings those lessons **back into the Scind proposal** in preparation
for building Scind "for real." It also establishes a durable way to keep the two
projects honest about where they agree and where they intentionally differ.

## 2. Operating model (the single most important rule)

**Scind is canon. Xcind's lessons upgrade the canon.**

- Scind's `docs/` remains the **authoritative design** — the thing that will be
  built (see [§5 on the Go target](#5-the-govsbash-structural-divergence)).
- When Xcind reveals that Scind's design was **wrong, incomplete, or naïve**, the
  learning flows **Xcind → Scind**: update the Scind proposal.
- When Xcind made a **compromise that Scind should not adopt** (a Bash-ism, a
  shortcut, a scope cut), that is recorded as an **intentional Xcind divergence**
  — it does *not* change Scind.
- Xcind is never the source of truth *for design intent*. It is the source of
  truth for **what actually happens when you build it**.

Directionality, stated as a rule of thumb for every finding:

> "Does this teach us the *design* was wrong? → change Scind.
> Or does it only reflect *how Xcind chose to implement* it? → record a divergence."

## 2a. The misclassification safeguard (protecting learnings)

The dangerous failure mode of this whole effort is **paving a real learning into
a divergence** — recording "Xcind does it differently" when the truth is "Xcind
proved Scind's assumption wrong." Once mislabeled, the insight is lost: it looks
settled, and future sync rounds skip it as *expected*.

Two rules prevent this, and every plan (P3, P4, P6, P7) inherits them:

- **Burden of proof favors canon change.** DIVERGENCE is the claim that must be
  *earned*, not the default. To file something as a divergence you must be able
  to state, in one sentence, **why Scind should not adopt Xcind's approach.** If
  you cannot, it is a **CANON-CHANGE** (learning), not a divergence.
- **Asymmetric cost → default toward CANON-CHANGE / ESCALATE.** A false learning
  costs a rejected Scind proposal (cheap, visible, reversible on review). A false
  divergence costs a permanently lost insight (expensive, invisible). When
  genuinely unsure, route to CANON-CHANGE or ESCALATE — never to DIVERGENCE.

Your own examples calibrate the risk. **Bash limits** and **config-file formats
vs. environment-variables** are *implementation-shape* divergences — safe to
record; they don't hide design learnings. The risky cases are
**design-assumption** divergences, where Xcind changed *what the thing does or
promises*, not *how it's built*. Those get an adversarial re-check in P3/P7
before the divergence label is allowed to stand.

Nothing is ever discarded: even a confirmed divergence records the canon-change
question it was tested against (P7 schema), so the reasoning stays re-auditable
and a later round can promote it if new evidence arrives.

### Worked examples (calibration reference)

Two real Xcind-vs-Scind differences, run through the exact test. They look
superficially similar — "Xcind does X, Scind assumed Y" — but land on opposite
sides. Use them to calibrate your own judgment.

#### Example A — stays a DIVERGENCE (implementation-shape)

> **Observation.** Scind's config model leans on structured, typed configuration
> (its Go scaffolds imply a parsed config object). Xcind instead makes `.xcind.sh`
> a **sourceable Bash file** and expresses most configuration as environment
> variables (`XCIND_*` arrays and scalars).
>
> **Intent test** → *forced/deliberate.* Bash has no typed-config story; a
> sourceable script is the idiomatic, dependency-free way to configure a shell
> tool. One sentence, easily written.
>
> **Canon-neutrality test** → *Scind should NOT adopt this.* Scind targets a
> compiled language where a parsed, validated config file is strictly better than
> "eval a shell script." Adopting Xcind's approach would make Scind *worse*, not
> better. The "Why Scind should NOT adopt" field writes itself.
>
> **Category:** Structural. **Adversarial re-check:** not required (low-risk).
> **Verdict:** DIVERGENCE. It changes *how config is expressed*, not *what the
> config system must guarantee*. Scind's design is untouched.

#### Example B — promotes to a CANON-CHANGE (design-assumption)

> **Observation.** Scind's project-name isolation (ADR-0001) implicitly assumes
> **one working copy per project**. Xcind, run from multiple **git worktrees** of
> the same repo, found that the derived compose project name and workspace network
> **collided** across worktrees — so it introduced `XCIND_INSTANCE` to
> disambiguate them.
>
> **Intent test** → this was *not* a Bash constraint or a scope cut; it was forced
> by a real usage pattern Scind never modeled.
>
> **Canon-neutrality test** → *fails.* Try to write "why Scind should not adopt a
> per-instance isolation token" — you can't, because multi-environment-on-one-host
> is Scind's **core promise**, and worktree collision is a genuine hole in that
> promise. If you cannot justify the divergence, it is a learning.
>
> **Adversarial re-check** (Design category) → the skeptic's job is to argue "this
> is just how Xcind's naming happens to work." It fails: the collision would occur
> in *any* implementation of ADR-0001 as written, Go included. That proves the
> *design assumption* was wrong.
>
> **Verdict:** CANON-CHANGE. Route to P6: amend Scind's project-name-isolation
> design to account for multiple concurrent working copies. It is **not** filed as
> an Xcind divergence — that would pave over the learning.

**The tell:** Example A changes *how the thing is built*; Example B changes *what
the thing must promise*. When a difference reaches into Scind's promises,
assumptions, or guarantees, suspect a learning and make the divergence label earn
its place.

## 3. The two repositories and their doc trees

| Repo | Role | Doc tree(s) |
|------|------|-------------|
| **scind** | Design canon (proposal) | `docs/` — Layered Documentation System (LDS) |
| **xcind** | Bash implementation | `docs/` — user-facing (Diátaxis) **and** `engineering/` — LDS mirror of Scind's `docs/` |

**The comparison surface is `scind/docs/` ↔ `xcind/engineering/`.** These two
trees share nearly identical LDS structure and many identically named files.
Xcind's user-facing `docs/` (Diátaxis) is **out of scope** for cross-project sync
except as corroborating evidence of behavior.

The LDS layers present in both trees:

```
decisions/      product/      architecture/    specs/
behaviors/      reference/     implementation/   maintenance/
```

(Scind also has `etymology/`; Xcind also has `archive/`. Both are project-local
and not part of the comparison surface.)

## 4. Known divergences already observed (seed facts — verify in P2)

These were spotted during initial reconnaissance. They are **starting points,
not conclusions**; the P2 correspondence map must verify and complete them.

### 4a. ADR numbering has already collided

ADRs `0001`–`0010` align by both number and topic. After that they diverge:

| Scind ADR | Xcind ADR | Relationship |
|-----------|-----------|--------------|
| 0011 options-based-targeting | *(no matching number)* | **Scind-only number** — confirm whether Xcind implements the concept elsewhere |
| 0012 layered-documentation-system | 0011 layered-documentation-system | Same decision, **off-by-one number** |
| 0013 apex-url-primary-designation | 0017 apex-url-reporting | Related topic, different number **and** possibly different decision |
| 0014 host-docker-internal-normalization | 0013 host-docker-internal-normalization | Same decision, different number |
| — | 0012 unified-generate-flag-semantics | **Xcind-only** |
| — | 0014 two-track-documentation | **Xcind-only** |
| — | 0015 application-export-introspection | **Xcind-only** |
| — | 0016 proxy-domain-wildcard-constraint | **Xcind-only** |
| — | 0018 service-discovery-env-injection | **Xcind-only** |

**Implication:** "same ADR number" does **not** mean "same decision" across
repos. Any reconciliation must key on *topic*, not number. P6 owns the
renumbering/cross-referencing strategy.

### 4b. Specs already diverge in both directions

- **Scind-only specs:** `state-management`, `host-gateway-resolution`,
  `generated-manifest`, `shell-integration`.
- **Xcind-only specs:** `hook-lifecycle`, `application-lifecycle`.

Scind-only specs are candidate **P5** material (specified but maybe unexercised).
Xcind-only specs are candidate **P4** material (built but unspecified in Scind).

### 4c. Behaviors (Gherkin) diverge

Scind has a small `behaviors/` set (2 `.feature` files); Xcind has many more
across `proxy/`, `workspace/`, and `config-resolution/`. Xcind's richer behavior
suite is likely a source of P2/P4 findings.

## 5. The Go-vs-Bash structural divergence

Scind's `implementation/` appendices are **Go scaffolds** (`scaffold-*.go`,
`goreleaser.yaml`, a Go-oriented `tech-stack.md`), indicating Scind targets a
**Go** implementation. Xcind is **Bash**.

**This entire layer is a permanent, intentional divergence.** Do not flag
Bash-vs-Go differences in `implementation/tech-stack`, build tooling, language
idioms, or packaging as "drift." They are expected. (Verify the Go target in P2;
if Scind is language-agnostic, note that instead.)

What *does* transfer across the language boundary: **design decisions, specs,
naming conventions, behaviors, product framing** — the language-independent
canon. Focus cross-project findings there.

## 6. Where outputs live

Everything for this effort lives in **`xcind/engineering/sync/`**:

- These plan documents (`00`–`07`).
- The generated correspondence map and inventories (P2 output).
- The reconciliation ledger and repeatable sync procedure (P6 output).
- The **divergence registry** (P7 output) — the durable record of intentional
  Scind↔Xcind differences.

Changes to **Scind** (driven by P3/P5/P6 findings) land in the **scind repo**,
via its own contribution process, and are *tracked* from here.

## 7. Vocabulary for this effort

| Term | Meaning |
|------|---------|
| **Canon** | Scind's `docs/` — the authoritative design. |
| **As-built** | Xcind's actual code in `bin/` + `lib/xcind/`. |
| **Eng-docs** | Xcind's `engineering/` LDS tree (Xcind's *claimed* design). |
| **Self-drift** | Gap between Xcind eng-docs and Xcind as-built. Closed in **P1** before anything else. |
| **Cross-gap** | Gap between Scind canon and Xcind eng-docs. Mapped in P2, analyzed in P3–P5. |
| **Learning** | Something Xcind revealed that should change Scind canon. |
| **Divergence** | An intentional, permanent difference Xcind keeps *against* canon. |
| **Correspondence map** | The P2 artifact: file↔file map + ADR reconciliation + presence/status matrix. |

## 8. Trust prerequisite (why P1 exists)

Every cross-project finding assumes **Xcind's eng-docs faithfully describe
Xcind's as-built code**. If eng-docs have self-drifted, comparing them to Scind
compares Scind against a *stale mirror* and produces false learnings and false
divergences.

Therefore **P1 (Phase 0 self-sync) is a hard gate**: reconcile Xcind eng-docs ↔
as-built (via `engineering/maintenance/sync.md`) and record the result before P2
begins. P2+ must treat eng-docs as trustworthy *only* for the areas P1 verified.

## 9. Execution order and dependencies

```
P1 (self-sync gate)  ── must complete first ──►
P2 (correspondence map)  ── produces the shared substrate ──►
   ├─► P3 (learnings extraction)
   ├─► P4 (Xcind-ahead: built, unspecified in Scind)
   └─► P5 (Scind-ahead: specified, unexercised in Xcind)
                         P3+P4+P5 feed ──►
P6 (reconciliation + repeatable cross-repo sync procedure)
P7 (divergence registry) — design early, populate from P3/P4/P5/P6
```

P3, P4, P5 are independent of one another and may run in parallel once P2 exists.
P7's *design* can proceed as soon as P2 exists; its *content* accretes from
P3–P6.

## 10. Success criteria for the whole effort

1. Xcind eng-docs verified against as-built (P1 audit report committed).
2. A complete, verified correspondence map exists (P2).
3. Every Xcind learning is classified and, where it changes canon, a Scind change
   is proposed or filed (P3).
4. Every capability Xcind has but Scind lacks is either promoted to canon or
   recorded as a divergence (P4).
5. Every Scind capability Xcind hasn't exercised is labeled
   not-implemented / implemented-but-untested / deliberately-deferred (P5).
6. ADR numbering + cross-referencing between repos has a decided strategy (P6).
7. A repeatable cross-repo sync procedure exists — the cross-project analog of
   `maintenance/sync.md` (P6).
8. A living divergence registry exists and is populated (P7).
