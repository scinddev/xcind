# P3 — Xcind Learnings, Classified by Destination

**Status**: COMPLETE. 39 learnings extracted from every evidence source in the
plan, each with exactly one classification and a rationale referencing the
global-context §2 directionality rule.
**Date**: 2026-07-15
**Inputs**: [`00-global-context.md`](../00-global-context.md) (§2 operating model,
§2a misclassification safeguard, §5 Go/Bash), [`03-learnings-extraction.md`](../03-learnings-extraction.md),
[`correspondence-map.md`](./correspondence-map.md) + [`.json`](./correspondence-map.json) (P2 substrate).
**Feeds**: P6 (reconciliation — executes CANON-CHANGE + CANON-CONFIRM), P7
(divergence registry — absorbs DIVERGENCE), P4/P5 (a few routed ESCALATEs).
**Machine companion**: [`learnings.json`](./learnings.json) (same 39 records, schema per the plan).

---

## 1. Summary

| Classification | Count | Destination |
|----------------|------:|-------------|
| **CANON-CHANGE** | 19 | Propose/file a change to `scind/docs/` → P6 |
| **CANON-CONFIRM** | 4 | Annotate the Scind ADR/spec as "validated by Xcind" → P6 (low priority) |
| **DIVERGENCE** | 5 | Record in the divergence registry → P7 |
| **PROCESS-ONLY** | 5 | P6 procedure / Xcind maintenance; does not touch Scind design |
| **ESCALATE** | 6 | Human product call / routed to P4/P5/P6 (§2 could not be cleanly applied) |
| **Total** | **39** | |

**Confidence distribution:** 12 high, 17 medium, 5 low (CANON-CHANGE/CONFIRM),
plus the 5 ESCALATEs held for human judgement.

### The §2a safeguard did its job

The one flagged design-assumption conflict — **the apex decision (Scind ADR-0013
↔ Xcind ADR-0017/0007)** — went through the mandatory adversarial re-check and was
**not** paved into a divergence. The re-check split it, and a subsequent **human
product-call** resolved the whole thing to **CANON-CHANGE** (see the callout in
§3). Two other design-assumption DIVERGENCE candidates (two-file config model,
own-app discovery scope) were adversarially re-checked and the divergence label
**survived** on both — recorded with the rejected canon-change reasoning intact so
a later round can reopen them.

---

## 2. Method

Five mining subagents fanned out by **evidence source × subsystem** (per the plan),
then a synthesis pass de-duplicated and reconciled classifications against §2:

1. **ADR-archaeology** — Xcind-only ADRs 0012/0014/0015/0016/0018/0019/0020 + the
   DIVERGED ADR rows (apex, docker-labels).
2. **Source-review ledgers** — the five `source-review-*.md` ledgers + the three
   `implementation/handoffs/*` + `archive/code-review-findings.md` + `sync-audit-*`.
3. **Proxy / networking** — proxy, TLS, apex, host-gateway, service-discovery;
   `archive/prd-proxy.md` / `prd-apex.md` / `research-scind-proxy.md`; as-built libs.
4. **Identity / lifecycle** — project naming, worktree isolation, workspace/app
   identity, hook pipeline, generation cache; the two open cache handoffs.
5. **Config / env** — config resolution, env files, host-env symmetry, variable
   expansion, `_HOST_PORT` service discovery; `archive/prd-app-env.md`.

A **separate** adversarial-re-check subagent (never the one that proposed the
label) then attacked the design-assumption DIVERGENCE/ESCALATE candidates, trying
to prove each was actually a broken Scind assumption. Per the SUPPLEMENT, three
Scind specs were explicitly re-checked for real-world Xcind deviations —
`specs/docker-labels.md` (L-0008, L-0011, L-0034), `specs/workspace-lifecycle.md`
(L-0005/06/07, L-0015/16/17, L-0021), `specs/state-management.md` (L-0005 cross-link,
L-0022, L-0039) — all covered below.

Evidence-source coverage (Done-criterion #1): every Xcind-only ADR is accounted
for — 0012→L-0030, 0014→L-0031, 0015→L-0012, 0016→L-0001/L-0008/L-0011,
0018→L-0003/L-0019/L-0026, 0019→L-0002, 0020→L-0004; the two DIVERGED ADR rows →
L-0013/L-0018/L-0028 (apex) and L-0008/L-0011/L-0034 (docker-labels).

---

## 3. Apex — the §2a adversarial re-check, resolved (human product-call)

The P2 map flagged **Scind-0013 ↔ Xcind-0017** as the single genuine
design-assumption conflict and required an adversarial re-check before any
divergence label. Here is the full audit trail, because the effort's whole point
is that this reasoning stays re-auditable:

1. **Mining** surfaced it as ESCALATE, capturing both readings (positional-default
   ergonomics vs. Scind's principled explicit-primary).
2. **Adversarial re-check** split the bundle:
   - *Default policy* → **CANON-CHANGE** (L-0018): Scind's implicit-primary counts
     ALL exports, so a single-proxied + N-assigned app wrongly gets **no apex**;
     scoping implicit-primary to *proxied* exports closes the hole
     order-independently. This real learning was about to be lost.
   - *Mechanism* (positional vs `primary:true`) → provisionally **DIVERGENCE**, on
     the "YAML maps are unordered" principle.
3. **Human product-call (SUPPLEMENT, overrides)** → the mechanism is **CANON-CHANGE**,
   not a divergence. Proposed Scind change: a **HYBRID apex** — honor explicit
   `primary: true`, else fall back to positional (first-in-array). Rationale: Xcind's
   positional-*only* was itself partly a **Bash-config limitation** (no clean way to
   express `primary` in the Bash contract; first-in-array was easiest), so it never
   earned a "Scind should not adopt" divergence.

**Net:** the apex conflict is fully a **CANON-CHANGE** now, across two composable
records — **L-0018** (apex-eligibility scoped to proxied exports) and **L-0028**
(hybrid selection). Enabling the positional fallback requires Scind to give
`exported_services` a defined declaration order (a sequence, or a documented
first-declared rule). **L-0013** (reporting prefers the apex URL) is the separate,
third apex facet.

---

## 4. CANON-CHANGE (19) — Xcind proved Scind's design wrong/incomplete → P6

Each names a target `scind/docs/` file and sketches the change (Done-criterion #3).

| ID | Learning | Target Scind file | Conf |
|----|----------|-------------------|------|
| **L-0001** | Wildcard TLS needs a ≥2-label proxy domain (`*.localhost` rejected by strict RFC-6125 stacks) | `decisions/0009-flexible-tls-configuration.md` (+ `specs/proxy-infrastructure.md`) | high |
| **L-0002** | Project-name isolation must handle multiple working copies (git worktrees) — `XCIND_INSTANCE` token | `decisions/0001-…project-name-isolation.md` (+ `specs/naming-conventions.md`) | high |
| **L-0003** | Assigned exports need 3 vars — Scind's in-network `_HOST` + host-side `_PORT` is incoherent; add `_HOST_PORT` | `specs/environment-variables.md` | high |
| **L-0004** | Service discovery must offer a host-view rendering, not only the container view | `specs/environment-variables.md` | med |
| **L-0005** | Assigned-port artifacts are live-state-derived; must not be cached as a pure config function | `specs/port-types.md` (+ `workspace-lifecycle.md`, `state-management.md`) | high |
| **L-0006** | Generated artifacts embedding assigned values must be written AFTER allocation | `specs/workspace-lifecycle.md` (+ `generated-manifest.md`) | high |
| **L-0007** | Staleness must catch partial output + generator-version changes; generation must be atomic | `specs/workspace-lifecycle.md` | med |
| **L-0008** | Specify the HTTP→HTTPS redirect middleware + its "define on every service block" Traefik constraint | `specs/proxy-infrastructure.md` (+ `docker-labels.md`) | high |
| **L-0009** | Traefik static config must emit websecure/file-provider/cert mounts only when TLS enabled | `specs/proxy-infrastructure.md` (+ appendices) | med |
| **L-0010** | Proxy HTTP/HTTPS/dashboard ports should be configurable, not hardcoded 80/443/8080 | `specs/configuration-schemas.md` (+ traefik appendix) | low |
| **L-0011** | Add a preferred-scheme `.url` label so consumers need no scheme-selection logic | `specs/docker-labels.md` | low |
| **L-0012** | One `--json` contract should back labels + introspection; read-only must be side-effect-free | `reference/cli.md` | med |
| **L-0013** | Reporting/introspection should prefer the apex URL for the headlining export | `reference/cli.md` | low |
| **L-0014** | First-class app-level env-file injection into all services (distinct from compose-interpolation env files) | `reference/configuration.md` | med |
| **L-0015** | Re-running a config-writing command must preserve unrelated user-authored fields | `specs/workspace-lifecycle.md` | low |
| **L-0016** | Validate resolved/inferred port values at generation time, not downstream in Traefik | `specs/workspace-lifecycle.md` (+ `port-types.md`) | low |
| **L-0017** | Networks declared `external` must have creation failures surfaced, not swallowed | `specs/workspace-lifecycle.md` | med |
| **L-0018** | Apex implicit-primary should be scoped to PROXIED exports (single-proxied apps get apex, zero config) | `specs/configuration-schemas.md` (+ ADR-0013) | med |
| **L-0028** | Apex selection should be HYBRID: explicit `primary:true`, else positional fallback *(human product-call)* | `decisions/0013-apex-url-primary-designation.md` | high |

> **Headline canon-changes** (highest confidence / impact): L-0001 (wildcard-TLS
> constraint — an empirical defect in ADR-0009's "TLS just works" claim),
> L-0002 (worktree instance isolation — the Example-B calibration case),
> L-0003 (`_HOST_PORT` — Scind's assigned-export env vars are self-contradictory),
> and the L-0005/L-0006/L-0007 **cache-soundness cluster** (Scind's mtime-only
> staleness model inherits three real bugs Xcind hit: live-state artifacts cached
> as pure, manifest written before allocation, and partial/version-stale output).

---

## 5. CANON-CONFIRM (4) — Xcind validated an unproven Scind decision → P6 (low priority)

| ID | Confirmation | Scind ref |
|----|--------------|-----------|
| **L-0019** | `SCIND_*` service-discovery injection schema (env-safing, HTTPS-default, apex vars) is build-validated | `specs/environment-variables.md` |
| **L-0020** | No application registry — apps derived from filesystem — works end-to-end | `specs/directory-structure.md` |
| **L-0021** | Workspace state machine is descriptive; runtime inference is sufficient (Scind already says so) | `specs/workspace-lifecycle.md` |
| **L-0022** | Xcind's attempt to out-stateless Scind FAILED — a registry + sticky assigned-port state are load-bearing, confirming ADR-0005 | `specs/state-management.md` |

> L-0022 is the mirror-image of a would-be divergence: Xcind *tried* to be leaner
> than Scind's state model and couldn't, which strengthens the canon rather than
> challenging it.

---

## 6. DIVERGENCE (5) — intentional Xcind compromises Scind should NOT adopt → P7

Each carries its ready-to-file registry line **and** the rejected canon-change
reasoning it was tested against (§2a / Done-criteria #4). The two design-assumption
ones (L-0026, L-0027) additionally passed an adversarial re-check.

| ID | Divergence | Why Scind should not adopt (one-line) | Re-check |
|----|-----------|----------------------------------------|----------|
| **L-0023** | Config as sourceable `.xcind.sh` + `XCIND_*` env vars vs typed YAML | Scind's compiled target gets parsed/validated YAML, strictly safer than eval-ing shell; Scind already rejects env-var config (Example A) | not required (Example A) |
| **L-0024** | `${APP_ENV}` file-pattern expansion vs Scind's declarative flavors | Expansion is only meaningful in sourced Bash; flavors serve the same need declaratively/validated (rides on L-0023) | not required |
| **L-0025** | `config.sh` shell-injection/escaping surface | The injection class exists only because Xcind persists config as a re-sourced shell file; Scind parses YAML and never executes config | not required (Bash-ism) |
| **L-0026** | Own-app-only service-discovery scope (v1) | Cross-app discovery is Scind's core value; DNS aliases (not env vars) are the real connectivity, and Scind's sticky global port state avoids staleness | **PERFORMED — divergence survived** |
| **L-0027** | Single `.xcind.sh` + marker vs two-file declarative workspace/app model | Xcind kept two artifacts anyway; Scind's `workspace.yaml` app-registry with `path:` buys name↔location indirection Xcind forgoes | **PERFORMED — divergence survived** |

**Registry lines (ready for P7):**
- **L-0023** — *Config model.* Xcind: sourceable `.xcind.sh` + `XCIND_*`. Scind: typed YAML, rejects env-var config. Settled; do not adopt.
- **L-0024** — *Environment-specific files.* Xcind: `${APP_ENV}` expansion in bash file-pattern arrays. Scind: typed named flavors resolved by CLI/state. Consequence of the config-model divergence. *(See also the L-0039 flavors learning candidate.)*
- **L-0025** — *Config persistence.* Xcind shell-escapes values written to a sourceable `config.sh`. Scind persists parsed YAML and never executes config; concern does not transfer.
- **L-0026** — *Service-discovery scope.* Xcind v1: own-app only (per-app model, forward-compatible with a workspace-wide v2). Scind: workspace-wide cross-app injection (core value). Do not narrow Scind.
- **L-0027** — *Config file model.* Xcind: one `.xcind.sh` format for both roles (`XCIND_IS_WORKSPACE=1`), apps by directory walk, inline exports. Scind: distinct `workspace.yaml` (registry + `path:`) and app-owned `application.yaml`. No canon change.

---

## 7. PROCESS-ONLY (5) — how to build/test/document, not product design

| ID | Lesson | Lands in |
|----|--------|----------|
| **L-0029** | Read-only invocation paths must resolve config without writing shared state; config-key renames need a deprecation path | P6 procedure |
| **L-0030** | Generator subcommands: uniform stdout/file semantics, named for output not consumer | P6 / CLI-ergonomics note |
| **L-0031** | Two-track docs (user Diátaxis + engineering LDS) once a real tool exists | Scind doc process (when it ships) |
| **L-0032** | CLI argument robustness (missing flag values, surplus positionals, explicit-vs-auto failure) | Xcind maintenance / P6 |
| **L-0033** | Pervasive eng-doc↔code drift → the sync procedure needs a periodic source-review sweep | P6 maintenance procedure |

---

## 8. ESCALATE (6) — human product call / §2 not cleanly applicable

These are **not** filed as divergences (per §2a: ambiguity routes up, never down).
Each captures both readings so a human/P6/P5 call can resolve it.

| ID | Open question | Route | Both readings captured |
|----|---------------|-------|------------------------|
| **L-0034** | Per-export single `tls` key vs Scind's protocol+visibility model; visibility labels dropped | P6 + **P5** | (a) tls-key is more ergonomic → canon-change (folds with L-0008); (b) `visibility` is a Scind-ahead access-control contract → P5, not a P3 learning |
| **L-0035** | Workspace-wide `generated-manifest.yaml`: necessary orchestrator view, or redundant with on-demand `--json`? | **P6** | (a) Xcind serves it all from per-app `--json`; (b) Scind is an orchestrator, the aggregate view has value Xcind never needed |
| **L-0036** | Should Scind adopt Xcind's named, extensible generation hook pipeline (CONFIGURED/RESOLVED/GENERATE/EXECUTE)? | **P4** | Additive/Xcind-ahead, not a disproof (the real purity defect is already L-0005) |
| **L-0037** | App-side self-declared workspace membership (`XCIND_WORKSPACE`) inverts Scind's workspace-owns-apps model | **P6** | (a) Scind's nesting is limiting → canon-change; (b) Scind deliberately owns the app roster → divergence. Burden favors canon-change but the inversion warrants a human call |
| **L-0038** | Scind's `*_HOST_GATEWAY` container env-var mandate is UNMET in Xcind (extra_hosts only) | **P5** | As-built gap: Scind mandates the env var; Xcind implements only `extra_hosts`. Confirmed both directions |
| **L-0039** | Flavors left out of Xcind by design — mechanism coupled to Scind's persistent state model *(human product-call)* | P6/**P5** | (a) env-var selection proves flavors' state-coupling may be heavier than needed; (b) flavors are declarative/validated/discoverable and Scind persists active-flavor state deliberately. **WHY dropped:** flavors need somewhere to record the active flavor; Xcind is stateless, so it used `${APP_ENV}` file-pattern expansion instead |

---

## 9. Routing summary for downstream plans

- **→ P6 (reconciliation, executes changes):** all 19 CANON-CHANGE (file + sketch
  in `learnings.json`), all 4 CANON-CONFIRM (annotate), the 5 PROCESS-ONLY
  procedure notes, and the P6-routed ESCALATEs (L-0035, L-0037, L-0039).
- **→ P7 (divergence registry):** the 5 DIVERGENCE registry lines in §6, each with
  rejected-canon-change reasoning preserved (re-auditable; reopenable).
- **→ P4 (Xcind-ahead):** L-0036 (generation pipeline forward-port).
- **→ P5 (Scind-ahead / as-built gaps):** L-0038 (`*_HOST_GATEWAY` unmet), the
  visibility-label half of L-0034, the flavor-review half of L-0039.

*Nothing was discarded. Every divergence records the canon-change question it was
tested against; every escalation records both readings.*
