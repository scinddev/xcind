# Round 2 — Reconciliation Ledger (post-9f975e4 feature wave)

**Status**: **Closed** 2026-08-07 — all Scind-affecting rows APPLIED in [scinddev/scind#8](https://github.com/scinddev/scind/pull/8) (PR open at close; merge pending, see the round-2 `sync-baseline.json` entry).
**Date**: 2026-08-07
**Procedure**: [`engineering/maintenance/cross-project-sync.md`](../../maintenance/cross-project-sync.md) (Steps 3–5 output).
**Scope**: Xcind PRs [#82](https://github.com/scinddev/xcind/pull/82) `07de51f`, [#83](https://github.com/scinddev/xcind/pull/83) `5b4b9f4`, [#85](https://github.com/scinddev/xcind/pull/85) `63223d3`, [#86](https://github.com/scinddev/xcind/pull/86) `d9d9a8f`, [#87](https://github.com/scinddev/xcind/pull/87) `a5f9494`, [#88](https://github.com/scinddev/xcind/pull/88) `92b0ea5` — round 1's `known_excluded` set — triaged against Scind canon at `ca156eb` (unchanged since round 1 closed).
**Step-1 gate**: LDS self-sync audit `ce0da4c` (docs-only, scoped to exactly these PRs) + `make check` green (137/137). No areas excluded.
**Machine companion**: [`reconciliation-ledger-round-2.json`](./reconciliation-ledger-round-2.json) (same rows, `meta` + `rows[]`, P6 field names and vocabulary).

`RL-` IDs continue the **global sequence** from the closed [P6 ledger](./reconciliation-ledger.md) (`RL-001..RL-115`); this round allocates `RL-116..RL-142`. Join keys are round-2 triage-finding IDs (`F2-*`).

### Directionality (global-context §2)

> Scind is canon. Xcind's lessons **upgrade** the canon. Divergence is the claim that must be **earned**; ambiguity routes to CANON-CHANGE or ESCALATE, never silently to DIVERGENCE.

## 1. Summary

| Action type | Count | Destination / status |
|-------------|------:|----------------------|
| **PROMOTE** | 17 | Add to Scind canon (+ ADR-0017) → Scind PR |
| **CANON-CHANGE** | 1 | Edit Scind canon → Scind PR |
| **CANON-CONFIRM** | 3 | Annotate Scind (low priority) / no edit |
| **DIVERGENCE** | 2 | Already covered by P7 registry (no new entries) |
| **DELIBERATELY-DEFERRED** | 1 | Already covered by P7 registry (0036) |
| **REGISTRY-UPDATE** | 1 | P7 registry status change (Step 5 outcome) |
| **NO-DELTA** | 1 | Triaged; no impact |
| **PROCESS** | 1 | Sync-artifact bookkeeping |
| **Total** | **27** | |

Notable: **no new divergences were earned this round** — every DIVERGENCE row maps to an existing registry entry, and one standing divergence (0034) closes by convergence.

## 2. Rows

| ID | Join key | Action | P | Status | Title |
|----|----------|--------|---|--------|-------|
| RL-116 | `F2-external-proxy-mode-capability` | PROMOTE | P1 | APPLIED | External proxy mode (managed|external) as canon + new Scind ADR-0017 |
| RL-117 | `F2-proxy-mode-config-key` | PROMOTE | P1 | APPLIED | proxy.mode config key, reconciled with proxy.auto_start |
| RL-118 | `F2-configurable-proxy-network-name` | PROMOTE | P1 | APPLIED | Configurable proxy.network (default scind-proxy) |
| RL-119 | `F2-configurable-entrypoint-names` | PROMOTE | P1 | APPLIED | Configurable entrypoint names (proxy.http_entrypoint/https_entrypoint) |
| RL-120 | `F2-tls-certresolver-router-label` | PROMOTE | P1 | APPLIED | proxy.certresolver + tls.certresolver router label (first ACME path in canon) |
| RL-121 | `F2-external-mode-tls-division-of-labor` | PROMOTE | P1 | APPLIED | External-mode TLS division of labor; tls.mode custom x external = hard error |
| RL-122 | `F2-external-mode-command-semantics` | PROMOTE | P2 | APPLIED | Command-behavior matrix under mode: external (refusal over silent no-op) |
| RL-123 | `F2-down-migration-escape-hatch` | PROMOTE | P2 | APPLIED | Two-predicate down escape hatch for managed-to-external migration |
| RL-124 | `F2-external-init-managed-artifact-cleanup` | PROMOTE | P2 | APPLIED | External init: managed-artifact cleanup + compose-file retention rule |
| RL-125 | `F2-external-mode-network-topology-guidance` | PROMOTE | P2 | APPLIED | Network topology guidance (join host proxy's network vs connect ours) |
| RL-126 | `F2-external-proxy-known-caveats` | PROMOTE | P2 | APPLIED | Known caveats: entrypoint-level redirect shadowing; providers.docker.constraints |
| RL-127 | `F2-redirect-middleware-permanent-flag` | PROMOTE | P2 | APPLIED | redirectscheme.permanent=true (301, not Traefik's default 302) |
| RL-128 | `F2-noop-middleware` | CANON-CONFIRM | P4 | RESOLVED | noop@internal pin + per-service middleware emission already in canon |
| RL-129 | `F2-proxy-status-doctor-mode` | PROMOTE | P2 | APPLIED | proxy status + doctor must report mode; network check replaces Traefik check externally |
| RL-130 | `F2-external-mode-dispose-semantics` | PROMOTE | P2 | APPLIED | External-mode teardown must never remove the shared proxy network |
| RL-131 | `F2-proxy-level-dispose-missing` | PROMOTE | P1 | APPLIED | scind proxy destroy [--purge] [--force] (canon has no proxy teardown verb) |
| RL-132 | `F2-workspace-dispose-partial-failure` | PROMOTE | P2 | APPLIED | workspace destroy failure semantics (abort before state removal) |
| RL-133 | `F2-app-level-dispose-matches` | CANON-CONFIRM | P4 | RESOLVED | xcind-application dispose converges with canonical scind app remove |
| RL-134 | `F2-rm-flag-shape` | DIVERGENCE | P5 | RESOLVED | Directory-removal flag shape: --yes/--rm split vs --force/--keep-apps pair |
| RL-135 | `F2-0034-flip` | REGISTRY-UPDATE | P2 | DONE | Close divergence 0034: Xcind converged via dispose (PR #86) |
| RL-136 | `F2-single-value-resolved-config-lookup` | PROMOTE | P2 | APPLIED | scind app get <path>: single-value resolved-config lookup |
| RL-137 | `F2-resolve-help-discoverability` | NO-DELTA | P5 | RESOLVED | resolve-specific --help (Xcind PR #87): no canon impact |
| RL-138 | `F2-88-resolved-cache-refresh-ordering` | CANON-CONFIRM | P4 | APPLIED | PR #88 re-confirms the generation-ordering rule canon already states |
| RL-139 | `F2-82-yq-already-covered` | DIVERGENCE | P5 | RESOLVED | kislyuk/yq compatibility (PR #82) fully covered by divergence 0001 |
| RL-140 | `F2-dashboard-not-an-entrypoint` | CANON-CHANGE | P3 | APPLIED | Dashboard is not an entrypoint; fix blanket web-redirect wording |
| RL-141 | `F2-proxy-init-flag-surface` | DELIBERATELY-DEFERRED | P5 | RESOLVED | proxy init flag surface for the five new keys: covered by divergence 0036 |
| RL-142 | `F2-artifacts-refresh` | PROCESS | P1 | DONE | Round-2 artifact refresh: map + ADR table + Step 5 stamps + watermark |

## 3. Row detail

### RL-116 — External proxy mode (managed|external) as canon + new Scind ADR-0017

**Join key**: `F2-external-proxy-mode-capability` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/decisions/0017-external-proxy-mode.md (new) + decisions/README.md + decisions/0008 back-link

New ADR modeled on Xcind ADR-0022: proxy.mode managed|external; external never starts/stops/configures a proxy; apps join a configured shared network with labels retargeted via proxy.network/http_entrypoint/https_entrypoint/certresolver; single label-generation code path; two network topologies with platform-recreation caveat. Credits Xcind PR #83 as validating implementation.

*Headline of round 2. Canon already names the externally-managed-proxy case (auto_start:false) but cannot deliver it; gap is three hardcoded values wide.*

### RL-117 — proxy.mode config key, reconciled with proxy.auto_start

**Join key**: `F2-proxy-mode-config-key` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/reference/configuration.md + specs/configuration-schemas.md + specs/workspace-lifecycle.md

Add proxy.mode to proxy.yaml schema/table. external supersedes auto_start (short-circuits before it is read); network-ensure failure is a hard error in external mode. Reframe the auto_start:false opt-out paragraph against the new mode.

### RL-118 — Configurable proxy.network (default scind-proxy)

**Join key**: `F2-configurable-proxy-network-name` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/reference/configuration.md + specs/proxy-infrastructure.md + specs/docker-labels.md

One config key drives traefik.docker.network label, providers.docker.network, and the compose networks block; default reproduces current behavior byte-for-byte.

### RL-119 — Configurable entrypoint names (proxy.http_entrypoint/https_entrypoint)

**Join key**: `F2-configurable-entrypoint-names` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/reference/configuration.md + specs/proxy-infrastructure.md + specs/docker-labels.md + specs/port-types.md

Entrypoint NAMES become config (defaults web/websecure) driving both generated static config and router labels; ports were already configurable.

### RL-120 — proxy.certresolver + tls.certresolver router label (first ACME path in canon)

**Join key**: `F2-tls-certresolver-router-label` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/specs/docker-labels.md + reference/configuration.md + specs/proxy-infrastructure.md

When proxy.certresolver is set, append tls.certresolver to every HTTPS router (per-export and apex) in BOTH modes; distinguish which-routers-exist (tls.mode) from who-provisions-certs (resolver).

### RL-121 — External-mode TLS division of labor; tls.mode custom x external = hard error

**Join key**: `F2-external-mode-tls-division-of-labor` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/specs/proxy-infrastructure.md + specs/configuration-schemas.md + decisions/0009 cross-ref

External mode skips the whole cert cascade (host proxy terminates TLS); router emission rules unchanged; custom+external MUST be rejected at validation/init.

### RL-122 — Command-behavior matrix under mode: external (refusal over silent no-op)

**Join key**: `F2-external-mode-command-semantics` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/reference/cli.md (Proxy Commands) + specs/proxy-infrastructure.md

init/up succeed with redefined contracts; up --force, down, restart, logs refuse with exit 1; principle: refusal beats silent no-op for verbs promising actions on a proxy Scind does not own.

### RL-123 — Two-predicate down escape hatch for managed-to-external migration

**Join key**: `F2-down-migration-escape-hatch` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/reference/cli.md (proxy down) + specs/proxy-infrastructure.md

down still stops a leftover managed proxy iff scind.component=proxy container is running AND the generated managed compose file exists; both predicates load-bearing.

### RL-124 — External init: managed-artifact cleanup + compose-file retention rule

**Join key**: `F2-external-init-managed-artifact-cleanup` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/specs/proxy-infrastructure.md + reference/cli.md (proxy init)

Remove stale static config + dynamic/tls.yaml; keep certs/; remove compose file ONLY when no managed proxy container is running (else it is the only stopping handle) + warn. Coolify-style example.

### RL-125 — Network topology guidance (join host proxy's network vs connect ours)

**Join key**: `F2-external-mode-network-topology-guidance` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/specs/proxy-infrastructure.md + new ADR-0017

RECOMMENDED: point proxy.network at the host proxy's existing network (external:true overrides; host proxy container untouched). ALTERNATE: docker network connect, re-applied on every container recreation (platform hosts recreate on upgrade). Absent network still created + loud warning.

### RL-126 — Known caveats: entrypoint-level redirect shadowing; providers.docker.constraints

**Join key**: `F2-external-proxy-known-caveats` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/specs/proxy-infrastructure.md

Host Force-HTTPS shadows emitted HTTP routers (harmless); constrained host providers need the constraint label added manually. Converts two silent-mystery support cases into a paragraph.

### RL-127 — redirectscheme.permanent=true (301, not Traefik's default 302)

**Join key**: `F2-redirect-middleware-permanent-flag` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/specs/docker-labels.md + specs/proxy-infrastructure.md

Add the permanent=true label to the shared redirect middleware definition; tls: require is a stable policy, permanent redirect is the correct, cacheable semantic.

### RL-128 — noop@internal pin + per-service middleware emission already in canon

**Join key**: `F2-noop-middleware` · **Action**: CANON-CONFIRM · **Priority**: P4 · **Status**: RESOLVED · **Merged with**: RL-127
**Target**: scind: engineering/specs/docker-labels.md (table completeness only)

Xcind ce0da4c caught its own docs up to canon; Scind already specifies both with Validated-by-Xcind annotations. Only cosmetic table completeness, riding along with RL-127.

*No standalone edit.*

### RL-129 — proxy status + doctor must report mode; network check replaces Traefik check externally

**Join key**: `F2-proxy-status-doctor-mode` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/reference/cli.md (proxy status, doctor)

Mode line in both outputs + external sample; doctor: 'Proxy network: present' is the hard diagnostic under external (overrides declare it external:true), Traefik-running check dropped, detected-container line informational.

### RL-130 — External-mode teardown must never remove the shared proxy network

**Join key**: `F2-external-mode-dispose-semantics` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED · **Merged with**: RL-131
**Target**: scind: engineering/reference/cli.md (proxy destroy) + specs/proxy-infrastructure.md

Teardown may stop a retained managed proxy via the old compose file (state kept for retry on failure) and removes generated state, but never the configured shared network (foreign-owned, shared with unrelated workloads).

*Merged into the RL-131 proxy destroy spec.*

### RL-131 — scind proxy destroy [--purge] [--force] (canon has no proxy teardown verb)

**Join key**: `F2-proxy-level-dispose-missing` · **Action**: PROMOTE · **Priority**: P1 · **Status**: APPLIED
**Target**: scind: engineering/reference/cli.md + specs/proxy-infrastructure.md + specs/state-management.md

Stop proxy, remove generated state incl. the assigned-port inventory (call out: every workspace loses port assignments), config only with --purge; add 'proxy destroyed' as a third port-release trigger in state-management.md. Credits Xcind PR #86.

### RL-132 — workspace destroy failure semantics (abort before state removal)

**Join key**: `F2-workspace-dispose-partial-failure` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/specs/workspace-lifecycle.md (Destroy Sequence) + reference/cli.md

If any app teardown fails, destroy aborts before removing .generated/, workspace.yaml, ports, registry entry; already-stopped apps stay stopped; retry is safe.

### RL-133 — xcind-application dispose converges with canonical scind app remove

**Join key**: `F2-app-level-dispose-matches` · **Action**: CANON-CONFIRM · **Priority**: P4 · **Status**: RESOLVED
**Target**: scind: engineering/reference/cli.md (no edit)

Functionally equivalent sequence; Xcind implemented what canon specified. No edit.

### RL-134 — Directory-removal flag shape: --yes/--rm split vs --force/--keep-apps pair

**Join key**: `F2-rm-flag-shape` · **Action**: DIVERGENCE · **Priority**: P5 · **Status**: RESOLVED
**Target**: xcind: noted in divergence 0034 resolution note (no new registry entry)

Earned sentence: Scind's --force/--keep-apps already reaches the same two non-interactive outcomes as Xcind's --yes/--rm split, so there is no capability gap to close. Naming-level; beneath registry granularity.

*Recorded inside 0034's closure note rather than minting a registry entry.*

### RL-135 — Close divergence 0034: Xcind converged via dispose (PR #86)

**Join key**: `F2-0034-flip` · **Action**: REGISTRY-UPDATE · **Priority**: P2 · **Status**: DONE
**Target**: xcind: engineering/sync/divergence/0034-explicit-workspace-destroy.md + registry.json

Premise 'Xcind has no destroy verb' is now false: xcind-workspace dispose does the same down+release-ports+remove-generated+deregister cascade as scind workspace destroy. Not a canon change (canon validated); flip Active -> Resolved with convergence note; re-check 0026's destroy-facet wording next round.

*Both the dispose triage and the Step 5 re-audit reached the same conclusion independently.*

### RL-136 — scind app get <path>: single-value resolved-config lookup

**Join key**: `F2-single-value-resolved-config-lookup` · **Action**: PROMOTE · **Priority**: P2 · **Status**: APPLIED
**Target**: scind: engineering/reference/cli.md (new subsection after app exports + JSON-contract cross-link)

Adopt the path grammar (dotted segments, quoted keys, [N] indices) and exit-code contract; NOT the --cached/--hooks-ttl cache mechanics (Xcind-cache-specific, see divergence 0020). Credits Xcind PR #85.

### RL-137 — resolve-specific --help (Xcind PR #87): no canon impact

**Join key**: `F2-resolve-help-discoverability` · **Action**: NO-DELTA · **Priority**: P5 · **Status**: RESOLVED
**Target**: none

Bespoke help text exists only because Xcind hand-rolls arg parsing; a cobra-style CLI generates per-subcommand help without static-text drift risk. Scind should not adopt.

### RL-138 — PR #88 re-confirms the generation-ordering rule canon already states

**Join key**: `F2-88-resolved-cache-refresh-ordering` · **Action**: CANON-CONFIRM · **Priority**: P4 · **Status**: APPLIED
**Target**: scind: engineering/specs/workspace-lifecycle.md (Generation Logic step 10, one clause)

Canon step 10 already mandates live-state-derived resolution before artifact writes, annotated Validated-by-Xcind. PR #88 is a second independent confirmation; append one clause, no new normative content.

### RL-139 — kislyuk/yq compatibility (PR #82) fully covered by divergence 0001

**Join key**: `F2-82-yq-already-covered` · **Action**: DIVERGENCE · **Priority**: P5 · **Status**: RESOLVED
**Target**: none

Bash-runtime portability concession; Scind's Go stack has no shelled-out yq. Covered by 0001 (Bash vs Go) + 0008 (runtime dep checker). No action.

### RL-140 — Dashboard is not an entrypoint; fix blanket web-redirect wording

**Join key**: `F2-dashboard-not-an-entrypoint` · **Action**: CANON-CHANGE · **Priority**: P3 · **Status**: APPLIED
**Target**: scind: engineering/specs/proxy-infrastructure.md (Entry Points table) + reference/configuration.md examples

Remove the dashboard|8080 entrypoint row (dashboard rides Traefik's insecure-API listener via api block + port publish, no entryPoints block); note dashboard inert under external mode; fix 'redirects to HTTPS' to per-export tls: require only.

### RL-141 — proxy init flag surface for the five new keys: covered by divergence 0036

**Join key**: `F2-proxy-init-flag-surface` · **Action**: DELIBERATELY-DEFERRED · **Priority**: P5 · **Status**: RESOLVED
**Target**: none

Xcind exposes the keys as init flags because its sourceable-shell config has no structured editor (registry 0036, accepted 2026-08). Scind routes them through scind config set proxy.*; only the schema keys land (RL-117..RL-120).

### RL-142 — Round-2 artifact refresh: map + ADR table + Step 5 stamps + watermark

**Join key**: `F2-artifacts-refresh` · **Action**: PROCESS · **Priority**: P1 · **Status**: DONE
**Target**: xcind: engineering/sync/artifacts/* + sync/divergence/registry.json + engineering/archive/ report

Update 12 materially-changed correspondence rows, add 3 (Xcind ADRs 0021/0022; handoff row if absent), flip the targeting ADR row SCIND-ONLY -> DIVERGED-DECISION (Scind 0011 vs Xcind 0023), stamp 22 re-audited divergences, append the round-2 baseline entry.
