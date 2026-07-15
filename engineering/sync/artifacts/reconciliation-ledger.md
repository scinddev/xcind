# P6 — Consolidated Reconciliation Ledger

**Status**: Active — Scind canon changes applied via **[scinddev/scind#3](https://github.com/scinddev/scind/pull/3)**; divergences deferred to P7.
**Date**: 2026-07-15
**Scind PR**: https://github.com/scinddev/scind/pull/3
**Plan**: [`06-reconciliation-and-sync-procedure.md`](../06-reconciliation-and-sync-procedure.md) (Part A).
**Inputs**: [`learnings.md`](./learnings.md)/`.json` (P3), [`xcind-ahead.md`](./xcind-ahead.md)/`.json` (P4), [`scind-ahead.md`](./scind-ahead.md)/`.json` (P5).
**Machine companion**: [`reconciliation-ledger.json`](./reconciliation-ledger.json) (same rows, `meta` + `rows[]`).

This ledger merges **every** P3/P4/P5 action item into one ordered record. The **join key** is the source-finding ID (`L-`/`XA-`/`SA-`/`RG-`); the stable **ledger ID** is `RL-NNN`. It is modelled on the `engineering/maintenance/source-review-*.md` ledgers (stable IDs, priority, status, per-row resolution notes).

### Directionality (global-context §2)

> Scind is canon. Xcind's lessons **upgrade** the canon. *Does a finding teach that the design was wrong → change Scind. Or only how Xcind chose to implement it → record a divergence.* Divergence is the claim that must be **earned**; ambiguity routes to CANON-CHANGE or ESCALATE, never silently to DIVERGENCE.

### Scope & cross-agent boundaries

- **Scind canon changes are applied** (scope lifted 2026-07-15): `CANON-CHANGE` / `PROMOTE` / `CANON-OVERREACH` / `CANON-CONFIRM` rows are edited in the Scind working tree and landed via a Scind branch + PR. Rows flip `PLANNED → APPLIED` with a `scind_pr` reference as they land. Rows still marked `PLANNED` are fully specified here (target file + edit sketch + rationale) but deferred (see per-row notes).
- **Divergences are P7's territory.** `DIVERGENCE` / `DELIBERATELY-DEFERRED` rows are referenced by origin ID and marked `DEFERRED-TO-P7`; this ledger authors **no** entries under `engineering/sync/divergence/` and invents no divergence IDs. P7 owns the registry admission gate + adversarial re-check.
- **Xcind backlog / process / escalation** rows carry a status and a note; they do not change Scind design.

## 1. Summary

| Action type | Count | Destination / status |
|-------------|------:|----------------------|
| **CANON-CHANGE** | 19 | Edit Scind canon → Scind PR |
| **PROMOTE** | 20 | Add to Scind canon (+ ADR) → Scind PR |
| **CANON-OVERREACH** | 1 | Trim/fix Scind canon → Scind PR |
| **CANON-CONFIRM** | 4 | Annotate Scind (low priority) → Scind PR |
| **DIVERGENCE** | 35 | P7 divergence registry |
| **XCIND-BACKLOG** | 7 | Xcind issues/todos |
| **PROCESS** | 8 | P6 procedure / Xcind doc maintenance |
| **ESCALATE** | 20 | Human product call |
| **ADR-POLICY** | 1 | Xcind ADR-0021 (this plan) |
| **Total** | **115** | |

**Scind-affecting rows**: 40 substantive (**19** CANON-CHANGE + **20** PROMOTE + **1** CANON-OVERREACH) + **4** CANON-CONFIRM annotations = 44 total. After merging **8** cross-plan duplicate pairs (a P3 learning and a P4 capability that target the *same* Scind edit), these collapse to ≈32 **distinct** Scind edit-sets.

### Cross-plan duplicate pairs (apply each edit once)

The consolidated view's main job is to catch findings that two plans surfaced independently. These pairs are the **same** Scind change; the ledger keeps both rows (for traceability) but they resolve to one edit:

| Scind edit | P3 learning | P4 capability |
|------------|-------------|---------------|
| Wildcard TLS ≥2-label proxy-domain constraint | `L-0001` | `XA-0002` |
| _HOST_PORT assigned-export discovery var | `L-0003` | `XA-0003` |
| Host-view env symmetry | `L-0004` | `XA-0017` |
| Live-state content is not cacheable as pure config | `L-0005` | `XA-0001` |
| HTTP→HTTPS redirect middleware / per-export tls | `L-0008` | `XA-0005` |
| Configurable proxy host ports | `L-0010` | `XA-0004` |
| Preferred-scheme .url label | `L-0011` | `XA-0007` |
| App-level env-file injection split | `L-0014` | `XA-0018` |

Two more clusters share a target without being exact duplicates: the **apex cluster** (`L-0013` reporting + `L-0018` proxied-scoping + `L-0028` hybrid selection, absorbing P4 `XA-0025`) all edit `docs/decisions/0013-apex-url-primary-designation.md` + `configuration-schemas.md`; and the **cache-soundness cluster** (`L-0005`/`L-0006`/`L-0007` + `XA-0001`) edit the staleness/generation contract.

## 2. Master ledger

Ordered: Scind-canon rows first (by action, then priority), then P7 divergences, Xcind backlog, process, escalations, policy. Full per-row `edit_sketch`, `rationale`-equivalent notes, and `merge_with` are in the JSON.

| Ledger ID | Join key | Plan | Action | Pri | Status | Target |
|-----------|----------|------|--------|-----|--------|--------|
| `RL-001` | `L-0001` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/decisions/0009-flexible-tls-configuration.md (+ docs/specs/proxy-infrastructure.md TLS section) |
| `RL-002` | `L-0002` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/decisions/0001-docker-compose-project-name-isolation.md (+ docs/specs/naming-conventions.md) |
| `RL-003` | `L-0003` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/specs/environment-variables.md (+ generated-manifest.md, reference/configuration.md) |
| `RL-004` | `L-0004` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/specs/environment-variables.md (+ new host-env ADR) |
| `RL-005` | `L-0005` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/specs/port-types.md (+ workspace-lifecycle.md Staleness Detection, state-management.md) |
| `RL-006` | `L-0006` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/specs/workspace-lifecycle.md Generation Logic (+ generated-manifest.md) |
| `RL-007` | `L-0007` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/specs/workspace-lifecycle.md Staleness Detection |
| `RL-008` | `L-0008` | P3 | CANON-CHANGE | P1 | APPLIED | scind: docs/specs/proxy-infrastructure.md (Entry Points/Dynamic Routing) + docs/specs/docker-labels.md |
| `RL-009` | `L-0009` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/specs/proxy-infrastructure.md + appendices/proxy-infrastructure/{traefik-config.yaml,traefik-compose.yaml} |
| `RL-010` | `L-0010` | P3 | CANON-CHANGE | P3 | APPLIED | scind: docs/specs/configuration-schemas.md proxy schema + traefik-compose appendix |
| `RL-011` | `L-0011` | P3 | CANON-CHANGE | P3 | APPLIED | scind: docs/specs/docker-labels.md |
| `RL-012` | `L-0012` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/reference/cli.md (or a new specs contract doc) |
| `RL-013` | `L-0013` | P3 | CANON-CHANGE | P3 | APPLIED | scind: docs/reference/cli.md |
| `RL-014` | `L-0014` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/reference/configuration.md (+ docs/specs/configuration-schemas.md) |
| `RL-015` | `L-0015` | P3 | CANON-CHANGE | P3 | APPLIED | scind: docs/specs/workspace-lifecycle.md |
| `RL-016` | `L-0016` | P3 | CANON-CHANGE | P3 | APPLIED | scind: docs/specs/workspace-lifecycle.md Generation Logic (+ port-types.md) |
| `RL-017` | `L-0017` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/specs/workspace-lifecycle.md Startup Sequence (+ generated-override-files.md) |
| `RL-018` | `L-0018` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/specs/configuration-schemas.md (Primary Export Designation) + docs/decisions/0013-apex-url-primary-designation.md |
| `RL-019` | `L-0028` | P3 | CANON-CHANGE | P2 | APPLIED | scind: docs/decisions/0013-apex-url-primary-designation.md |
| `RL-020` | `XA-0001` | P4 | PROMOTE | P1 | APPLIED | scind: docs/specs/generated-manifest.md / state-management.md |
| `RL-021` | `XA-0002` | P4 | PROMOTE | P1 | APPLIED | scind: docs/specs/proxy-infrastructure.md TLS section / ADR-0009 |
| `RL-022` | `XA-0003` | P4 | PROMOTE | P1 | APPLIED | scind: docs/specs/environment-variables.md |
| `RL-023` | `XA-0004` | P4 | PROMOTE | P3 | APPLIED | scind: proxy config (proxy.yaml + env) + docs/specs/environment-variables.md/proxy-infrastructure.md |
| `RL-024` | `XA-0005` | P4 | PROMOTE | P1 | APPLIED | scind: docs/specs/port-types.md + docs/decisions/0009-flexible-tls-configuration.md |
| `RL-025` | `XA-0006` | P4 | PROMOTE | P1 | APPLIED | scind: docs/specs/docker-labels.md |
| `RL-026` | `XA-0007` | P4 | PROMOTE | P3 | APPLIED | scind: docs/specs/docker-labels.md |
| `RL-027` | `XA-0008` | P4 | PROMOTE | P2 | APPLIED | scind: docs/specs/proxy-infrastructure.md TLS section |
| `RL-028` | `XA-0009` | P4 | PROMOTE | P2 | APPLIED | scind: docs/specs/state-management.md |
| `RL-029` | `XA-0010` | P4 | PROMOTE | P2 | APPLIED | scind: docs/specs/shell-integration.md + docs/reference/cli.md |
| `RL-030` | `XA-0011` | P4 | PROMOTE | P2 | APPLIED | scind: docs/reference/cli.md |
| `RL-031` | `XA-0012` | P4 | PROMOTE | P3 | APPLIED | scind: docs/specs/port-types.md (or generated-manifest.md) + docs/reference/cli.md |
| `RL-032` | `XA-0013` | P4 | PROMOTE | P2 | APPLIED | scind: docs/reference/cli.md + docs/specs/generated-manifest.md |
| `RL-033` | `XA-0014` | P4 | PROMOTE | P3 | APPLIED | scind: docs/specs/shell-integration.md + docs/reference/cli.md |
| `RL-034` | `XA-0015` | P4 | PROMOTE | P3 | APPLIED | scind: docs/reference/cli.md Version Information |
| `RL-035` | `XA-0016` | P4 | PROMOTE | P3 | APPLIED | scind: docs/reference/cli.md + docs/specs/state-management.md |
| `RL-036` | `XA-0017` | P4 | PROMOTE | P2 | APPLIED | scind: docs/specs/environment-variables.md + new ADR (analogous to Scind ADR-0018) |
| `RL-037` | `XA-0018` | P4 | PROMOTE | P2 | APPLIED | scind: docs/reference/configuration.md + docs/specs/configuration-schemas.md |
| `RL-038` | `XA-0043` | P4 | PROMOTE | P2 | PLANNED | scind: rename docs/ → engineering/ (+ optional placeholder docs/README.md) |
| `RL-039` | `XA-0044` | P4 | PROMOTE | P2 | APPLIED | scind: docs/specs/environment-variables.md + docs/specs/state-management.md |
| `RL-040` | `SA-0005` | P5 | CANON-OVERREACH | P1 | APPLIED | scind: docs/specs/state-management.md |
| `RL-041` | `L-0019` | P3 | CANON-CONFIRM | P3 | APPLIED | scind: docs/specs/environment-variables.md |
| `RL-042` | `L-0020` | P3 | CANON-CONFIRM | P3 | APPLIED | scind: docs/specs/directory-structure.md |
| `RL-043` | `L-0021` | P3 | CANON-CONFIRM | P3 | APPLIED | scind: docs/specs/workspace-lifecycle.md |
| `RL-044` | `L-0022` | P3 | CANON-CONFIRM | P3 | APPLIED | scind: docs/specs/state-management.md (+ ADR-0005) |
| `RL-045` | `L-0023` | P3 | DIVERGENCE | P3 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-046` | `L-0024` | P3 | DIVERGENCE | P3 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-047` | `L-0025` | P3 | DIVERGENCE | P3 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-048` | `L-0026` | P3 | DIVERGENCE | P3 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-049` | `L-0027` | P3 | DIVERGENCE | P3 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-050` | `XA-0030` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-051` | `XA-0031` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-052` | `XA-0032` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-053` | `XA-0033` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-054` | `XA-0034` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-055` | `XA-0035` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-056` | `XA-0036` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-057` | `XA-0037` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-058` | `XA-0038` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-059` | `XA-0039` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-060` | `XA-0040` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-061` | `XA-0041` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-062` | `XA-0042` | P4 | DIVERGENCE | P4 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-063` | `SA-0001` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-064` | `SA-0002` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-065` | `SA-0006` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-066` | `SA-0007` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-067` | `SA-0008` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-068` | `SA-0009` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-069` | `SA-0010` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-070` | `SA-0011` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-071` | `SA-0013` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-072` | `SA-0014` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-073` | `SA-0015` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-074` | `SA-0017` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-075` | `SA-0019` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-076` | `SA-0020` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-077` | `SA-0023` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-078` | `SA-0024` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-079` | `SA-0025` | P5 | DIVERGENCE | P5 | DEFERRED-TO-P7 | engineering/sync/divergence/ (P7 registry) |
| `RL-080` | `SA-0003` | P5 | XCIND-BACKLOG | P1 | XCIND-BACKLOG | xcind: test/ (behavioral completion tests) |
| `RL-081` | `SA-0004` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: lib/xcind/ + bin/xcind-config |
| `RL-082` | `SA-0012` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: bin/xcind-proxy |
| `RL-083` | `SA-0021` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: bin/ context-detection error paths |
| `RL-084` | `SA-0022` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: bin/ arg parsers |
| `RL-085` | `SA-0016` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: roadmap / future |
| `RL-086` | `SA-0018` | P5 | XCIND-BACKLOG | P3 | XCIND-BACKLOG | xcind: roadmap / future |
| `RL-087` | `L-0029` | P3 | PROCESS | P3 | PROCESS | Scind build guidance (P6) — no canon change |
| `RL-088` | `L-0030` | P3 | PROCESS | P3 | PROCESS | Scind CLI-ergonomics guideline (P6) — no canon change |
| `RL-089` | `L-0031` | P3 | PROCESS | P3 | PROCESS | Scind documentation process (P6) — no canon change |
| `RL-090` | `L-0032` | P3 | PROCESS | P3 | PROCESS | Xcind maintenance / P6 — no canon change |
| `RL-091` | `L-0033` | P3 | PROCESS | P2 | PROCESS | P6 maintenance procedure (cross-project-sync.md) |
| `RL-092` | `PROC-0001` | P5 | PROCESS | P3 | PROCESS | xcind: engineering/decisions/0005-structure-vs-state-separation.md |
| `RL-093` | `PROC-0002` | P5 | PROCESS | P3 | PROCESS | xcind: engineering/decisions/ (new ADR) |
| `RL-094` | `PROC-0003` | P4 | PROCESS | P3 | PROCESS | xcind + scind: engineering/behaviors/ (both) |
| `RL-095` | `L-0034` | P3 | ESCALATE | P2 | ESCALATED | human product call → P6 + P5 |
| `RL-096` | `L-0035` | P3 | ESCALATE | P2 | ESCALATED | human product call → P6 |
| `RL-097` | `L-0036` | P3 | ESCALATE | P2 | ESCALATED | human product call → P4 (forward-port) |
| `RL-098` | `L-0037` | P3 | ESCALATE | P2 | ESCALATED | human product call → P6 |
| `RL-099` | `L-0038` | P3 | ESCALATE | P2 | ESCALATED | human product call → P5 |
| `RL-100` | `L-0039` | P3 | ESCALATE | P2 | ESCALATED | human product call → P6/P5 |
| `RL-101` | `XA-0019` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-102` | `XA-0020` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-103` | `XA-0021` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-104` | `XA-0022` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-105` | `XA-0023` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-106` | `XA-0024` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-107` | `XA-0025` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-108` | `XA-0026` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-109` | `XA-0027` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-110` | `XA-0028` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-111` | `XA-0029` | P4 | ESCALATE | P2 | ESCALATED | human product call |
| `RL-112` | `SA-0026` | P5 | ESCALATE | P2 | ESCALATED | human product call → P6/Scind design |
| `RL-113` | `RG-0001` | P4 | ESCALATE | P3 | ESCALATED | human product call → P5/P3 |
| `RL-114` | `RG-0002` | P4 | ESCALATE | P3 | ESCALATED | human product call → P5/P3 |
| `RL-115` | `RL-ADR-POLICY` | P6 | ADR-POLICY | P1 | APPLIED | xcind: engineering/decisions/0021-cross-repo-adr-cross-referencing.md (+ scind note) |

## 3. Scind canon changes — full specification (reviewable plan)

Every `CANON-CHANGE` / `PROMOTE` / `CANON-OVERREACH` / `CANON-CONFIRM` row, with its exact target file and a sketched edit. This is the reviewable change-set the Scind PR implements.

### 3.1 CANON-CHANGE — Xcind proved the design wrong/incomplete

**`RL-001` (L-0001, P1, APPLIED)** — ≥2-label proxy-domain constraint for wildcard TLS · merges `XA-0002`
*Target:* scind: docs/decisions/0009-flexible-tls-configuration.md (+ docs/specs/proxy-infrastructure.md TLS section)
*Edit:* Add constraint: any proxy domain used for wildcard TLS MUST contain ≥1 dot (≥2 labels) under non-disabled TLS; strict RFC-6125 stacks reject *.singlelabel even with a valid SAN; implementations SHOULD warn (not fail) on a single-label domain. Optional HSTS-TLD caveat.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0002 — apply once. Headline canon-change.

**`RL-002` (L-0002, P1, APPLIED)** — Project-name isolation must handle multiple working copies (worktrees)
*Target:* scind: docs/decisions/0001-docker-compose-project-name-isolation.md (+ docs/specs/naming-conventions.md)
*Edit:* State {workspace}-{application} assumes one working copy; introduce a per-instance disambiguation token that EXTENDS the project name (empty token = current behavior, backward compatible); fold into project-name + internal-network patterns; resolution order explicit > opt-out > auto-detect-from-linked-worktree.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Xcind source = ADR-0019. Example-B calibration case.

**`RL-003` (L-0003, P1, APPLIED)** — Assigned exports need three vars (_HOST + _PORT + _HOST_PORT) · merges `XA-0003`
*Target:* scind: docs/specs/environment-variables.md (+ generated-manifest.md, reference/configuration.md)
*Edit:* Split assigned-export vars into _HOST (in-network alias) + _PORT (container port) + _HOST_PORT (allocated host port). Current _HOST/_PORT pair is self-contradictory when host port != container port.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0003 — apply once. Defect fix, not mere promotion.

**`RL-004` (L-0004, P2, APPLIED)** — Service discovery must offer a host-view rendering · merges `XA-0017`
*Target:* scind: docs/specs/environment-variables.md (+ new host-env ADR)
*Edit:* Add Host-View Environment section: opt-in host-view env file whose assigned exports use 127.0.0.1 + host port while proxied/apex keep the routable hostname, from the SAME computation as container injection; document dotenv/compose precedence; explicit own/block write mode.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0017. Depends on L-0003. If Scind rules host-side access out of scope → downgrade to divergence.

**`RL-005` (L-0005, P1, APPLIED)** — Assigned-port artifacts are live-state-derived, not a pure config function · merges `XA-0001`
*Target:* scind: docs/specs/port-types.md (+ workspace-lifecycle.md Staleness Detection, state-management.md)
*Edit:* State assigned port values resolve against live global port state (not a pure function of app config); add global assigned-ports state as a regeneration trigger; define an always-regenerate class for live-state-derived override content.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0001. Cache-soundness cluster with L-0006/L-0007.

**`RL-006` (L-0006, P1, APPLIED)** — Generated artifacts embedding assigned values must be written AFTER allocation
*Target:* scind: docs/specs/workspace-lifecycle.md Generation Logic (+ generated-manifest.md)
*Edit:* Add explicit assigned-port allocation/validation step; require it to precede override (step 8) + manifest (step 10) writes; add manifest freshness contract (written after allocation, reflects post-allocation values).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Cache-soundness cluster.

**`RL-007` (L-0007, P2, APPLIED)** — Staleness must catch partial output + generator-version changes
*Target:* scind: docs/specs/workspace-lifecycle.md Staleness Detection
*Edit:* Require atomic generation (temp + rename) with a completeness marker; treat partial/incomplete output as stale; add generator/schema version to staleness inputs; a failed resolve step must fail generation, not persist a truncated artifact.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Cache-soundness cluster.

**`RL-008` (L-0008, P1, APPLIED)** — Specify HTTP→HTTPS redirect middleware + every-service-block constraint · merges `XA-0005`
*Target:* scind: docs/specs/proxy-infrastructure.md (Entry Points/Dynamic Routing) + docs/specs/docker-labels.md
*Edit:* Specify redirect via a redirectscheme middleware on the HTTP router; note the middleware DEFINITION must be repeated on every rendered service block because Traefik's Docker provider reads labels only from running containers (idempotent repetition).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Overlaps PROMOTE XA-0005 (per-export tls). Apply together.

**`RL-009` (L-0009, P2, APPLIED)** — Traefik static config emits websecure/file-provider/cert mounts only when TLS enabled
*Target:* scind: docs/specs/proxy-infrastructure.md + appendices/proxy-infrastructure/{traefik-config.yaml,traefik-compose.yaml}
*Edit:* Annotate the websecure entrypoint, file provider, :443 port and ./certs//./dynamic mounts as emitted only when tls.mode != disabled (mirroring the already-conditional dashboard).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Relates XA-0008 (cert cascade).

**`RL-010` (L-0010, P3, APPLIED)** — Proxy HTTP/HTTPS/dashboard ports should be configurable · merges `XA-0004`
*Target:* scind: docs/specs/configuration-schemas.md proxy schema + traefik-compose appendix
*Edit:* Add proxy.http_port / proxy.https_port (reuse proxy.dashboard.port); reference them in the appendix ports: block instead of literal 80/443/8080.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0004.

**`RL-011` (L-0011, P3, APPLIED)** — Add preferred-scheme .url label · merges `XA-0007`
*Target:* scind: docs/specs/docker-labels.md
*Edit:* Add scind.export.{name}.proxy.url / scind.apex.proxy.url (HTTPS when an HTTPS router exists else HTTP), additive to the per-protocol URL labels.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0007.

**`RL-012` (L-0012, P2, APPLIED)** — Single --json contract backs labels+introspection; reads side-effect-free
*Target:* scind: docs/reference/cli.md (or a new specs contract doc)
*Edit:* (1) Define a stable --json introspection contract (assignedExports/proxiedExports keyed by export name) shared by Traefik label generation and read/show commands; (2) state read-only commands must resolve from persisted/config state and never trigger generation, cert provisioning, or proxy startup.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Related to PROMOTE XA-0011 (per-app introspection).

**`RL-013` (L-0013, P3, APPLIED)** — Reporting/introspection should prefer the apex URL · merges `XA-0025`
*Target:* scind: docs/reference/cli.md
*Edit:* scind urls / app show report the apex URL for the primary proxied export (per-export URL kept in detail view); add apex/apex_host as additive JSON fields from the same source as scind.apex.* labels.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Apex cluster (with L-0018, L-0028). Absorbs P4 ESCALATE XA-0025 handed back to P3.

**`RL-014` (L-0014, P2, APPLIED)** — First-class app-level env-file injection into all services · merges `XA-0018`
*Target:* scind: docs/reference/configuration.md (+ docs/specs/configuration-schemas.md)
*Edit:* Add app-level env-file injection (compose_env_files for --env-file interpolation vs app_env_files generating env_file: on every service); document the two-scope Compose distinction explicitly.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Duplicate of PROMOTE XA-0018.

**`RL-015` (L-0015, P3, APPLIED)** — Re-running a config-writing command must preserve unrelated user fields
*Target:* scind: docs/specs/workspace-lifecycle.md
*Edit:* State that re-running workspace init (or any command writing workspace.yaml/application.yaml) performs targeted field updates and preserves unrelated user-authored fields, extending the overrides/ preservation guarantee to the primary config files.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-016` (L-0016, P3, APPLIED)** — Validate resolved/inferred port values at generation time
*Target:* scind: docs/specs/workspace-lifecycle.md Generation Logic (+ port-types.md)
*Edit:* Add a port-value validation step (resolved/inferred ports must be integers 1–65535, protocol suffixes handled explicitly); invalid ports fail at generation with an export-named error, not downstream in Traefik.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-017` (L-0017, P2, APPLIED)** — External-network creation failures must be surfaced, not swallowed
*Target:* scind: docs/specs/workspace-lifecycle.md Startup Sequence (+ generated-override-files.md)
*Edit:* Startup steps 1–2: network/proxy creation failures must emit a diagnostic naming the resource + underlying error (the overlay declares it external, so compose otherwise fails opaquely); define whether the failure is fatal to up.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-018` (L-0018, P2, APPLIED)** — Apex implicit-primary scoped to PROXIED exports
*Target:* scind: docs/specs/configuration-schemas.md (Primary Export Designation) + docs/decisions/0013-apex-url-primary-designation.md
*Edit:* Refine implicit-primary from 'exactly one exported service' to 'exactly one PROXIED exported service ⇒ implicitly primary (apex-eligible)'; assigned exports don't count against eligibility. Keep explicit primary:true required only when 2+ proxied exports compete.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Apex cluster. Adversarial re-check SPLIT this (order-independent half).

**`RL-019` (L-0028, P2, APPLIED)** — Apex selection HYBRID: explicit primary:true, else positional fallback
*Target:* scind: docs/decisions/0013-apex-url-primary-designation.md
*Edit:* Amend to a HYBRID rule: explicit primary:true always wins; when none marked, fall back to POSITIONAL (first-declared proxied export) and still emit an apex, instead of 'none marked → no apex'. Requires giving exported_services a defined declaration order (sequence, or documented first-declared rule).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Apex cluster. HUMAN PRODUCT-CALL overrode a provisional divergence. Resolves SA-0006 overreach candidacy.

### 3.2 PROMOTE — capabilities Scind should adopt

**`RL-020` (XA-0001, P1, APPLIED)** — Generation-cache live-state correctness · merges `L-0005`
*Target:* scind: docs/specs/generated-manifest.md / state-management.md
*Edit:* Staleness/regeneration must distinguish config-derived override content (cacheable) from live-state-derived content (assigned host ports, discovery env vars) and refresh the latter even when the config-based staleness check reports up-to-date.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0005.

**`RL-021` (XA-0002, P1, APPLIED)** — Proxy domain must be multi-label · merges `L-0001`
*Target:* scind: docs/specs/proxy-infrastructure.md TLS section / ADR-0009
*Edit:* Same as L-0001: mandate ≥1 dot in the proxy domain + non-fatal startup warning under non-disabled TLS; cite RFC-6125 strict-vs-lenient matching (ADR-0016 evidence).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0001.

**`RL-022` (XA-0003, P1, APPLIED)** — _HOST_PORT assigned-export discovery var · merges `L-0003`
*Target:* scind: docs/specs/environment-variables.md
*Edit:* Add SCIND_{APP}_{SERVICE}_HOST_PORT (allocated host-published port) alongside in-network _HOST/_PORT.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0003.

**`RL-023` (XA-0004, P3, APPLIED)** — Configurable proxy host ports · merges `L-0010`
*Target:* scind: proxy config (proxy.yaml + env) + docs/specs/environment-variables.md/proxy-infrastructure.md
*Edit:* Add SCIND_PROXY_HTTP_PORT/HTTPS_PORT/DASHBOARD_PORT; specify discovery _PORT/_URL include the port when non-default. Defaults unchanged (80/443/8080).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same capability as L-0010.

**`RL-024` (XA-0005, P1, APPLIED)** — Per-export TLS metadata + redirect middleware pattern · merges `L-0008`
*Target:* scind: docs/specs/port-types.md + docs/decisions/0009-flexible-tls-configuration.md
*Edit:* Add a per-export tls attribute (auto/require/disable); document the redirect-middleware pattern (shared middleware repeated on every service block; redirect-only routers point at noop@internal).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Overlaps CANON-CHANGE L-0008 (redirect mechanism).

**`RL-025` (XA-0006, P1, APPLIED)** — traefik.docker.network label + pinned router→service binding
*Target:* scind: docs/specs/docker-labels.md
*Edit:* Add traefik.docker.network={proxy-network} to required routing labels and document explicit router→loadbalancer-service binding (multi-network containers otherwise mis-route intermittently — a correctness bug given ADR-0002).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-026` (XA-0007, P3, APPLIED)** — Preferred scheme-agnostic .url label · merges `L-0011`
*Target:* scind: docs/specs/docker-labels.md
*Edit:* Add a canonical scind.export.{name}.url / scind.apex.url (https when an HTTPS router serves the export else http), additive to per-protocol labels.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0011.

**`RL-027` (XA-0008, P2, APPLIED)** — TLS cert cascade + domain-change regeneration marker
*Target:* scind: docs/specs/proxy-infrastructure.md TLS section
*Edit:* Specify the auto-mode resolution order (user cert > cached > mkcert > openssl self-signed) and require regenerating the wildcard when the configured domain changes (recorded-domain marker), else a stale-CN cert is served.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Relates L-0009.

**`RL-028` (XA-0009, P2, APPLIED)** — Path-existence GC of assigned ports
*Target:* scind: docs/specs/state-management.md
*Edit:* Add a GC rule: drop an assigned-port entry whose recorded application path no longer exists, run on the port-inventory maintenance commands.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-029` (XA-0010, P2, APPLIED)** — Context-aware shell prompt segment
*Target:* scind: docs/specs/shell-integration.md + docs/reference/cli.md
*Edit:* Add a scind prompt command + a generate path emitting a Starship snippet; specify the fast context-only detection path and --print field / --detect / apex-url (OSC 8) semantics.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Scind shell-integration currently has no prompt concept at all.

**`RL-030` (XA-0011, P2, APPLIED)** — Per-app export introspection (urls/ports/exports, scalar output)
*Target:* scind: docs/reference/cli.md
*Edit:* Add scind app urls/ports/exports with a [SERVICE] filter and -q/scalar output for scripting; align JSON shape with assignedExports/proxiedExports maps.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Related to CANON-CHANGE L-0012.

**`RL-031` (XA-0012, P3, APPLIED)** — Unified per-export descriptor
*Target:* scind: docs/specs/port-types.md (or generated-manifest.md) + docs/reference/cli.md
*Edit:* Define a unified export descriptor merging assigned + proxied by export name (type/service/port/url/tls/apex) in one view; expose via app show / exports.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-032` (XA-0013, P2, APPLIED)** — Resolved/flattened compose-config export
*Target:* scind: docs/reference/cli.md + docs/specs/generated-manifest.md
*Edit:* Add a resolved/flattened compose-config output (stdout + arbitrary file), the substrate for the Dev Container workflow; document the devcontainer consumer. CLI shape (subcommand vs flag) is Scind's to decide.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-033` (XA-0014, P3, APPLIED)** — POSIX docker/compose wrapper generation
*Target:* scind: docs/specs/shell-integration.md + docs/reference/cli.md
*Edit:* Add a wrapper-script generator emitting real executable docker/docker-compose wrappers for tools (JetBrains, CI) that exec a literal binary and cannot call the scind-compose shell function.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-034` (XA-0015, P3, APPLIED)** — Build provenance in --version
*Target:* scind: docs/reference/cli.md Version Information
*Edit:* Specify a SemVer build-metadata suffix (+source.rev.dirty.date) populated at build time. Mechanism (env-var injection) is Bash-flavored/excluded (§5); the capability (provenance disclosure) promotes.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-035` (XA-0016, P3, APPLIED)** — Fine-grained registry ops: register/forget PATH
*Target:* scind: docs/reference/cli.md + docs/specs/state-management.md
*Edit:* Add scind workspace register PATH (cloned-but-never-run workspace, no Docker labels) and scind workspace forget PATH (drop one moved/deleted entry).
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)

**`RL-036` (XA-0017, P2, APPLIED)** — Host/container env symmetry · merges `L-0004`
*Target:* scind: docs/specs/environment-variables.md + new ADR (analogous to Scind ADR-0018)
*Edit:* Add a host-view env export: opt-in host-flavored dotenv emitting SCIND_{APP}_{EXPORT}_* with loopback IP + published host port for assigned exports and the routable hostname for proxied/apex; own/block write modes.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0004. Self-flagged PROMOTE in Xcind ADR-0020.

**`RL-037` (XA-0018, P2, APPLIED)** — App-level env-file interpolation-vs-injection split · merges `L-0014`
*Target:* scind: docs/reference/configuration.md + docs/specs/configuration-schemas.md
*Edit:* Add compose_env_files (--env-file interpolation) and app_env_files (env_file: injection into all services) to application.yaml.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Same edit as CANON-CHANGE L-0014.

**`RL-038` (XA-0043, P2, PLANNED)** — Two-track documentation (Diátaxis + LDS)
*Target:* scind: rename docs/ → engineering/ (+ optional placeholder docs/README.md)
*Edit:* Rename Scind's design-canon tree docs/ → engineering/ (matching Xcind's LDS track); optionally add a placeholder docs/README.md stating intent for a future user-facing Diátaxis track. No Diátaxis content exists yet in either project.
*Notes:* HUMAN PRODUCT-CALL. Structural/repo-wide change — deferred in this PR (see notes); recommend a separate Scind PR to avoid churning every doc path mid-review. STATUS: still PLANNED — deferred to a separate Scind PR (repo-wide rename churns every doc path mid-review).

**`RL-039` (XA-0044, P2, APPLIED)** — XDG Base Directory split (config vs state)
*Target:* scind: docs/specs/environment-variables.md + docs/specs/state-management.md
*Edit:* Default SCIND_STATE_DIR to $XDG_STATE_HOME/scind (fallback ~/.local/state/scind); keep SCIND_CONFIG_DIR under $XDG_CONFIG_HOME/scind; align with the XDG spec (config vs state vs data). Encodes ADR-0005 at the filesystem level.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* HUMAN PRODUCT-CALL.

### 3.3 CANON-OVERREACH — Scind over-specified (reverse learning)

**`RL-040` (SA-0005, P1, APPLIED)** — Fail-fast port-conflict at startup mis-fires on idempotent re-up
*Target:* scind: docs/specs/state-management.md
*Edit:* Startup port-conflict check must exclude ports bound by the workspace's OWN running containers before declaring a conflict, else idempotent workspace up reports false conflicts (the flapping Xcind hit). Verify Scind's port_inventory + bind-probe attributes a bound port to its owner.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Reverse learning (Xcind→Scind). Confidence medium — hinges on Scind's port_inventory ownership attribution.

### 3.4 CANON-CONFIRM — Xcind validated an unproven decision (annotate)

**`RL-041` (L-0019, P3, APPLIED)** — SCIND_* discovery injection schema build-validated
*Target:* scind: docs/specs/environment-variables.md
*Edit:* Annotate that the SCIND_{APP}_{EXPORT}_{SUFFIX} injection schema (env-safing, HTTPS-default, apex vars) is build-validated by the Xcind PoC. No behavioral change.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Low priority annotation. _HOST/_HOST_PORT defect is L-0003, separate.

**`RL-042` (L-0020, P3, APPLIED)** — Derived-not-tracked application model validated
*Target:* scind: docs/specs/directory-structure.md
*Edit:* Optionally note the derived-not-tracked application model (apps resolved from workspace directory contents, no registry) is PoC-validated.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Low priority annotation.

**`RL-043` (L-0021, P3, APPLIED)** — Workspace state machine is descriptive; runtime inference sufficient
*Target:* scind: docs/specs/workspace-lifecycle.md
*Edit:* Keep the state table as descriptive prose; optionally add a note that the PoC confirmed no stored state artifact is needed to drive lifecycle transitions.
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Low priority annotation.

**`RL-044` (L-0022, P3, APPLIED)** — Registry + sticky assigned-port state are load-bearing (confirms ADR-0005)
*Target:* scind: docs/specs/state-management.md (+ ADR-0005)
*Edit:* No design change — record that Xcind's attempt to out-stateless Scind failed: a workspace registry + sticky assigned-port state are load-bearing, confirming ADR-0005. (Xcind's stale 'stateless' wording is an Xcind-maintenance item.)
*Applied:* [scinddev/scind#3](https://github.com/scinddev/scind/pull/3)
*Notes:* Low priority annotation.

## 4. Divergences → P7 registry

Referenced by origin ID only; **P7 owns** `engineering/sync/divergence/`, the admission gate, and the adversarial re-check for design/scope (⚠) rows. Registry-ready "why Scind should NOT adopt" text + the rejected-canon-change reasoning already live in the P3/P4/P5 JSON artifacts.

| Ledger ID | Join key | Plan | Divergence | Note |
|-----------|----------|------|-----------|------|
| `RL-045` | `L-0023` | P3 | Config as sourceable .xcind.sh + XCIND_* vs typed YAML (Example A) | P7-owned. Do not author divergence entries here. |
| `RL-046` | `L-0024` | P3 | ${APP_ENV} file-pattern expansion vs Scind declarative flavors | P7-owned. Do not author divergence entries here. |
| `RL-047` | `L-0025` | P3 | config.sh shell-injection/escaping surface (Bash-ism) | P7-owned. Do not author divergence entries here. |
| `RL-048` | `L-0026` | P3 | Own-app-only service-discovery scope (v1) — re-check survived | P7-owned. Do not author divergence entries here. |
| `RL-049` | `L-0027` | P3 | Single .xcind.sh + marker vs two-file workspace/app model — re-check survived | P7-owned. Do not author divergence entries here. |
| `RL-050` | `XA-0030` | P4 | Concern-split 8 per-hook overlays vs 1 monolithic override | P7-owned. |
| `RL-051` | `XA-0031` | P4 | Internal 4-array phase vocabulary (CONFIGURED/RESOLVED/GENERATE/EXECUTE) | P7-owned. |
| `RL-052` | `XA-0032` | P4 | Per-app SHA-keyed config.json introspection artifact | P7-owned. |
| `RL-053` | `XA-0033` | P4 | Stateless identity/registry (path+timestamp TSV) | P7-owned. |
| `RL-054` | `XA-0034` | P4 | Default domain localhost.scind.io | P7-owned. |
| `RL-055` | `XA-0035` | P4 | Assigned-port sticky-trust allocation (fail-open) | P7-owned. |
| `RL-056` | `XA-0036` | P4 | --check runtime dependency checker (jq/yq/sha256sum) | P7-owned. |
| `RL-057` | `XA-0037` | P4 | .xcind.sh trust/security warning | P7-owned. |
| `RL-058` | `XA-0038` | P4 | --generate-starship --format nix | P7-owned. |
| `RL-059` | `XA-0039` | P4 | --preview resolved-command flag | P7-owned. |
| `RL-060` | `XA-0040` | P4 | Shell ${VAR}/$(cmd) expansion in file patterns | P7-owned. |
| `RL-061` | `XA-0041` | P4 | Per-file .override sibling auto-derivation | P7-owned. |
| `RL-062` | `XA-0042` | P4 | XCIND_ADDITIONAL_CONFIG_FILES includes | P7-owned. |
| `RL-063` | `SA-0001` | P5 | Options-based targeting by name (--workspace/--app from anywhere; ADR-0011) | P7-owned. Also file an Xcind ADR recording the deliberate deviation from Scind ADR-0011 (currently implicit) — PROCESS row PROC-0002. |
| `RL-064` | `SA-0002` | P5 | *_HOST_GATEWAY env var inside containers (extra_hosts only) — human product-call | P7-owned. Human product-call: Scind KEEPS mandating the env var (NOT overreach). Optional Xcind backlog: add environment: - XCIND_HOST_GATEWAY (value already computed). Same finding as L-0038 / RG-0001. |
| `RL-065` | `SA-0006` | P5 | Explicit primary:true designation + multi-primary validation | P7-owned. Overreach candidacy adjudicated by the apex cluster: NOT over-engineered — Scind keeps explicit primary:true and ADDS positional fallback (L-0028). Designation MECHANISM absence remains a divergence. |
| `RL-066` | `SA-0007` | P5 | Generated manifest (computed workspace topology view) | P7-owned. |
| `RL-067` | `SA-0008` | P5 | Flavors (named variant configs + state.yaml active-flavor + flavor cmds) | P7-owned. Soft P6 note (PROCESS row PROC-0001): add an explicit 'flavors dropped' sentence to Xcind ADR-0005. Flavors coupled to persistent active-flavor state; see ESCALATE L-0039. |
| `RL-068` | `SA-0009` | P5 | port_inventory + assigned/unavailable/released status model | P7-owned. |
| `RL-069` | `SA-0010` | P5 | Workspace state machine + explicit generate/destroy | P7-owned. |
| `RL-070` | `SA-0011` | P5 | port scan / port gc | P7-owned. |
| `RL-071` | `SA-0013` | P5 | Workspace-wide up/down/restart orchestration | P7-owned but flagged Xcind-backlog reconsider (see XB-0007): xcind-workspace status already enumerates apps, so a thin up/down loop is a natural high-value addition. |
| `RL-072` | `SA-0014` | P5 | workspace clone (repo URLs) | P7-owned. |
| `RL-073` | `SA-0015` | P5 | Port-type plugins + tcp/SNI routing (future in both) | P7-owned. |
| `RL-074` | `SA-0017` | P5 | Shared volumes (future in both) | P7-owned. |
| `RL-075` | `SA-0019` | P5 | Port/service visibility (public/protected) — test-enforced omission | P7-owned. |
| `RL-076` | `SA-0020` | P5 | Customizable %VAR% template surface | P7-owned. |
| `RL-077` | `SA-0023` | P5 | Explicit workspace generate command | P7-owned. |
| `RL-078` | `SA-0024` | P5 | workspace destroy command | P7-owned. |
| `RL-079` | `SA-0025` | P5 | Scind reference appendices (doc-presentation) — human product-call | P7-owned. Human product-call: leave Scind appendices as-is; Xcind demonstrates usage in its Diátaxis docs/. Error/exit-code catalog tracked as UX polish under SA-0021. |

## 5. Xcind backlog

| Ledger ID | Join key | Pri | Item | Target |
|-----------|----------|-----|------|--------|
| `RL-080` | `SA-0003` | P1 | Completion FUNCTION behavior untested (latent bug) | xcind: test/ (behavioral completion tests) |
| `RL-081` | `SA-0004` | P3 | Fish shell support | xcind: lib/xcind/ + bin/xcind-config |
| `RL-082` | `SA-0012` | P3 | port assign (manual host-port pin) | xcind: bin/xcind-proxy |
| `RL-083` | `SA-0021` | P3 | Context-detection UX (feedback, exit code 5, hints) | xcind: bin/ context-detection error paths |
| `RL-084` | `SA-0022` | P3 | Universal --yaml/--quiet/--verbose/--color flags | xcind: bin/ arg parsers |
| `RL-085` | `SA-0016` | P3 | Application dependencies (depends_on) — shared future work | xcind: roadmap / future |
| `RL-086` | `SA-0018` | P3 | Health checks — shared future work | xcind: roadmap / future |

> `RL-080` (SA-0003, completion-function tests) is a **⚠️ latent-bug** item — highest-priority backlog work.

## 6. Process / doc-maintenance

| Ledger ID | Join key | Action item | Lands in |
|-----------|----------|-------------|----------|
| `RL-087` | `L-0029` | Read-only paths resolve config without writing shared state; config-key deprecation path | Scind build guidance (P6) — no canon change |
| `RL-088` | `L-0030` | Generator subcommands: uniform stdout/file semantics, named for output | Scind CLI-ergonomics guideline (P6) — no canon change |
| `RL-089` | `L-0031` | Two-track docs (user Diátaxis + engineering LDS) once a real tool exists | Scind documentation process (P6) — no canon change |
| `RL-090` | `L-0032` | CLI argument robustness (missing values, surplus positionals, explicit-vs-auto failure) | Xcind maintenance / P6 — no canon change |
| `RL-091` | `L-0033` | Pervasive eng-doc↔code drift → periodic source-review sweep | P6 maintenance procedure (cross-project-sync.md) |
| `RL-092` | `PROC-0001` | Make the flavors deferral explicit in Xcind ADR-0005 | xcind: engineering/decisions/0005-structure-vs-state-separation.md |
| `RL-093` | `PROC-0002` | File an Xcind ADR recording the ADR-0011 (targeting) deviation | xcind: engineering/decisions/ (new ADR) |
| `RL-094` | `PROC-0003` | Drop behaviors/ from both projects (docs-process) | xcind + scind: engineering/behaviors/ (both) |

## 7. Escalations — human product call

Not filed as divergences (§2a: ambiguity routes up). Both readings are captured in the P3/P4/P5 artifacts.

| Ledger ID | Join key | Plan | Open question | Route | Note |
|-----------|----------|------|---------------|-------|------|
| `RL-095` | `L-0034` | P3 | Per-export single tls key vs Scind protocol+visibility; visibility labels dropped | human product call → P6 + P5 | Visibility-label half = same as RG-0002; routes to P5 as Scind-ahead. tls-key half folds with L-0008. |
| `RL-096` | `L-0035` | P3 | Workspace-wide generated-manifest: necessary orchestrator view or redundant with --json? | human product call → P6 |  |
| `RL-097` | `L-0036` | P3 | Adopt Xcind's named extensible generation hook pipeline? | human product call → P4 (forward-port) | Related divergences XA-0031 (phase vocab), XA-0019 (extensibility ESCALATE). |
| `RL-098` | `L-0037` | P3 | App-side self-declared workspace membership inverts workspace-owns-apps model | human product call → P6 |  |
| `RL-099` | `L-0038` | P3 | Scind *_HOST_GATEWAY container env mandate UNMET in Xcind (extra_hosts only) | human product call → P5 | Same finding as SA-0002 / RG-0001 (host-gateway env). Human product-call: Scind keeps mandating; Xcind absence accepted → P7 (SA-0002). |
| `RL-100` | `L-0039` | P3 | Flavors dropped by design — mechanism coupled to persistent state | human product call → P6/P5 |  |
| `RL-101` | `XA-0019` | P4 | Extensible generation hook lifecycle (plugin/hook-dir contract) | human product call |  |
| `RL-102` | `XA-0020` | P4 | Content-addressed (SHA-of-inputs) generation cache | human product call |  |
| `RL-103` | `XA-0021` | P4 | Workspaceless standalone app mode | human product call |  |
| `RL-104` | `XA-0022` | P4 | Late-bind workspace self-declaration (app names its workspace) | human product call | Depends on XA-0021. Related to ESCALATE L-0037 (app-side workspace membership). |
| `RL-105` | `XA-0023` | P4 | XCIND_APP_ROOT env root-pin escape hatch | human product call | Likely already covered by Scind ADR-0011 targeting; low priority. |
| `RL-106` | `XA-0024` | P4 | On-demand proxy auto-start on app up + opt-out | human product call |  |
| `RL-107` | `XA-0025` | P4 | Apex reporting mechanics — HAND TO P3 | human product call | Folded into the apex cluster (L-0013/L-0018/L-0028) so apex is not decided twice. |
| `RL-108` | `XA-0026` | P4 | proxy init accepts full config as flags (interface question) | human product call |  |
| `RL-109` | `XA-0027` | P4 | config doctor generation/routing diagnostic | human product call |  |
| `RL-110` | `XA-0028` | P4 | Zero-config default compose/env candidate resolution | human product call |  |
| `RL-111` | `XA-0029` | P4 | XCIND_TOOLS declarative host→container tool shortcuts | human product call |  |
| `RL-112` | `SA-0026` | P5 | scind-compose shell function + compose-prefix — does Scind still need it? | human product call → P6/Scind design | Human product-call. Related PROMOTE XA-0014 (wrapper generation). |
| `RL-113` | `RG-0001` | P4 | *_HOST_GATEWAY env injection (Xcind behind Scind) | human product call → P5/P3 | Recorded for completeness; not a distinct action. |
| `RL-114` | `RG-0002` | P4 | Per-export/port visibility labels (Xcind behind Scind) | human product call → P5/P3 | Recorded for completeness; not a distinct action. |

## 8. ADR numbering & cross-referencing policy

`RL-115` records the decision: **Option A — a topic-keyed cross-reference table, no renumbering**, written as **Xcind [ADR-0021](../../decisions/0021-cross-repo-adr-cross-referencing.md)**. Divergence-encoding ADRs are marked and pointed at the P7 registry. Rationale and the rejected alternatives are in the ADR.

## 9. Done-criteria (plan Part A)

- [x] Every P3/P4/P5 action item appears with a status (115 rows: 39 P3 + 46 P4 incl. 2 reverse gaps + 26 P5 + 4 derived/policy).
- [x] ADR numbering/cross-ref policy decided and written as an ADR (Xcind ADR-0021, `RL-115`).
- [x] All `CANON-CHANGE`/`PROMOTE`/`CANON-OVERREACH` items fully specified; applied to Scind or explicitly deferred with reason (see `status` + per-row notes; `scind_pr` on applied rows).
- [x] Divergences referenced by origin ID and left to P7; no `divergence/` writes here.

---

*Generated for P6. 115 rows. Re-render from the JSON after any status flip.*
