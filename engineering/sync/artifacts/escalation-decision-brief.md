# Escalation Decision Brief — Human Product Calls (RL-095 … RL-114, + RL-038)

**Status**: DRAFT for human review — recommend only, decide nothing.
**Next steps**: see [`escalation-followup-steps.md`](./escalation-followup-steps.md) for the ordered execution plan once the DECISION boxes are marked.
**Date**: 2026-08-05
**Scope**: The 20 `ESCALATED` rows of the [reconciliation ledger](./reconciliation-ledger.md) §7, merged into 17 decision units per the duplicate map, plus a go/no-go on the one `PLANNED` row (`RL-038`).
**Method**: Per unit — verbatim question, evidence, the §2 directionality test, a §2a adversarial re-check on every DIVERGENCE / WONTFIX call, then a recommendation the human can accept or reject row by row.
**Evidence base**: Scind working tree on branch `sync/xcind-learnings-reconciliation` at `de98208` — content-identical to the scinddev/scind#3 canon edits, which are **merged** to `origin/main` as `241c991` (2026-07-15); the local checkout is just parked on the stale feature branch. Xcind working tree at `main` (`8839d19`).

Duplicate map applied (nothing decided twice):

- `RL-113` (RG-0001) merged into `RL-099` (host-gateway env).
- `RL-114` (RG-0002) merged into `RL-095` (visibility labels + label naming).
- `RL-107` (XA-0025) checked against the already-applied apex cluster; only the residual is decided here.
- `RL-104` (XA-0022) merged into `RL-098` (workspace membership) as sub-question 2.

## Summary table

| Unit | Title | Recommendation | Confidence |
|------|-------|----------------|------------|
| RL-095 (+RL-114) | Per-export `tls` vs protocol+visibility; visibility labels; label naming | DIVERGENCE (confirm 0032) + small CANON-CHANGE cleanup | High |
| RL-096 | Workspace-wide generated manifest: keep or demote? | DIVERGENCE (confirm 0023; manifest stays canon) + one-line cleanup | High |
| RL-097 | Adopt named extensible generation pipeline? | WONTFIX-DEFER | Medium |
| RL-101 | First-class generation extensibility surface? | WONTFIX-DEFER (same decision as RL-097) | Medium |
| RL-102 | Content-addressed (SHA) cache replaces mtime staleness? | WONTFIX-DEFER | Medium-high |
| RL-103 | Truly workspaceless single-app mode? | WONTFIX-DEFER | Medium-low |
| RL-098 (+RL-104) | App-side workspace membership / late-bind | SPLIT: CANON-CHANGE (external `path:`) + DIVERGENCE (self-declaration) | Medium |
| RL-099 (+RL-113) | `*_HOST_GATEWAY` env mandate unmet in Xcind | WONTFIX-DEFER (already adjudicated; optional Xcind backlog) | High |
| RL-100 | Flavors: add a stateless env-var alternative to canon? | WONTFIX-DEFER | Medium-high |
| RL-105 | Env-var root pin (`XCIND_APP_ROOT`) for Scind? | WONTFIX-DEFER | High |
| RL-106 | Proxy auto-start on app `up` + opt-out | FORWARD-PORT (conditional start + opt-out knob) | Medium-high |
| RL-107 | Apex reporting mechanics residual | CANON-CHANGE (apex opt-out + stale-behavior cleanup) | High |
| RL-108 | `proxy init` full-config flags | DIVERGENCE (new registry entry) | Medium-high |
| RL-109 | Generation/routing explain diagnostic | FORWARD-PORT (`app diagnose`-style, distinct from `doctor`) | Medium |
| RL-110 | Zero-config default compose/env detection | FORWARD-PORT | Medium-high |
| RL-111 | Declarative tool shortcuts (`XCIND_TOOLS`) | WONTFIX-DEFER (premise corrected) | Medium |
| RL-112 | `scind-compose` shell function + `compose-prefix` still needed? | WONTFIX-DEFER (conditioned on RL-080) | Medium |
| RL-038 | Rename Scind `docs/` → `engineering/` | GO (unblocked — PR#3 already merged) | High |

---

## RL-095 (+RL-114) — Per-export `tls` key vs protocol+visibility; visibility labels dropped; label naming

**Escalation question (verbatim, learnings.json L-0034 rationale):**

> "§2 cannot be cleanly applied — the reshape mixes two opposite-flowing differences. (a) CANON-CHANGE reading: requiring separate per-protocol port entries plus a `require`-redirect is more complex than one ergonomic `tls` key (overlaps the redirect-mechanism gap in L-0008). (b) SCIND-AHEAD/P5 reading: `visibility` (public/protected/private) is a documented external-tooling access-control contract Xcind chose NOT to exercise — dropping it is a Scind→Xcind gap (P5 material), not proof Scind is wrong, and cannot be filed as a P3 divergence."

**Merged RG-0002 question (verbatim, xcind-ahead.json reverse_gaps):**

> "ESCALATE to P5/P3: decide whether Xcind should restore visibility labels and whether the 'proxy.'-segment naming difference is intentional or should re-converge."

**Evidence.**

- *Facet (a) — tls key.* Already resolved by applied canon changes. `RL-024` (XA-0005, APPLIED) added a per-export `tls` attribute (`auto`/`require`/`disable`) to `scind/docs/specs/port-types.md:36-48`, credited to Xcind ADR-0009. The `protocol` field per port entry remains required (`port-types.md:28-34`) — canon now carries **both** models, and the JSON sample at `cli.md:1750-1754` carries both `"protocol": "https"` and `"tls": true`.
- *Facet (b) — visibility.* Divergence **0032** already exists (Scope, Active, origin SA-0019) and **survived a P7 adversarial re-check**: the label has a named downstream consumer (Servlo) for display/filtering, so it is legitimate advisory metadata, not speculative. Xcind test-enforces rejection of the `visibility` attribute (`test/test-xcind-proxy.sh:727-729`). Entry 0032 carries a soft P6 note: "access-control" is a misnomer — the label is advisory display metadata; worth a wording clarification in Scind.
- *Canon-internal inconsistencies found this pass:* `docker-labels.md:20-39` allows `public|protected|private`, while `port-types.md:52` and `reference/configuration.md:49,854-863` allow only `public|protected`; `port-types.md:59` names the label `workspace.visibility=…`, which matches no label in `docker-labels.md`.
- *Facet (c) — label naming (RG-0002).* Xcind drops the `proxy.` segment (`xcind.export.{n}.http.url` at `lib/xcind/xcind-proxy-lib.bash:610-651` vs canon `scind.export.{n}.proxy.http.url`) and emits no visibility and no assigned-port labels at all. No divergence entry currently covers the segment-naming difference.

**§2 test.** Facet (a) taught the design was incomplete — and that learning already flowed to canon (RL-024 applied). Facet (b) does not teach the design was wrong: Xcind dropped a Scind-ahead capability, which is exactly what divergence 0032 records. Facet (c) is implementation-shape: Xcind's label schema is its own namespace and its shape difference changes how labels are spelled, not what the labels must promise.

**§2a adversarial re-check (for keeping (b)/(c) as divergence).** Strongest opposite claim: "visibility controls no behavior even in Scind, so Xcind's rejection proves it speculative — canon should drop it." This was already run by P7 on entry 0032 and failed: a named consumer (Servlo) exists, and the correct canon response is a *wording* fix (advisory metadata, not access control), not removal. For (c): "the `proxy.` segment is redundant ceremony Scind should drop." Rejected — the segment separates proxied-export labels from assigned-port labels (`port.{n}.assigned`) in one namespace; Xcind never emits assigned-port labels, so it never felt the collision pressure. Xcind's flatter schema is not evidence the segmented schema is wrong.

**Recommendation: DIVERGENCE (confirm entry 0032, extend it) + small CANON-CHANGE cleanup.** Confidence: **high.**
Facet (a) is closed by RL-024; record it as resolved here. Facet (b): confirm 0032 as the standing answer — Xcind stays visibility-free; Scind keeps the labels. Facet (c): extend 0032 (or add a sibling Structural entry) to cover the `proxy.`-segment and missing assigned-port labels explicitly, so future sync rounds skip the delta as expected. The cleanup CANON-CHANGE: reconcile the `private` enum mismatch, fix the phantom `workspace.visibility` label name in `port-types.md:59`, act on 0032's wording note (visibility = advisory display metadata), and clarify `protocol` vs `tls` interplay in the JSON sample.

**Concrete next action if accepted:** one small Scind PR (docs-only cleanup: enum + label-name + wording); one Xcind edit extending divergence 0032's "What differs" with the label-schema shape (segment + assigned labels) and adding the delta to `registry.json`.

**Flip evidence:** a second external consumer needing visibility *enforcement* (not display) would reopen (b) as a canon design question; a tool that must consume both `scind.*` and `xcind.*` labels would reopen (c) toward convergence.

`DECISION: [X] accept  [ ] reject  — recommended: DIVERGENCE (confirm 0032) + CANON-CHANGE cleanup`

---

## RL-096 — Workspace-wide generated manifest: necessary orchestrator view, or redundant with on-demand `--json`?

**Escalation question (verbatim, learnings.json L-0035 proposed_action):**

> "ESCALATE to P6 reconciliation: decide whether Scind's manifest.yaml should be (a) retained as the orchestrator's aggregated view, (b) demoted to a derivable `--json` command output, or (c) kept but explicitly defined as cache-derived (with the L-0006 freshness contract). Do not silently file as divergence."

**Evidence.**

- Scind's manifest (`docs/specs/generated-manifest.md`) is a workspace-wide computed, read-only view; PR#3 already applied the L-0006 freshness contract to it verbatim: written **after** assigned-port allocation, reflecting post-allocation values, with the config-derived vs live-state-derived split (`generated-manifest.md:12-16`). So option (c) is already done.
- Divergence **0023** (Design, Active) already survived a P7 canon-change test with the decisive argument: the manifest's one non-redundant property is being readable **at rest, without Docker running** — a file-based integration surface for Servlo/DNS-updaters that neither Docker labels nor an on-demand `--json` command provides. Its revisit condition points back at exactly this escalation (L-0035).
- Divergences 0017 (stateless registry) and 0020 (per-app SHA config.json) both defer to L-0035 for the manifest-necessity question — this decision closes all three loops.
- One stale line: `generated-manifest.md:10` (duplicated at `reference/configuration.md:609`) still says "Scind can compare the manifest against configuration to determine if regeneration is needed," which contradicts the actual staleness model (`workspace-lifecycle.md:74-94`: mtime comparison; the manifest is never named as a staleness input).

**§2 test.** Xcind did not prove the manifest wrong — it proved a *per-app* tool can live without an *aggregated* view. Scind is a workspace orchestrator; the aggregated at-rest view is a capability with named consumers. The design survives; the Xcind absence is the already-recorded divergence.

**§2a adversarial re-check.** Strongest opposite claim: "Scind now has three surfaces for one dataset (labels, `--json`, manifest) — the manifest is the redundant third." Rejected: labels require running containers; `--json` requires invoking the binary in context; only the manifest is a file another process can watch or read at rest. Trimming should target the *claim* the manifest makes (it is not the staleness input), not the artifact.

**Recommendation: DIVERGENCE (confirm entry 0023; manifest stays canon as the at-rest integration surface) + one-line CANON-CHANGE cleanup.** Confidence: **high.**
Resolve L-0035 as options (a)+(c): retained, with the already-applied freshness contract. The cleanup: delete or rewrite the stale "Caching" bullet at `generated-manifest.md:10` / `configuration.md:609` so the manifest's stated purposes match the mtime staleness model — this also discharges 0023's "three surfaces" soft note by making the manifest's role (at-rest topology, not cache input) explicit.

**Concrete next action if accepted:** one-line Scind edit (the Caching bullet); flip the 0023/0017/0020 revisit-condition references from "open (L-0035)" to "resolved 2026-08 — manifest retained"; update `registry.json` notes accordingly.

**Flip evidence:** Servlo/DNS-updater consumers materialize and prefer the Docker-label or `--json` path in practice, leaving the manifest unread.

`DECISION: [X] accept  [ ] reject  — recommended: DIVERGENCE (confirm 0023) + one-line CANON-CHANGE`

---

## RL-097 — Should Scind adopt a named, extensible generation hook pipeline?

**Escalation question (verbatim, learnings.json L-0036 proposed_action):**

> "ESCALATE to P4/forward-port: evaluate whether Scind should adopt a named, extensible generation pipeline with a documented pure-generator vs runtime-precondition contract. Not a canon defect; a candidate feature Scind pulls forward if it wants third-party generation hooks."

**Evidence.**

- Xcind's pipeline: four phase arrays (CONFIGURED/RESOLVED/GENERATE/EXECUTE, `engineering/specs/hook-lifecycle.md`), with the load-bearing purity rule at `:165` (GENERATE hooks are pure generators, skippable on cache hit; side effects belong in EXECUTE, which always runs). Custom hooks are plain Bash array appends from `.xcind.sh` (`:209-238`). CONFIGURED and RESOLVED are *specified but not implemented*.
- The genuinely transferable learning — pure config-derived generation vs live-state/runtime work — **already landed in canon** via RL-005/RL-020 (config-derived vs live-state-derived content, `workspace-lifecycle.md:96-101`) and RL-007 (atomicity + completeness marker).
- Scind canon today has **zero** hook/extension concept in its generation pipeline. Its only extensibility plan is a *future protocol-handler* plugin system (HashiCorp go-plugin, `implementation/tech-stack.md:42-68`, `pkg/plugin/` in the project layout) for tcp/SNI port types — a different axis.
- Divergence **0019** (phase vocabulary) is recorded as **Active (contingent)**: "If the XA-0019 ESCALATE resolves toward Scind exposing a first-class generation-extensibility surface … this entry must be re-opened — a named phase vocabulary may then become a genuine canon need."

**§2 test.** Nothing here proves Scind's monolithic generator wrong — the defects it *did* have (purity, ordering, atomicity) are already fixed in canon. What remains is a pure capability question: does Scind want third parties injecting overlay generators? That is additive product scope, not a disproof.

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "Xcind's 8 independent built-in hooks prove a real tool accretes generation concerns fast; a monolithic Go generator will become unmaintainable, so the pipeline is a design learning, not a feature." Rejected: internal decomposition of a Go generator (functions, packages) needs no *user-facing* hook contract; Xcind's own registry records the vocabulary as "internal ceremony with no consumer absent a user-registrable surface" (0019). The learning content is the purity boundary, and that is already in canon. Deferring the extensibility *surface* loses no insight — 0019's contingency flag guarantees re-opening.

**Recommendation: WONTFIX-DEFER.** Confidence: **medium.**
Keep Scind generation closed for v1. A Go plugin contract for generation is a substantial design (process isolation, versioned interfaces) with no demonstrated third-party demand; Scind already has a natural future vehicle (the planned go-plugin protocol-handler system) that generation extensibility could ride when demand exists.

**Concrete next action if accepted:** add one sentence to Scind's `implementation/tech-stack.md` future-plugins note naming generation extensibility as a recognized candidate on the same go-plugin substrate; keep divergence 0019 Active-contingent with its flag intact.

**Flip evidence:** a concrete third party asking to inject overlays into Scind generation, or the protocol-plugin system landing (infrastructure cost already paid).

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-101 — Extensible generation hook lifecycle (plugin/hook-dir contract)

**Escalation question (verbatim, xcind-ahead.json XA-0019):**

> "Should Scind expose a first-class extensibility surface for generation (a Go plugin API or a hook-directory contract), or keep generation monolithic and closed? This is a product/architecture call."

**Evidence and analysis.** This is the same decision as RL-097 at implementation altitude — RL-097 asks "adopt the pipeline concept?", RL-101 asks "expose the surface?". One cannot be accepted while the other is rejected without incoherence. All evidence and the adversarial re-check in RL-097 apply here unchanged. The only additional fact: XA-0019's own rationale concedes "Scind cannot source user shell functions, so adopting it means designing a Go plugin/hook contract" — i.e. nothing mechanical transfers; only the product decision does.

**Recommendation: WONTFIX-DEFER — decide identically with RL-097.** Confidence: **medium.**
If the human instead resolves RL-097/RL-101 toward FORWARD-PORT, two consequences are mandatory: divergence 0019 must be reopened per its contingency flag (the phase vocabulary becomes canon material), and the pure-generate vs always-run-execute contract (`hook-lifecycle.md:165,179-184`) is the piece of Xcind's design worth porting verbatim.

**Concrete next action if accepted:** same single action as RL-097; mark both ledger rows with one shared resolution note.

**Flip evidence:** same as RL-097.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-102 — Content-addressed (SHA-of-inputs) generation cache

**Escalation question (verbatim, xcind-ahead.json XA-0020):**

> "Should Scind replace its manifest-vs-config staleness detection with a content-addressed (SHA-of-inputs) cache, including per-SHA generated directories? Architectural decision."

**Evidence.**

- The question's premise is stale: Scind's staleness model post-PR#3 is **mtime comparison** (`workspace-lifecycle.md:76`), not manifest-vs-config (that phrasing survives only in the stale bullet flagged under RL-096). PR#3 already absorbed the robustness properties that made Xcind's SHA cache attractive: assigned-port revalidation, generator/schema version as a staleness input, atomic temp+rename generation, a completeness marker, and the live-state-derived always-refresh class (`workspace-lifecycle.md:78-105`).
- Xcind's SHA cache hashes 13 input classes including file *content*, the instance token, a cache-schema version, and the runtime-detected host-gateway value (`lib/xcind/xcind-lib.bash:1338-1459`), keying per-SHA directories with per-hook completeness. Canon already acknowledges the mtime tradeoff: "may trigger unnecessary regeneration if files are touched without content changes" (`workspace-lifecycle.md:94`) — a false-*positive* (harmless rebuild), not a correctness hole.
- Divergences **0020** (per-app SHA config.json) and **0018** (per-hook overlay split — which exists to amortize the per-hook SHA cache) both survived P7 re-checks on the grounds that the transferable soundness learnings were already promoted.
- Small Xcind-side drift found: the `XCIND_CACHE_SCHEMA=2` SHA input (`xcind-lib.bash:1432-1437`) is absent from `engineering/specs/generated-override-files.md:34-49` and `hook-lifecycle.md:130`.

**§2 test.** Xcind proved specific *soundness requirements* (partial output, version skew, live-state refresh) — those flowed to canon in implementation-neutral form. The remaining delta — content hashing vs mtime, per-SHA dirs vs fixed `.generated/` — is cache implementation strategy, not a design promise. mtime-with-revalidation and SHA-of-inputs both satisfy the now-specified contract.

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "mtime is unreliable (git checkout churn, container clock skew, CI restores) — Xcind's content addressing is the *correct* design and canon specifies the broken one." Rejected: every mtime failure mode in that list produces spurious rebuilds, not stale artifacts, because the dangerous direction (content changed, mtime not newer) is pathological on developer machines and the completeness/revalidation checks catch the corruption cases independently. Correctness does not hinge on the choice; the choice is therefore not canon material.

**Recommendation: WONTFIX-DEFER.** Confidence: **medium-high.**
Keep canon's mtime-plus-revalidation model; leave the SHA cache as Xcind divergences 0020/0018. Optionally add one sentence to `workspace-lifecycle.md:94` noting content-based comparison as an acceptable implementation refinement, so a Go implementer is free to adopt it without a canon amendment.

**Concrete next action if accepted:** the optional one-sentence note in Scind; an Xcind maintenance item to document `XCIND_CACHE_SCHEMA` in the two spec files (spec/code drift).

**Flip evidence:** the Go implementation hitting real-world mtime unreliability that revalidation does not catch, or per-input caching becoming necessary for performance.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-103 — Workspaceless / standalone application mode

**Escalation question (verbatim, xcind-ahead.json XA-0021):**

> "Should Scind support a truly workspaceless single-app mode, or is the mandatory workspace.yaml boundary a deliberate guardrail (context-hijack prevention) worth keeping?"

**Evidence.**

- Scind: no `workspace.yaml` found walking up ⇒ hard error, dedicated exit code 5 (`context-detection.md:6-33`, `cli.md:1884`). The lightest unit is a single-app workspace — `workspace.yaml` with `path: .` — which is explicitly supported and special-cased throughout (`directory-structure.md:75-83`, `cli.md:815`). Context detection deliberately refuses `application.yaml` files outside the workspace tree ("Never traverse above workspace root") — the anti-hijack guardrail.
- Xcind: workspaceless is not a mode, it is the **default** (`${XCIND_WORKSPACELESS:-1}` everywhere). Naming, hostnames, network creation, and discovery all branch on it (`xcind-naming-lib.bash:33-45`, `xcind-workspace-lib.bash:50-53,117-124`, `xcind-discovery-lib.bash:113-116,213-217`) — pervasive dual-mode branching through the whole identity/naming/network surface.
- Scind's new ADR-0016 (instance token, from PR#3) speaks only of `{workspace}-{application}` identities; nothing in post-PR#3 canon contemplates an app without a workspace.

**§2 test.** Xcind proved a workspaceless mode is buildable and pleasant — it did not prove Scind's workspace boundary wrong. Scind's core promise (ADR-0001) is *isolation between multiple environments on one host*, and every isolation primitive is keyed on the workspace. A single-file `workspace.yaml` with `path: .` delivers the single-app case inside the existing model at the cost of five lines of ceremony. This is a scope extension, not a hole in a made promise (contrast the worktree collision, calibration Example B, where a made promise actually broke).

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "adoption funnel — nobody trying Scind on one repo wants to write a workspace file first; Xcind's default proves the zero-ceremony path is the natural one." That is a genuine product argument and the honest reason this is a human call. Rebuttal for the deferral: the cost side is visible in Xcind's own code — dual naming templates, dual hostname/apex templates, conditional network and discovery behavior — a permanent 2× surface in every identity-touching feature. `scind app init` scaffolding the five-line single-app workspace buys the same onboarding for a fraction of the complexity. The learning is not lost: this brief and XA-0021 record it, and the divergence entry proposed below carries the canon-change test.

**Recommendation: WONTFIX-DEFER (keep the mandatory workspace boundary; make the single-app path ergonomic).** Confidence: **medium-low** — this is the most genuinely contestable call in the brief.

**Concrete next action if accepted:** file the missing P7 divergence entry for XA-0021 (Design: Xcind defaults to workspaceless; Scind keeps the workspace boundary), with this unit's re-check as its canon-change test; optionally add a canon note that `workspace init`/`app init` should scaffold the `path: .` single-app form as the documented "just one repo" path.

**Flip evidence:** real onboarding friction reports once Scind exists, or a decision to court Xcind users whose apps are standalone by default. Note: rejecting this recommendation (adopting workspaceless mode) also reopens RL-098 sub-question 2, since late-bind presumes a workspaceless base state.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-098 (+RL-104) — App-side self-declared workspace membership / late-bind

**Escalation question (verbatim, learnings.json L-0037 proposed_action):**

> "ESCALATE to P6: decide whether Scind should support app-side self-declared workspace membership (decoupled from directory nesting) or intentionally keep workspace-owns-applications enumeration. Record that Xcind proved the inverted binding workable in practice."

**Merged RL-104 question (verbatim, xcind-ahead.json XA-0022):**

> "Should Scind let an application declare its own workspace membership (app->workspace), inverting the workspace.yaml-lists-applications ownership model? Depends on resolution of XA-0021."

**Evidence.**

- Scind's model: `workspace.yaml` enumerates applications, each with an optional `path:` documented only in workspace-relative forms (`./database`, `.`; `cli.md:810`: "Custom path **relative to workspace**"). No canon text permits an app outside the workspace tree; context detection forbids considering `application.yaml` outside it (`context-detection.md:7-8`). `SCIND_WORKSPACE` exists only as a transient detection override in the CLI env-var table (`cli.md:1869`), not as a committed membership declaration.
- Xcind's late-bind: `__xcind-late-bind-workspace` (`xcind-lib.bash:1198-1206`) flips `XCIND_WORKSPACELESS` 1→0 when the app's own `.xcind.sh` sets `XCIND_WORKSPACE`; the app directory doubles as its workspace root. Directory detection wins the mode decision. Documented as "useful when the workspace is conceptual rather than a physical directory" (`docs/guides/workspaces-vs-apps.md:74-82`).
- Two decision-relevant wrinkles: (1) divergence **0007** already asserts "Scind's `workspace.yaml` registry buys name↔location indirection (`path:` can point an app name at an arbitrary location)" — a claim the canon text does **not** actually support; 0007 also explicitly leaves this inversion question to L-0037. (2) An Xcind guard gap: `__xcind-load-config` sources the app `.xcind.sh` with no guard on `XCIND_WORKSPACE`, so an app setting it can silently overwrite the *discovered* workspace name — contradicting `self-declaration.feature:17-22` ("XCIND_WORKSPACE retains the discovered value").

**§2 test — split verdict.** The escalation bundles two claims that flow opposite directions:

1. **"Membership must not require directory nesting"** — Xcind proved the lone-repo-joins-a-workspace pattern is real and workable. Scind's canon is ambiguous here (divergence 0007 already believes `path:` grants it; the reference text says relative-only). Ambiguity on a real usage pattern routes to **CANON-CHANGE**: explicitly permit an absolute/external `path:` in the workspace roster, with the note that context auto-detection does not reach external apps (use `--workspace`/`--app` targeting, which ADR-0011 already provides). This closes the use case *inside* the workspace-owns-apps model and makes canon match what its own divergence registry believes it says.
2. **"The app declares its membership (direction inversion)"** — **DIVERGENCE**. One sentence for the gate: app-side declaration makes workspace membership unenumerable — `workspace up` and the manifest cannot know the roster without scanning the filesystem for volunteers, which breaks Scind's orchestrator model and its derived-from-workspace-contents application model (`directory-structure.md:3-6`).

**§2a adversarial re-check (on the DIVERGENCE half).** Strongest opposite claim: "Xcind proved inverted binding workable in practice — Scind's ownership direction is a wrong assumption." Rejected: workable ≠ better for Scind's promises. Every orchestrator feature (workspace-wide up, aggregated manifest, roster validation) needs an authoritative enumeration; Xcind never felt that pressure because it is per-app and manifest-free. The genuine user value in late-bind (external app joins workspace networking) is fully delivered by half 1 with enumerability preserved. Late-bind itself is a consequence of Xcind's registry-less, sourceable-config architecture (divergences 0003/0017), which is the calibration Example A shape.

**Recommendation: SPLIT — CANON-CHANGE (external `path:` allowed, membership stays workspace-declared) + DIVERGENCE (app-side self-declaration stays Xcind-only).** Confidence: **medium.**

**Concrete next action if accepted:** Scind edit sketch — `reference/configuration.md` + `directory-structure.md`: state that `applications.{name}.path` MAY be absolute or outside the workspace tree; external apps are targeted via `-w`/`-a` (context auto-detection does not apply); `context-detection.md` unchanged. Xcind side — file the P7 divergence entry for XA-0022/L-0037 (Design, with this re-check as the canon-change test); fix the `XCIND_WORKSPACE` overwrite guard gap (Xcind backlog, small); correct divergence 0007's `path:` claim to cite the new canon text instead of asserting it.

**Flip evidence:** if the CANON-CHANGE half is rejected (canon stays nesting-only), the DIVERGENCE half weakens — late-bind would then be the only way to serve a real pattern, and §2a says re-run this unit with the burden on canon.

`DECISION: [X] accept  [ ] reject  — recommended: CANON-CHANGE (external path) + DIVERGENCE (self-declaration)`

---

## RL-099 (+RL-113) — `*_HOST_GATEWAY` container env mandate unmet in Xcind

**Escalation question (verbatim, learnings.json L-0038 proposed_action):**

> "ESCALATE / route to P5: Scind's `*_HOST_GATEWAY` container env exposure (host-gateway-resolution.md 'Environment Variable Exposure') is unimplemented in Xcind, which only emits `extra_hosts`. Either implement env injection in xcind-host-gateway-lib.bash to validate the mandate, or downgrade the Scind spec's SHOULD if extra_hosts-only proves sufficient. No canon change proposed until Xcind exercises the env path."

**Evidence.** This escalation has **already been adjudicated** by a recorded human product-call (2026-07-15), captured in divergence **0022** (Scope, Active, origin SA-0002): Scind keeps the SHOULD-level mandate ("canon is NOT softened"); Xcind's `extra_hosts`-only implementation is a deliberately-deferred divergence; the earlier "soften Scind's mandate" note was explicitly withdrawn. The canon-change test in 0022 records why the mandate stands: the env var serves Xdebug `client_host`, which a `/etc/hosts` DNS name cannot — a tool that wants an env value cannot read `extra_hosts`. Verified both directions this pass: `host-gateway-resolution.md:83-100` mandates (SHOULD, twice) `SCIND_HOST_GATEWAY` inside containers; `xcind-host-gateway-lib.bash:150-228` writes `extra_hosts` only, with no `environment:` block anywhere in the file. 0022's revisit condition already names the exit: Xcind may optionally add `environment: - XCIND_HOST_GATEWAY=<value>` (the value is already computed in-hook), at which point the entry flips to Resolved.

**§2 / §2a.** Nothing to re-classify — both tests were run, adversarially, at P7 admission, and the human call is on record. Re-deciding it here would violate the duplicate map's purpose.

**Recommendation: WONTFIX-DEFER (confirm the recorded adjudication; no new decision).** Confidence: **high.**

**Concrete next action if accepted:** mark RL-099/RL-113 resolved-by-reference to divergence 0022; optionally promote 0022's optional backlog item to a real Xcind backlog row (inject `XCIND_HOST_GATEWAY` into `environment:` — small, value already computed, unblocks Xdebug, and resolves the divergence outright, which is the cleanest possible end state).

**Flip evidence:** none needed — implementing the Xcind backlog item dissolves the divergence.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER (confirm 0022)`

---

## RL-100 — Flavors dropped by design: does Scind add a stateless alternative?

**Escalation question (verbatim, learnings.json L-0039 proposed_action):**

> "ESCALATE to P6/P5: decide whether Scind retains stateful named flavors or additionally offers a stateless env-var-driven alternative. Record the WHY (flavor selection is coupled to persistent active-flavor state in state.yaml; Xcind is stateless so used `${APP_ENV}` file-pattern expansion instead). Cross-ref L-0024 (the config-model consequence) and L-0022 (Xcind's statelessness limits). Feeds docs/specs/state-management.md + docs/specs/configuration-schemas.md flavor-resolution review."

**Evidence.**

- Scind's flavor resolution already has an ephemeral *and* a persistent path: `--flavor=X` (per-invocation) > `.generated/state.yaml` (persisted by `flavor set`) > `default_flavor` > `"default"` (`configuration-schemas.md:245-250`, `state-management.md:57-62`). No flavor env var exists anywhere in canon.
- Divergence **0024** (Scope, Active) already survived a P7 adversarial re-check and **records the WHY verbatim**: "Flavors need somewhere to record the active flavor — persisted state. Xcind is deliberately stateless (divergence 0017), so it had no home for active-flavor state and used shell expansion over file patterns instead (the L-0039 rationale)." Its canon-neutrality argument: flavors map to an industry-standard need (`docker compose --profile`); Xcind's substitute rides the arbitrary-shell config shape canon deliberately rejects (divergences 0004/0012).
- The pending PROCESS row `RL-092` (make the flavors deferral explicit in Xcind ADR-0005) is the same soft note 0024 carries.

**§2 test.** Xcind proved environment-switching is achievable statelessly — but its substitute is inseparable from the sourceable-shell config model Scind rejected, so it does not transfer as a mechanism. The persistent active flavor is deliberate orchestrator UX: `workspace up` with no arguments reuses the last selection, an outcome env-var selection cannot deliver without every shell re-exporting it. Nothing here proves the flavor design wrong.

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "the state coupling makes flavors heavier than the outcome requires; a `SCIND_FLAVOR` env var would serve CI and scripting statelessly." Rejected as a *now* decision: `--flavor=X` already serves the ephemeral case; a third selection source adds precedence complexity for a consumer (CI that cannot pass flags) that is currently hypothetical. The WHY is durably recorded in 0024, so deferring loses nothing.

**Recommendation: WONTFIX-DEFER (Scind keeps stateful flavors unchanged; no env-var alternative now).** Confidence: **medium-high.**

**Concrete next action if accepted:** close L-0039 by reference to divergence 0024 (the WHY is recorded there); execute the pending `RL-092` process row (explicit flavors-deferral sentence in Xcind ADR-0005); update 0024's revisit condition from "reopen with L-0039" to "resolved 2026-08 — flavors retained."

**Flip evidence:** a real CI/scripting consumer that cannot thread `--flavor` — then add `SCIND_FLAVOR` between the CLI flag and the state file in the resolution order (a three-line canon edit).

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-105 — `XCIND_APP_ROOT` env root-pin escape hatch

**Escalation question (verbatim, xcind-ahead.json XA-0023):**

> "Is an env-var root-pin (vs the existing --app/-a flag) worth adding to Scind? Likely already covered by ADR-0011 targeting — probably not a real gap."

**Evidence.** Scind's ADR-0011 provides `--workspace/-w` and `--app/-a` on every command, overriding context detection; `SCIND_WORKSPACE` additionally exists as an env default (`cli.md:1869`). There is no `SCIND_APP`/`SCIND_APP_ROOT` env var anywhere in canon. Xcind's `XCIND_APP_ROOT` (`xcind-lib.bash:214-250`) short-circuits the upward walk with no validation at read time ("trust it") and relocates the whole detection frame — it exists because Xcind has *no* targeting flags (divergence 0021: context-only targeting is the recorded Xcind scope divergence, itself a consequence of having no registry).

**§2 test.** Pure implementation-shape. Xcind needed an env pin because it lacks `-a`; Scind has `-a`. No design assumption is challenged.

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "env-var targeting composes better with wrapper scripts and CI than flags do — and Scind already grants `SCIND_WORKSPACE`, so refusing `SCIND_APP` is asymmetric." True but trivial: if the asymmetry ever bothers anyone, adding `SCIND_APP` to the env table is a one-line reference edit, not a design decision worth pre-making. No learning is at risk.

**Recommendation: WONTFIX-DEFER (no Scind action).** Confidence: **high.**

**Concrete next action if accepted:** one-line ledger note: "covered by ADR-0011; env symmetry (`SCIND_APP`) available as a trivial future reference edit if asked for."

**Flip evidence:** a wrapper/CI use case where flags genuinely cannot be threaded.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-106 — On-demand proxy auto-start on app `up` + opt-out

**Escalation question (verbatim, xcind-ahead.json XA-0024):**

> "Should Scind auto-start the proxy as a side effect of an app-level 'up' (not just workspace up), and expose a first-class opt-out knob? Lifecycle/UX policy call against ADR-0010."

**Evidence.**

- The first half of the question is **already answered by canon**: `scind app up` is defined as "Equivalent to `scind workspace up --app=NAME`" (`cli.md:850-864`) and therefore inherits Startup Sequence step 1, "Ensure proxy is running" (`workspace-lifecycle.md:58-63`) — which RL-017 (APPLIED) additionally made a hard-fail gate. ADR-0010 contains zero occurrences of "proxy"; there is no conflict with it.
- Two genuine deltas remain. (1) *Export-conditional start:* Xcind's EXECUTE hook starts Traefik only when the app declares at least one `type=proxied` export and skips it for assigned-only configs (`xcind-proxy-lib.bash:1386-1414`); Scind starts the proxy unconditionally. (2) *Opt-out knob:* `XCIND_PROXY_AUTO_START=0` skips auto-start but still ensures the proxy network exists for overlay compatibility (`xcind-proxy-lib.bash:503-528`); Scind has no toggle anywhere in `proxy.yaml` or its env tables.

**§2 test.** Both deltas are provider-agnostic ergonomic refinements Xcind proved in use — starting a reverse proxy for an app that exports nothing proxied is pure waste, and the opt-out serves the externally-managed-proxy case. They extend canon; they do not contradict it. That is FORWARD-PORT shape.

**Recommendation: FORWARD-PORT (both deltas).** Confidence: **medium-high.**

**Concrete next action if accepted:** Scind edit sketch — `workspace-lifecycle.md` step 1 + `configuration-schemas.md` proxy schema: condition proxy start on ≥1 proxied export among the apps being brought up (network ensure stays unconditional); add `proxy.auto_start: true|false` (default true) with defined interaction with the RL-017 fail-fast gate (opted-out + proxied exports present ⇒ warn, still ensure network, do not fail `up`). Credit Xcind; note the staleness-nudge behavior (`"config changed; run up to apply"`) as optional.

**Flip evidence:** a decision that the proxy is invariant always-on infrastructure (one shared Traefik regardless of workload) — that reading keeps the unconditional start and reduces this to just the opt-out knob.

`DECISION: [X] accept  [ ] reject  — recommended: FORWARD-PORT`

---

## RL-107 — Apex reporting mechanics (folded into the apex cluster — residual check)

**Escalation question (verbatim, xcind-ahead.json XA-0025):**

> "HAND TO P3: fold apex reporting-preference and the single-export apex opt-out into the P3 apex-designation decision (Scind 0013 explicit-primary vs Xcind 0017 positional+reporting), rather than promoting reporting in isolation."

**Evidence — what the applied apex cluster (RL-013/RL-018/RL-019) already answers.**

- Prefer-apex reporting: **landed** (`scind/docs/reference/cli.md:1675-1702`, `app show` at `:658-672`, with explicit Xcind credit).
- Additive `apex`/`apex_host` JSON fields: **landed** (`cli.md:1695-1700`).
- Hybrid designation (explicit `primary:true` wins, else first-declared proxied export): **landed** (`0013-apex-url-primary-designation.md:18-27`, mirrored in `configuration-schemas.md:212-235`).
- Apex **opt-out**: **NOT landed.** No mechanism anywhere in canon disables apex generation; post-hybrid, every application with ≥1 proxied export gets an apex with no way to decline. Xcind has one: an empty apex template disables it (`engineering/reference/configuration.md:337`, ADR-0017 point 3, enforced at `xcind-proxy-lib.bash:1002`).
- Stale canon contradicting the applied hybrid rule (missed by PR#3): `behaviors/proxy/apex-routing.feature:28-32` and `behaviors/exported-services/primary-designation.feature:34-40` still assert "no primary ⇒ no apex"; `naming-conventions.md:46` still has the pre-RL-018 unscoped implicit-primary wording; `apex-routing.feature:44` asserts an outdated label form.

**§2 test.** The cluster resolved the designation question; RL-107's fold instruction is satisfied. The opt-out is a genuine residual: Xcind's field experience (ADR-0017) is that some apps must be able to decline the apex, and the hybrid rule made canon *strictly more* apex-eager, so the gap widened. That is a small design incompleteness → CANON-CHANGE.

**Recommendation: CANON-CHANGE (residual: apex opt-out + stale-text cleanup); the rest of RL-107 is record-as-resolved.** Confidence: **high.**

**Concrete next action if accepted:** Scind edit sketch — ADR-0013 + `configuration-schemas.md`: add an explicit opt-out (e.g. app-level `apex: false`, or primary designation `primary: none`) declaring that no apex router, labels, or `apex`/`apex_host` values are produced; note Xcind's empty-template mechanism as the validating implementation. Same PR: update the two stale `.feature` scenarios and `naming-conventions.md:46` to the hybrid/proxied-scoped rules (these contradict applied canon today, independent of the opt-out). Note: `RL-094` (drop `behaviors/` from both projects) is a pending PROCESS row — if it executes first, the feature-file cleanup becomes moot; sequence accordingly.

**Flip evidence:** none for the cleanup (it is consistency, not product choice); for the opt-out, a decision that "every proxied app has an apex" is itself the product promise would convert this to WONTFIX — but Xcind's ADR-0017 is direct evidence users need the escape.

`DECISION: [X] accept  [ ] reject  — recommended: CANON-CHANGE (opt-out + cleanup)`

---

## RL-108 — `proxy init` accepts full config as flags

**Escalation question (verbatim, xcind-ahead.json XA-0026):**

> "Should Scind surface proxy configuration as 'proxy init' flags in addition to the declarative proxy.yaml, or keep init minimal and config-file-driven?"

**Evidence.**

- Scind: `proxy init` takes 3 flags (`--force`, `--domain`, `--path`); everything else lives in declarative `proxy.yaml`, which is fully editable via `scind config get/set/edit` (`cli.md:1144-1166,1285-1362`). Re-init errors unless `--force` (backup-and-overwrite).
- Xcind: `xcind-proxy init` accepts 14 value flags covering the whole proxy config, with inline validation and **idempotent merge** on re-init — existing `config.sh` is sourced as defaults, flag overrides applied, config rewritten (`bin/xcind-proxy:37-260`). Xcind has no `config set` equivalent; init flags are its only ergonomic scripted write path.
- The underlying *capabilities* (configurable ports, TLS modes, cert files, dashboard) were all promoted separately and are APPLIED (RL-023/RL-024/RL-027). Only the interface question remains, exactly as the escalation says.

**§2 test.** Implementation-shape. Xcind's flag surface exists because its config is a sourced shell file with no structured editing command — flags are the only safe scripted writer. Scind has a typed YAML file plus `config set`; every capability is already reachable both interactively and scripted. Nothing about the flag interface teaches that Scind's declarative design is wrong.

**§2a adversarial re-check (for DIVERGENCE).** Strongest opposite claim: "one-shot provisioning (`proxy init --tls-mode custom --https-port 8443 …`) is better UX than init-then-N-config-sets, and Xcind's idempotent merge beats Scind's error-or-force re-init." The first half fails canon-neutrality: mirroring every `proxy.yaml` key as an init flag creates a second write surface that must track the schema forever, for a convenience `scind config set` already provides. The second half is worth a look but is not this escalation's question and Scind's `--force` backup semantics is a deliberate recovery design (`configuration-schemas.md:39`). No learning is buried: the capabilities themselves are all in canon.

**Recommendation: DIVERGENCE (new P7 registry entry; Scind keeps `proxy init` minimal and config-file-driven).** Confidence: **medium-high.**

**Concrete next action if accepted:** file a new divergence entry (suggest Category: Structural — the flag surface is forced by Xcind's sourced-shell config having no structured editor; origin XA-0026), with this re-check as the canon-change test; add to `registry.json` + README index.

**Flip evidence:** users of Scind asking for one-shot scripted provisioning that `config set` sequences handle poorly (e.g. atomic multi-key init in CI).

`DECISION: [X] accept  [ ] reject  — recommended: DIVERGENCE`

---

## RL-109 — Generation/routing explain diagnostic (`config doctor`)

**Escalation question (verbatim, xcind-ahead.json XA-0027):**

> "Should Scind add a generation/routing-explain diagnostic (distinct from its host-health 'doctor'), and under what name? The Bash-internal parts (sourcing order, hook registration) don't transfer; the intent does."

**Evidence.**

- Scind's existing `doctor` (`cli.md:1602-1641`) checks host health: Docker, Compose, proxy network, Traefik, config dir, DNS resolution of workspace domains. It offers **no per-app generation or routing introspection**.
- Xcind's `xcind-config doctor` (`xcind-lib.bash:1925-2070`) answers "why didn't routing/generation happen for this app": hook registration (with a pointed warning when the assigned hook is missing), the sourced-config-file chain, per-entry `XCIND_PROXY_EXPORTS` parse results, assigned-port TSV rows, generated-dir contents, and port-probe tool availability — with `--json`. It exists because users had *no other way* to see why a proxied export failed to generate (XA-0027 `why_it_exists`).
- The Scind-translatable content is real and non-Bash: which config files resolved, the active flavor, export parse results, assigned-port state records, generated-artifact presence/staleness verdict.

**§2 test.** The need is field-proven (an emergent debugging aid built because users were stuck), and the *intent* — a self-explaining generation pipeline — is language-independent. Scind's applied RL-012 contract already requires read-only, side-effect-free introspection; an explain diagnostic is its natural debugging complement. Additive capability → FORWARD-PORT.

**Recommendation: FORWARD-PORT, under a name distinct from `doctor`.** Confidence: **medium.**
Suggest `scind app diagnose` (or `scind explain`): per-app, intent-level spec — report resolved config inputs, flavor, export parse results, assigned-port records, generated artifacts and their staleness verdict, with `--json`; keep `doctor` host-scoped. Naming is the human's call; the two-command split (host health vs per-app explain) mirrors what both tools already converged on.

**Concrete next action if accepted:** Scind edit sketch — new subsection in `docs/reference/cli.md` (+ a line in the RL-012 introspection contract noting the diagnostic shares its read-only guarantee). Bash internals (hook arrays, sourcing order, TSV paths) explicitly excluded per §5.

**Flip evidence:** a decision to grow `doctor` with an `--app` scope instead — same capability, different surface; the recommendation is indifferent between the two, opposed only to dropping the capability.

`DECISION: [X] accept  [ ] reject  — recommended: FORWARD-PORT`

---

## RL-110 — Zero-config default compose/env candidate resolution

**Escalation question (verbatim, xcind-ahead.json XA-0028):**

> "Should Scind auto-detect conventionally-named compose files (compose.yaml, docker-compose.yaml, .env) when none are declared, or keep explicit per-flavor compose_files declaration?"

**Evidence.**

- Scind: `compose_files` is explicit inside each flavor (`configuration.md:388-403`, `workspace-lifecycle.md:110`); no fallback or "if omitted" language exists anywhere in canon. `scind app init` scaffolds the field once at creation (`cli.md:784`) — a write-time convenience, not runtime detection.
- Xcind: when nothing is declared, `XCIND_COMPOSE_FILES` defaults to the four candidates and `XCIND_COMPOSE_ENV_FILES` to `.env`, each existence-filtered — with the in-code comment "Mirror Docker Compose's default file discovery" (`xcind-lib.bash:271-289,322-327`) and a six-scenario behavior spec (`compose-file-defaults.feature`), including "custom `.xcind.sh` overrides defaults."

**§2 test.** This one leans learning. The default set is not an Xcind invention — it mirrors what `docker compose` itself does with no `-f` flags, so a Scind user's expectation is already set by the underlying tool. Scind is convention-based for naming (ADR-0004) yet demands explicit declaration for the one input Compose itself defaults; requiring boilerplate that duplicates the platform convention is ceremony, not safety. Crucially the default applies **only when nothing is declared** — flavors and explicit lists are untouched the moment they exist, so the typed-flavors design loses nothing.

**Adversarial counter (for the human's benefit, since the recommendation is not DIVERGENCE/WONTFIX):** explicit-only fails loudly on a missing declaration and keeps `application.yaml` self-describing. Rebuttal: Compose users never get that failure from Compose itself; the loud failure protects against a mistake the platform convention already defines away, and `scind app show` can display the resolved (defaulted) file list for self-description.

**Recommendation: FORWARD-PORT.** Confidence: **medium-high.**
Spec sketch: when an application declares no `flavors`/`compose_files`, the `default` flavor resolves to the existence-filtered candidate list `compose.yaml`, `compose.yml`, `docker-compose.yaml`, `docker-compose.yml`; env-file default `.env`; zero existing candidates at generation time is an error naming the convention.

**Concrete next action if accepted:** Scind edit — `reference/configuration.md` + `configuration-schemas.md` (default-resolution paragraph, credit Xcind + the behavior spec); align `scind app init` wording (scaffolding becomes optional when conventions match).

**Flip evidence:** if Scind decides `application.yaml` must stay fully self-describing as a design invariant (every input declared), that is a coherent WONTFIX — record it with a canon sentence saying so, so the question does not resurface each round.

`DECISION: [X] accept  [ ] reject  — recommended: FORWARD-PORT`

---

## RL-111 — Declarative per-project tool shortcuts (`XCIND_TOOLS`)

**Escalation question (verbatim, xcind-ahead.json XA-0029):**

> "Should Scind add declarative per-project tool shortcuts (host command -> container service + exec/run mode) as a typed application.yaml field, or keep only generic 'exec'?"

**Evidence — including a premise correction.**

- The escalation's framing ("so e.g. 'xcind php' / 'xcind npm' run inside the mapped service") **overstates the as-built capability**. There is no `xcind` binary and no tool dispatcher in the repo; `XCIND_TOOLS` is parsed into a JSON map (`__xcind-resolve-tools`, `xcind-lib.bash:737-814`) whose only consumers are the `--json` introspection contract (key `tools`) and the generation SHA. Its proven use is **IDE/tooling metadata**: "The JetBrains plugin reads `xcind-config --json` to discover compose files, env files, and tools per app" (`docs/guides/tools-ide-integration.md:25-31`).
- Scind has no analog: no `scind exec` command exists; the generic path is `scind-compose exec <service> <cmd>` (`cli.md:1471,1940-1946`), and no tool-map concept appears anywhere in canon.

**§2 test.** What Xcind actually proved is a *metadata contract* (name → service + exec/run mode + path) consumed by an external IDE integration — not a host-command runner. That is a real but narrow capability, and its value to Scind depends entirely on a consumer that does not yet exist on the Scind side. Adding a typed `tools:` field with no consumer would be speculative schema.

**§2a adversarial re-check (for WONTFIX).** Strongest opposite claim: "the JetBrains plugin is a *named, existing* consumer — the same test that kept visibility labels alive (RL-095) should keep this alive as a promote." The parallel is imperfect: visibility labels are *in Scind canon* with a Scind-ecosystem consumer (Servlo); the tools map is an *Xcind* surface with an *Xcind* consumer, and Scind's JSON contract (RL-012, applied) can grow a `tools` key the day a Scind consumer wants it — the schema is additive and loses nothing by waiting. The deferral is recorded here with the corrected premise, so no learning is paved over.

**Recommendation: WONTFIX-DEFER.** Confidence: **medium.**

**Concrete next action if accepted:** ledger note correcting the XA-0029 premise (declarative metadata map, not an executable shortcut layer — no `xcind <tool>` dispatcher exists) and deferring with the flip condition below. No registry entry needed — this is Xcind-ahead surface area, not a difference from any canon promise.

**Flip evidence:** an IDE/tooling consumer targeting *Scind's* `--json` contract asking for tool metadata — then forward-port as a typed `tools:` map in `application.yaml` mirroring Xcind's `name:service[;use=exec|run][;path=…]` semantics. A future `scind <tool>` *runner* would be a separate, larger product decision — evaluate it on its own escalation, not this one.

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER`

---

## RL-112 — `scind-compose` shell function + `compose-prefix`: does Scind still need it?

**Escalation question (verbatim, scind-ahead.json SA-0026 recommendation):**

> "ESCALATE (human product-call): open question whether Scind still needs the scind-compose shell function + compose-prefix design at all, given Xcind's binary proved a viable alternative. This is NOT a settled divergence NOR a plain Xcind gap — it is a canon design question for the Scind side to resolve: keep the shell-function/compose-prefix architecture, adopt Xcind's binary approach, or support both. Route to human/P6 for a design decision; do not auto-classify."

**Evidence.**

- Scind's stated reason for the function architecture is completion economics: "Shell function + completion delegation achieves full docker compose completion 'for free'" (`shell-integration.md:20-28`), with the `compose-prefix` eval contract and an empty-output error-detection workaround (`shell-integration.md:116-176`).
- Xcind's `bin/xcind-compose` is a real executable that resolves context internally and `exec docker compose …` (`bin/xcind-compose:66-76`) — no sourced function, no eval indirection — and its docs claim the same completion delegation ("delegates to Docker's own completion, so you get the full `docker compose` UX", `tools-ide-integration.md:17`).
- **The load-bearing caveat:** SA-0026's own evidence says the binary comes "at the cost of the 'completion for free' delegation," and ledger row `RL-080` (SA-0003, the highest-priority ⚠ latent-bug backlog item) records that Xcind's **completion-function behavior is untested**. So the one property that motivates Scind's design is exactly the property Xcind has claimed but not proven.
- Post-PR#3, canon already positions generated wrapper scripts as a *complement* for exec-a-binary tools, "not replaces" (`shell-integration.md:288-319`, RL-033 APPLIED) — so the exec-consumer case is covered either way.

**§2 test.** If Xcind's completion delegation demonstrably works from a standalone binary, Scind's motivating assumption ("must be a shell function to get delegated completion") is disproven and the simplification to a binary is a clean CANON-CHANGE. But the evidence is not yet there — the delegation is exactly the untested piece. Recommending a canon change on an unverified existence proof would be the false-learning failure mode in reverse.

**§2a adversarial re-check (for WONTFIX-DEFER).** Strongest opposite claim: "defer is a dodge; the binary obviously works — Xcind ships it as its only interface." Invocation, yes; completion parity, no — that is precisely RL-080's latent-bug flag, and completion UX is the entire stated rationale for Scind's architecture. Deferring **on a named, testable condition** keeps the learning alive rather than paving it.

**Recommendation: WONTFIX-DEFER, explicitly conditioned on RL-080.** Confidence: **medium.**
Keep the shell-function + `compose-prefix` design in canon unchanged for now. Execute `RL-080` (behavioral completion tests — already the top backlog item). If the tests prove delegated completion works from the standalone binary, flip this unit to CANON-CHANGE: replace the function + eval-prefix indirection with a real `scind-compose` executable (retiring the empty-output error hack), keep `compose-prefix` only if scripting consumers want the prefix text, and keep wrapper generation as-is.

**Concrete next action if accepted:** ledger note tying RL-112's resolution to RL-080's outcome; bump RL-080 (already P1) with this added stake.

**Flip evidence:** the RL-080 test results, in either direction — passing tests flip this to CANON-CHANGE; failing tests convert it to a confirmed canon validation (the function architecture earns its keep) plus an Xcind docs fix (the `tools-ide-integration.md:17` claim would be wrong).

`DECISION: [X] accept  [ ] reject  — recommended: WONTFIX-DEFER (conditioned on RL-080)`

---

## RL-038 — Rename Scind `docs/` → `engineering/` (the one PLANNED row): go/no-go

**Ledger row (verbatim, reconciliation-ledger RL-038 / XA-0043):**

> "Rename Scind's design-canon tree docs/ → engineering/ (matching Xcind's LDS track); optionally add a placeholder docs/README.md stating intent for a future user-facing Diátaxis track. No Diátaxis content exists yet in either project. … HUMAN PRODUCT-CALL. Structural/repo-wide change — deferred in this PR (see notes); recommend a separate Scind PR to avoid churning every doc path mid-review. STATUS: still PLANNED — deferred to a separate Scind PR (repo-wide rename churns every doc path mid-review)."

**Current state.** The promote decision itself was already made by human product-call (XA-0043: "PROMOTE … overrides the initial classification"); only execution was deferred, to avoid churning every doc path while PR#3 was in review. **That blocker is gone**: PR#3 merged to `origin/main` as `241c991` on 2026-07-15 (verified via `gh pr view 3` this pass; the local Scind checkout is merely parked on the stale feature branch). The rename is unblocked today.

**Assessment.** The rename is mechanical in a docs-only repo: `git mv docs engineering`, a repo-wide relative-link fix (top-level `README.md`, `DOCUMENTATION-GUIDE.md`, cross-references), and the placeholder `docs/README.md`. One bounded coordination cost remains: essentially every Xcind sync artifact — the correspondence map, all three finding JSONs, the ledger, and all 35 divergence entries' "Scind canon: docs/…" fields — keys on `scind/docs/` paths. The next sync round needs a one-line path-alias rule ("scind `docs/` ≡ `engineering/` as of <rename PR>") in `cross-project-sync.md` rather than a mass rewrite; entries then update opportunistically as they are touched.

No evidence found that argues against the rename itself; it makes the comparison surface symmetric (`scind/engineering/` ↔ `xcind/engineering/`), which simplifies every future sync round's tooling and prose. One sequencing note: if the follow-up canon PR from this brief's accepted rows is opened first, land it before the rename (or write it against the new paths) — same churn logic that deferred the rename originally.

**Recommendation: GO** — unblocked now; land as its own small PR. Confidence: **high.**

**Concrete next action if accepted:** (1) reset the local Scind checkout to `main` (`241c991`); (2) open the rename PR: `git mv docs engineering` + link fixes + placeholder `docs/README.md` stating the future Diátaxis intent (per the XA-0043 edit sketch); (3) add the path-alias rule to `engineering/maintenance/cross-project-sync.md`; (4) flip RL-038 to APPLIED with the new PR reference.

**Flip evidence (no-go case):** a decision to start real Diátaxis user-doc content in Scind soon — in that case do the rename *together with* seeding the new `docs/` tree, one migration instead of two.

`DECISION: [X] accept  [ ] reject  — recommended: GO (unblocked)`

---

## Tally and cross-cutting notes

**Recommendation counts (17 escalation units + RL-038):**

- **WONTFIX-DEFER**: 9 — RL-097, RL-099(+113), RL-100, RL-101, RL-102, RL-103, RL-105, RL-111, RL-112 (three of these confirm adjudications already recorded in the P7 registry: 0022, 0024, and the 0019 contingency).
- **DIVERGENCE**: 3 — RL-095(+114) (confirm+extend 0032), RL-096 (confirm 0023), RL-108 (new entry).
- **FORWARD-PORT**: 3 — RL-106, RL-109, RL-110.
- **CANON-CHANGE**: 1 full — RL-107 (apex opt-out), plus the CANON-CHANGE half of the RL-098 split and small cleanup riders on RL-095/RL-096.
- **SPLIT**: 1 — RL-098(+104): CANON-CHANGE (external `path:`) + DIVERGENCE (app-side self-declaration).
- **GO**: 1 — RL-038 (rename; unblocked — PR#3 already merged as `241c991`).

**Incidental findings surfaced while gathering evidence** (not decisions; candidates for backlog/maintenance rows):

1. Xcind guard gap: an app `.xcind.sh` setting `XCIND_WORKSPACE` silently overwrites the *discovered* workspace name in `__xcind-load-config`, contradicting `self-declaration.feature:17-22` (see RL-098).
2. Scind canon internal inconsistencies on visibility: `private` enum mismatch across three files; phantom `workspace.visibility` label name in `port-types.md:59` (see RL-095).
3. Stale Scind behaviors/spec text contradicting the applied hybrid apex rule (see RL-107) — interacts with pending PROCESS row RL-094 (drop `behaviors/`).
4. Stale "manifest-vs-config caching" bullet in `generated-manifest.md:10` / `configuration.md:609` contradicting the mtime staleness model (see RL-096, RL-102).
5. Xcind spec/code drift: `XCIND_CACHE_SCHEMA` is a SHA input in code but undocumented in `generated-override-files.md` / `hook-lifecycle.md` (see RL-102).
6. Divergence 0007 asserts `path:` grants arbitrary-location indirection, which canon text does not support — corrected by the RL-098 CANON-CHANGE half if accepted, otherwise 0007 needs a wording fix.

**Suggested processing order for accepted rows:** the three confirm-only rows (RL-099, RL-100 WHY-reference, RL-096) are pure bookkeeping; the Scind edits (RL-107, RL-098-half, RL-106, RL-109, RL-110, plus the cleanup riders) batch naturally into one follow-up canon PR; land that PR before the RL-038 rename (or write it against the renamed paths) so each path is written once.
