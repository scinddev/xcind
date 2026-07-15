# P2 — Correspondence Map (Scind ↔ Xcind "Rosetta Stone")

**Status**: COMPLETE. All six LDS layers + `maintenance/` reconciled across both
trees. Every file in the comparison surface (Scind `docs/` 82 files, Xcind
`engineering/` 83 files — 165 total) appears in exactly one row below.
**Date**: 2026-07-15   **Branch**: `sync/p1-self-sync`
**Inputs**: [`00-global-context.md`](../00-global-context.md),
[`02-correspondence-map.md`](../02-correspondence-map.md),
[`p1-self-sync-report.md`](./p1-self-sync-report.md).
**Method**: six parallel subagents, one per LDS layer across both repos, plus a
coordinating pass for `maintenance/` and reconciliation. Scind treated read-only.

**Coverage status by layer** (all done):

| Layer | Status | Rows |
|-------|--------|------|
| decisions | ✅ done | 23 (incl. 2 new Xcind ADRs 0019/0020) |
| specs (+ appendices) | ✅ done | 23 |
| behaviors | ✅ done | 14 |
| reference (+ appendices) | ✅ done | 8 |
| architecture + product + root | ✅ done | 9 |
| implementation (+ appendices) | ✅ done | 25 |
| maintenance (reserved for P6) | ✅ mapped | 12 |
| **Total** | | **114 rows / 165 files** |

**Relationship-code counts (file-level):**

| Rel | Count | Feeds |
|-----|------:|-------|
| `MATCH` | 19 | — |
| `PARTIAL` | 27 | P3/P4/P5 (per row) |
| `DIVERGED` | 3 | P3 |
| `SCIND-ONLY` | 31 | P5 (12) / P7 permanent Go/Bash + architectural divergence (19) |
| `XCIND-ONLY` | 32 | P4 (mostly) / P6 (maintenance + ADR-0019) |
| `RENUMBERED` | 2 | P6 |

> Reconciliation: 51 paired rows (both sides present) × 2 files = 102, plus 31
> `SCIND-ONLY` + 32 `XCIND-ONLY` single files = **165 files** = 82 + 83. ✔

---

## 1. File correspondence matrix

Paths are repo-relative (Scind → `docs/…`, Xcind → `engineering/…`). "Feeds"
tags the downstream plan each non-`MATCH` row hands to.

### Root / documentation guide

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/DOCUMENTATION-GUIDE.md` | `engineering/DOCUMENTATION-GUIDE.md` | PARTIAL | P3/P4/P5 | Same LDS framework/taxonomy; Xcind adds two-track (Diátaxis + LDS) split, drops Scind's migration/confidence classification & Layer-6 detail. |
| `docs/README.md` | `engineering/README.md` | PARTIAL | P3 | Both layer-index landing pages; Xcind reframes as the "engineering track" implementing Scind + adds Behaviors/Maintenance rows. |

### architecture/

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/architecture/README.md` | `engineering/architecture/README.md` | MATCH | — | Trivial one-item index; identical. |
| `docs/architecture/overview.md` | `engineering/architecture/overview.md` | PARTIAL | P3/P4/P5 | Design concepts (workspace, pure overlay, two-layer net, Traefik) match; component architecture diverges Go-vs-Bash (Generate Engine + state files vs three scripts + hook pipeline + SHA cache). |

### product/

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/product/README.md` | `engineering/product/README.md` | MATCH | — | Same index; Xcind adds "implements Scind" note. |
| `docs/product/comparison.md` | `engineering/product/comparison.md` | PARTIAL | P3/P4 | Xcind adds Xcind + Scind columns and a whole "Xcind vs Scind" positioning section (lightweight Bash impl of Go/YAML Scind). |
| `docs/product/glossary.md` | `engineering/product/glossary.md` | PARTIAL | P3 | Core terms match; **term drift**: Scind's Exported Service/Service Contract/Flavor/Manifest/Visibility/Port Type gone, replaced by Xcind's Export/Hook/App Root/Variable Expansion + redefined Override File. |
| `docs/product/roadmap.md` | `engineering/product/roadmap.md` | PARTIAL | P3/P5 | Both forward-looking; Xcind is a strict subset (drops Port Type Plugins + Shared Volumes). |
| `docs/product/vision.md` | `engineering/product/vision.md` | PARTIAL | P3 | Same problem/gap; Scind is a formal PRD (orchestration system) vs Xcind "slim docker compose wrapper" — narrowed scope. |

### decisions/  (see full ADR reconciliation in §2)

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/decisions/0000-template.md` | `engineering/decisions/0000-template.md` | MATCH | — | Identical body; Scind keeps a trailing HTML comment. |
| `docs/decisions/README.md` | `engineering/decisions/README.md` | PARTIAL | — | Structural index; Xcind lists 0001–0020 + Scind-origin note. |
| `docs/decisions/0001-docker-compose-project-name-isolation.md` | `engineering/decisions/0001-…` | MATCH | — | Same decision; Xcind adds a worktree-instance note (subject of 0019). |
| `docs/decisions/0002-two-layer-networking.md` | `engineering/decisions/0002-…` | MATCH | — | Identical but proxy-net prefix. |
| `docs/decisions/0003-pure-overlay-design.md` | `engineering/decisions/0003-…` | MATCH | — | Identical. |
| `docs/decisions/0004-convention-based-naming.md` | `engineering/decisions/0004-…` | MATCH | — | Same; Xcind adds additive URL templates. |
| `docs/decisions/0005-structure-vs-state-separation.md` | `engineering/decisions/0005-…` | MATCH | — | Same; state mechanism differs (YAML vs `.xcind.sh` + cache). |
| `docs/decisions/0006-three-configuration-schemas.md` | `engineering/decisions/0006-…` | MATCH | — | Same three-tier; Bash vs YAML. |
| `docs/decisions/0007-port-type-system.md` | `engineering/decisions/0007-…` | MATCH | — | Same proxied/assigned; Xcind's positional-primary rule is the root of the apex divergence. |
| `docs/decisions/0008-traefik-reverse-proxy.md` | `engineering/decisions/0008-…` | MATCH | — | Identical. |
| `docs/decisions/0009-flexible-tls-configuration.md` | `engineering/decisions/0009-…` | MATCH | — | Same modes; Xcind adds per-export `tls`; corrected later by 0016. |
| `docs/decisions/0010-up-down-command-semantics.md` | `engineering/decisions/0010-…` | MATCH | — | Identical. |
| `docs/decisions/0011-options-based-targeting.md` | — | SCIND-ONLY | P5 | No Xcind ADR for `--workspace`/`--app` targeting (Xcind uses subcommands + DIR). |
| `docs/decisions/0012-layered-documentation-system.md` | `engineering/decisions/0011-layered-documentation-system.md` | RENUMBERED | P6 | Same LDS decision, off-by-one. |
| `docs/decisions/0013-apex-url-primary-designation.md` | `engineering/decisions/0017-apex-url-reporting.md` | **DIVERGED** | P3 | **Conflicting decision** (see §2 verdict): Scind mandates `primary: true` and explicitly rejects positional; Xcind is positional (0007) + 0017 adds only reporting. |
| `docs/decisions/0014-host-docker-internal-normalization.md` | `engineering/decisions/0013-host-docker-internal-normalization.md` | RENUMBERED | P6 | Same decision, different number. |
| — | `engineering/decisions/0012-unified-generate-flag-semantics.md` | XCIND-ONLY | P4 | CLI `--generate-*` unification. |
| — | `engineering/decisions/0014-two-track-documentation.md` | XCIND-ONLY | P4 | Diátaxis user + LDS eng track. |
| — | `engineering/decisions/0015-application-export-introspection.md` | XCIND-ONLY | P4 | `ports/urls/exports` + `--json` contract (shipped). |
| — | `engineering/decisions/0016-proxy-domain-wildcard-constraint.md` | XCIND-ONLY | P4/P3 | Corrects wildcard-TLS flaw in shared 0009; new default `localhost.scind.io`. |
| — | `engineering/decisions/0018-service-discovery-env-injection.md` | XCIND-ONLY | P4 | Ports a Scind spec-level design; `_HOST_PORT` is a PROMOTE candidate. |
| — | `engineering/decisions/0019-worktree-instance-isolation.md` | XCIND-ONLY | **P6/P3** | Learning is a **canon-change against Scind 0001** (one-working-copy assumption), not a divergence. |
| — | `engineering/decisions/0020-host-env-symmetry.md` | XCIND-ONLY | P4 | Opt-in host-view env file; self-flagged PROMOTE candidate. |

### specs/  (+ appendices)

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/specs/README.md` | `engineering/specs/README.md` | PARTIAL | — | Index; differs by each tree's inventory. |
| `docs/specs/configuration-schemas.md` | `engineering/specs/configuration-schemas.md` | PARTIAL | P4/P5 | Scind three YAML schemas + flavors vs Xcind three `.xcind.sh` levels + hook-pipeline table. Flavors Scind-only (P5); pipeline Xcind-ahead (P4). |
| `docs/specs/context-detection.md` | `engineering/specs/context-detection.md` | PARTIAL | P4 | Scind walks for `workspace.yaml`/`application.yaml`; Xcind walks for `.xcind.sh` + parent `XCIND_IS_WORKSPACE` + late-bind/`XCIND_APP_ROOT`. |
| `docs/specs/directory-structure.md` | `engineering/specs/directory-structure.md` | PARTIAL | P4 | Scind `.generated/*.override.yaml`; Xcind SHA-keyed `.xcind/generated/{sha}/` 8 overlays + cache + workspaceless mode. |
| `docs/specs/docker-labels.md` | `engineering/specs/docker-labels.md` | **DIVERGED** | P3/P4 | **Conflicting label schema**: Scind `.proxy.{proto}.visibility/.url` + visibility labels; Xcind `.http.url/.https.url`/preferred `.url` + `traefik.docker.network`/`.service` + redirect middleware + two-router model. Xcind ahead on routers (P4); visibility Scind-only (P3). |
| `docs/specs/environment-variables.md` | `engineering/specs/environment-variables.md` | PARTIAL | P4 | `SCIND_`→`XCIND_` + Xcind far ahead: `_HOST_PORT` (self-flagged divergence), `XCIND_HOST_ENV_FILE/_MODE`, `XCIND_INSTANCE/_AUTO`, app-env injection. |
| `docs/specs/generated-override-files.md` | `engineering/specs/generated-override-files.md` | PARTIAL | P4 | Scind monolithic override; Xcind 8 per-hook SHA overlays + caching/`.complete`/`XCIND_HOOKS_ALWAYS` contract. |
| `docs/specs/naming-conventions.md` | `engineering/specs/naming-conventions.md` | PARTIAL | P4 | Xcind folds `XCIND_INSTANCE` + workspaceless templates; Scind `primary:true` field + git-submodule strategy have no Xcind analog. |
| `docs/specs/port-types.md` | `engineering/specs/port-types.md` | PARTIAL | P4/P5 | Xcind ahead on per-export `tls` + assigned lifecycle (P4); tcp/SNI + visibility Scind-only (P5). |
| `docs/specs/proxy-infrastructure.md` | `engineering/specs/proxy-infrastructure.md` | PARTIAL | P4 | Xcind ahead: configurable ports, multi-label domain constraint (0016), layered TLS resolution, assigned-ports lifecycle. |
| `docs/specs/workspace-lifecycle.md` | `engineering/specs/workspace-lifecycle.md` | PARTIAL | P4/P5 | Scind full state machine + flavors + destroy (P5); Xcind deliberately stateless registry (P4). |
| `docs/specs/state-management.md` | — | SCIND-ONLY | P5 | Flavors, `port_inventory`, status-transition model absent from Xcind by design. |
| `docs/specs/host-gateway-resolution.md` | — | SCIND-ONLY | P5 | **Built but not re-specified** (via `xcind-host-gateway-hook`); Xcind defers to this Scind spec. Candidate gap: Scind mandates exposing `*_HOST_GATEWAY` into containers; Xcind env-var spec never mentions it. |
| `docs/specs/generated-manifest.md` | — | SCIND-ONLY | P5 | Xcind deliberately has **no manifest** (`application-lifecycle.md` says so). Candidate P7 divergence. |
| `docs/specs/shell-integration.md` | — | SCIND-ONLY | P5 | Scind `scind-compose` shell-function design; Xcind `xcind-compose` is a real binary. Candidate P7 divergence. |
| — | `engineering/specs/hook-lifecycle.md` | XCIND-ONLY | P4 | CONFIGURED/RESOLVED/GENERATE/EXECUTE hook pipeline. Built, unspecified in canon. |
| — | `engineering/specs/application-lifecycle.md` | XCIND-ONLY | P4 | Dedicated app spec + `xcind-application` subcommands. |
| `docs/specs/appendices/generated-override-files/complete-override-example.yaml` | `engineering/specs/appendices/generated-override-files/complete-proxy-example.yaml` | PARTIAL | P4 | Scind whole merged override; Xcind only the `compose.proxy.yaml` hook slice. |
| `docs/specs/appendices/proxy-infrastructure/traefik-compose.yaml` | `engineering/specs/appendices/proxy-infrastructure/traefik-compose.yaml` | PARTIAL | P4 | Xcind conditionalizes 443/certs/dashboard on TLS mode + `XCIND_PROXY_*`; Scind hard-codes. |
| `docs/specs/appendices/proxy-infrastructure/traefik-config.yaml` | `engineering/specs/appendices/proxy-infrastructure/traefik-config.yaml` | PARTIAL | P4 | Xcind TLS-conditional websecure/file-provider + conditional dashboard; Scind unconditional. |
| `docs/specs/appendices/shell-integration/bash-setup.sh` | — | SCIND-ONLY | P5 | Part of Scind-only shell-integration topic (candidate P7 divergence). |
| `docs/specs/appendices/shell-integration/fish-setup.fish` | — | SCIND-ONLY | P5 | Scind-only shell-integration topic. |
| `docs/specs/appendices/shell-integration/zsh-setup.zsh` | — | SCIND-ONLY | P5 | Scind-only shell-integration topic. |

### behaviors/

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/behaviors/README.md` | `engineering/behaviors/README.md` | PARTIAL | — | Same index/template; Xcind runs via `make test` (shell suites) vs Scind cucumber-js. |
| `docs/behaviors/proxy/apex-routing.feature` | `engineering/behaviors/proxy/apex-routing.feature` | **DIVERGED** | P3/P4/P5 | Conflicting primary-selection (mirrors ADR 0013/0017): Scind explicit-primary "no primary → no apex" vs Xcind positional "first proxy export always gets apex" + opt-out + workspaceless apex. |
| `docs/behaviors/exported-services/primary-designation.feature` | — | SCIND-ONLY | P5 | Designation mechanism (explicit `primary:true`, multi-primary validation, assigned-port apex alias, `SCIND_*_APEX_*` env) has no Xcind counterpart. |
| — | `engineering/behaviors/proxy/hostname-generation.feature` | XCIND-ONLY | P4 | Hostname derivation + edge cases. |
| — | `engineering/behaviors/proxy/traefik-labels.feature` | XCIND-ONLY | P4 | Label/router generation incl. TLS modes. |
| — | `engineering/behaviors/workspace/network-aliases.feature` | XCIND-ONLY | P4 | Workspace service aliases, `dev-internal` network. |
| — | `engineering/behaviors/workspace/self-declaration.feature` | XCIND-ONLY | P4 | `XCIND_WORKSPACE` late-bind. |
| — | `engineering/behaviors/workspace/workspace-mode.feature` | XCIND-ONLY | P4 | Parent `.xcind.sh` workspace discovery. |
| — | `engineering/behaviors/config-resolution/app-env-injection.feature` | XCIND-ONLY | P4 | Inject app env files into all services. |
| — | `engineering/behaviors/config-resolution/compose-file-defaults.feature` | XCIND-ONLY | P4 | Default compose/env candidates + `XCIND_ENV_FILES` back-compat. |
| — | `engineering/behaviors/config-resolution/override-files.feature` | XCIND-ONLY | P4 | Override derivation + auto-source `.xcind.override.sh`. |
| — | `engineering/behaviors/config-resolution/project-naming.feature` | XCIND-ONLY | P4 | Compose project-name hook (relates to 0001/0019). |
| — | `engineering/behaviors/config-resolution/variable-expansion.feature` | XCIND-ONLY | P4 | `${APP_ENV}` expansion. |
| — | `engineering/behaviors/config-resolution/xcind-sh-discovery.feature` | XCIND-ONLY | P4 | `.xcind.sh` upward-walk discovery. |

### reference/  (+ appendices)  — eng-reference vs Scind reference only (per ADR-0014)

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/reference/README.md` | `engineering/reference/README.md` | MATCH | — | Both thin index pages; Scind adds an Appendices section. |
| `docs/reference/cli.md` | `engineering/reference/cli.md` | PARTIAL | P4/P5 | Scind unified `scind <resource> <action>` vs Xcind six binaries. Scind-only surface (flavor cmds, clone/generate/destroy, port assign/gc/scan) → P5; Xcind-ahead (`xcind-prompt`, provenance `--version`, `--generate-*`, `application ports/urls/exports`) → P4. |
| `docs/reference/configuration.md` | `engineering/reference/configuration.md` | PARTIAL | P4/P5 | Same concepts, opposite mechanism (Scind YAML, explicitly rejects env-vars, vs Xcind `XCIND_*`). Xcind-only vars → P4; Scind flavor/manifest/`%VAR%` template material → P5. |
| `docs/reference/appendices/cli/detailed-examples.md` | — | SCIND-ONLY | P5 | Extended CLI walkthroughs; **may be covered by Xcind two-track user `docs/`** (not chased — human call). |
| `docs/reference/appendices/cli/error-messages.md` | — | SCIND-ONLY | P5 | CLI error/exit-code catalog; no Xcind eng-reference analog (may live in user docs). |
| `docs/reference/appendices/configuration/complete-examples.md` | — | SCIND-ONLY | P5 | Worked config examples; Xcind embeds inline in `configuration.md`. |
| — | `engineering/reference/build-provenance.md` | XCIND-ONLY | P4 | `XCIND_BUILD_*` provenance schema. |
| — | `engineering/reference/devcontainers.md` | XCIND-ONLY | P4 | Dev Container generation. |

### implementation/  (+ appendices)  — permanent Go/Bash divergence layer (see §3 Q6)

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/implementation/README.md` | `engineering/implementation/README.md` | MATCH | — | Same purpose/framing; Scind adds appendices pointer. |
| `docs/implementation/tech-stack.md` | `engineering/implementation/tech-stack.md` | PARTIAL | P7 | **Expected Go/Bash divergence, NOT drift.** Go (Cobra/Viper/Afero) vs Bash 3.2+/yq/jq/npm/Nix. |
| `docs/implementation/project-layout.md` | `engineering/implementation/project-layout.md` | PARTIAL | P7 | **Expected Go/Bash divergence.** Go package tree vs `bin/` + `lib/xcind/*.bash`. |
| `docs/implementation/cli-scaffolding.md` | — | SCIND-ONLY | P7 | Cobra scaffolding; permanent Go/Bash divergence, **not a P5 gap**. |
| `docs/implementation/appendices/tech-stack/goreleaser.yaml` | — | SCIND-ONLY | P7 | Go release tooling; permanent divergence. |
| `docs/implementation/appendices/tech-stack/makefile` | — | SCIND-ONLY | P7 | Go build Makefile; permanent divergence. |
| `docs/implementation/appendices/tech-stack/scaffold-*.go` (16 files) | — | SCIND-ONLY | P7 | Go source scaffolds (main, cmd-root, aliases, compose-prefix, init-shell, validate, utility, workspace, app, flavor, port, proxy, config, config-types, context, generator). Each a permanent Go/Bash divergence, **not a P5 gap** — Xcind implements the same commands as Bash. *(Enumerated individually in the JSON companion.)* |
| — | `engineering/implementation/handoffs/apex-url-reporting.md` | XCIND-ONLY | P7 | Bash impl work-record (resolved, ties to 0017). No action. |
| — | `engineering/implementation/handoffs/assigned-hook-cache-hit-skip.md` | XCIND-ONLY | P7 | Bash impl work-record (open). No action. |
| — | `engineering/implementation/handoffs/config-json-cache-staleness.md` | XCIND-ONLY | P7 | Bash impl work-record (open). No action. |

### maintenance/  — reserved for P6 (process docs); mapped here for completeness

| Scind path | Xcind path | Rel | Feeds | Notes |
|-----------|-----------|-----|-------|-------|
| `docs/maintenance/README.md` | `engineering/maintenance/README.md` | MATCH | P6 | Same purpose; project-name only diff. |
| `docs/maintenance/audit.md` | `engineering/maintenance/audit.md` | PARTIAL | P6 | Scind migration-flavored; Xcind completeness/accuracy. |
| `docs/maintenance/refine.md` | `engineering/maintenance/refine.md` | MATCH | P6 | Identical intro. |
| `docs/maintenance/sync.md` | `engineering/maintenance/sync.md` | MATCH | P6 | Identical intro; Xcind's is the process P1 ran; cross-repo analog derives from it. |
| `docs/maintenance/update.md` | `engineering/maintenance/update.md` | MATCH | P6 | Identical intro. |
| — | `engineering/maintenance/releasing.md` | XCIND-ONLY | P6 | Bash release procedure. |
| — | `engineering/maintenance/source-review-plan.md` | XCIND-ONLY | P6 | Source-review coordination plan. |
| — | `engineering/maintenance/source-review-cli-entrypoints.md` | XCIND-ONLY | P6 | Source-review work record. |
| — | `engineering/maintenance/source-review-core-runtime.md` | XCIND-ONLY | P6 | Source-review work record. |
| — | `engineering/maintenance/source-review-proxy-routing.md` | XCIND-ONLY | P6 | Source-review work record. |
| — | `engineering/maintenance/source-review-workspace-app-identity.md` | XCIND-ONLY | P6 | Source-review work record. |
| — | `engineering/maintenance/scratchpad-round-3-proxy-routing.md` | XCIND-ONLY | P6 | Active scratchpad; doc-hygiene. |

---

## 2. ADR reconciliation table (keyed by topic)

Keyed on **topic, not number** — "same ADR number" does **not** mean "same
decision." This table supersedes the global-context §4a seed table.

| Topic | Scind ADR | Xcind ADR | Same decision? | Rel | Owner/Feeds |
|-------|-----------|-----------|----------------|-----|-------------|
| ADR template | 0000-template | 0000-template | Yes | MATCH | — |
| Decisions index (README) | README | README | Partial | PARTIAL | — |
| Docker Compose project-name isolation | 0001 | 0001 | Yes | MATCH | (0019 amends → P6/P3) |
| Two-layer networking | 0002 | 0002 | Yes | MATCH | — |
| Pure overlay design | 0003 | 0003 | Yes | MATCH | — |
| Convention-based naming | 0004 | 0004 | Yes | MATCH | — |
| Structure vs state separation | 0005 | 0005 | Yes | MATCH | — |
| Three configuration schemas | 0006 | 0006 | Yes | MATCH | — |
| Port type system | 0007 | 0007 | Yes | MATCH | (root of apex divergence) |
| Traefik reverse proxy | 0008 | 0008 | Yes | MATCH | — |
| Flexible TLS configuration | 0009 | 0009 | Yes | MATCH | (0016 corrects wildcard) |
| up/down command semantics | 0010 | 0010 | Yes | MATCH | — |
| Options-based targeting | 0011 | — | N/A | SCIND-ONLY | **P5** |
| Layered documentation system | 0012 | 0011 | Yes | RENUMBERED | **P6** |
| **Apex URL designation vs reporting** | **0013** | **0017** | **No** | **DIVERGED** | **P3** |
| host.docker.internal normalization | 0014 | 0013 | Yes | RENUMBERED | **P6** |
| Unified `--generate-*` flag semantics | — | 0012 | N/A | XCIND-ONLY | **P4** |
| Two-track documentation | — | 0014 | N/A | XCIND-ONLY | **P4** |
| Application export introspection | — | 0015 | N/A | XCIND-ONLY | **P4** |
| Proxy domain wildcard constraint | — | 0016 | N/A | XCIND-ONLY | **P4/P3** (refines shared 0009) |
| Service-discovery env injection | — | 0018 | N/A | XCIND-ONLY | **P4** (`_HOST_PORT` = PROMOTE candidate) |
| Worktree instance isolation (`XCIND_INSTANCE`) | — | 0019 | N/A | XCIND-ONLY | **P6/P3** — canon-change vs 0001 |
| Host/container env symmetry (`XCIND_HOST_ENV_FILE`) | — | 0020 | N/A | XCIND-ONLY | **P4** (self-flagged PROMOTE) |

### Seed-table verdict

The §4a seed was **confirmed with one correction**:

- **0001–0010** genuinely express the same decisions (Context/Decision spot-checked
  on each; differences are cosmetic — network-name prefixes, YAML-vs-Bash mechanism,
  additive Xcind extensions).
- **Scind 0011 options-based-targeting = SCIND-ONLY** → P5 (Xcind uses subcommands + DIR, no ADR).
- **Scind 0012 ↔ Xcind 0011 LDS = RENUMBERED** (off-by-one) → P6.
- **Scind 0014 ↔ Xcind 0013 host-docker-internal = RENUMBERED** → P6.
- All seven Xcind-only ADRs hold (0012, 0014, 0015, 0016, 0018), **plus the two new
  branch ADRs 0019 & 0020**. 0019 is correctly a **canon-change against Scind 0001**
  (P6/P3), not a plain P4 divergence.
- **Correction — the seed's uncertainty on 0013/0017 resolves to DIVERGED, not
  RENUMBERED.** They are *not* the same decision renumbered: Scind 0013 mandates an
  explicit `primary: true` designation field and **explicitly rejects** Xcind's
  positional approach ("unlike xcind's position-based approach", `0013:9,31`), whereas
  Xcind's designation is positional first-proxied-entry (`0007:32`, reaffirmed
  `0018:45-49`) and Xcind 0017 adds only apex-URL *reporting* on top of that positional
  rule. Same topic, conflicting mechanism → **DIVERGED, feeds P3**.

---

## 3. Structural deltas + open questions

### Q6 — The Go target: **ANSWERED — Scind commits to Go, unambiguously.**

Not language-agnostic. The commitment is explicit and structural:
- `docs/implementation/tech-stack.md` is titled **"Go Technology Stack"** (line 1) and
  pins a real `go.mod` — `module github.com/yourorg/scind`, `go 1.23`, Cobra/Viper/Afero/
  Sprig/validator/docker SDK/testify (lines 11–37).
- `docs/implementation/cli-scaffolding.md` (Step 1, lines 11–14) instructs
  `go mod init …` and maps every CLI command to Cobra commands.
- `docs/implementation/project-layout.md` (lines 6–87) lays out a canonical Go tree
  (`cmd/scind/main.go`, `internal/…`, `pkg/…`, `go.mod`, `go.sum`).
- All 16 `scaffold-*.go` appendices are real Go source (`package main`/`package cli`,
  headed "Create as: cmd/scind/…"), plus `goreleaser.yaml` and a Go build `makefile`.

**Consequence:** the entire Scind-`implementation/` ↔ Xcind-`implementation/` boundary
is a **permanent, intentional Go-vs-Bash divergence** (global-context §5 confirmed).
These rows feed the **P7 divergence registry**, not P5 — there are **zero canon gaps to
close** in the implementation layer (no DIVERGED design conflicts, no SCIND-ONLY items
representing missing design intent — only expected language mechanics).

### Whole-layer / structural deltas

- **Scind-only spec topics (4):** `state-management`, `generated-manifest`,
  `shell-integration`, `host-gateway-resolution`. First three are architectural
  divergences (Xcind is stateless, manifest-free, and ships `xcind-compose` as a binary
  — candidate **P7** as well as P5); `host-gateway-resolution` is the exception — **built
  but not re-specified**, with a candidate real gap (Scind exposes `*_HOST_GATEWAY` into
  containers; Xcind's env-var spec never mentions injecting it — **verify in P5/P3**).
- **Xcind-only spec topics (2):** `hook-lifecycle`, `application-lifecycle` — built,
  unspecified in canon → **P4**.
- **Xcind-only behavior suite (11 features)** vs Scind's 2 — the richest Xcind-ahead
  surface → **P4**.
- **Xcind-only ADRs feeding P4 (6):** 0012, 0014, 0015, 0016, 0018, 0020; **plus 0019
  → P6/P3** (canon-change).
- **Scind reference `appendices/` (3 files)** have no Xcind eng-reference home; Xcind's
  two-track model folds examples inline + into user `docs/` → SCIND-ONLY/P5 **but see
  human-call below**.
- **Xcind-only eng-reference (2):** `build-provenance.md`, `devcontainers.md` → **P4**.
- **`maintenance/` (reserved for P6):** 5 shared LDS process docs (mostly MATCH; `audit`
  is PARTIAL) + 7 Xcind-only process/work-record docs.

### Rows needing a human call

1. **0013/0017 apex DIVERGED (P3, high-priority).** This is the one genuine *design-
   assumption* conflict, not implementation shape. Per global-context §2a it must get an
   adversarial re-check before any divergence label is allowed — likely a **canon-change
   candidate** (does Scind's explicit-primary requirement survive Xcind's positional
   evidence, or does Xcind's ergonomic default teach the canon?). Decide in P3.
2. **`host-gateway-resolution` container-injection gap.** Confirm whether Xcind actually
   injects a `*_HOST_GATEWAY` env var into containers (Scind mandates it; Xcind eng-spec
   is silent). If not built, it's a real P5 not-implemented item; if built-but-undocumented
   it's Xcind self-drift to re-open. **Re-verify against `xcind-host-gateway-lib.bash`.**
3. **Scind reference appendices vs Xcind two-track user docs.** `detailed-examples`,
   `error-messages`, `complete-examples` are eng-reference SCIND-ONLY, but equivalent
   material plausibly lives in Xcind's **out-of-scope** user `docs/` (Diátaxis). Confirm
   before treating as true P5 gaps — otherwise risks a false "Scind-ahead" finding.
4. **`generated-manifest` / `shell-integration` / stateless model** — classify in P5 as
   *deliberately-deferred* (architectural divergence) vs *not-implemented*; these are
   strong **P7 divergence-registry** candidates, not canon gaps.
5. **Implementation bug carried from P1** (not a P2 row, flagged for continuity):
   `xcind-workspace status` is instance-blind for the workspace network name
   (`bin/xcind-workspace:330`) — file as a Linear issue under Xcind; independent of P2.

---

*Machine-readable companion: [`correspondence-map.json`](./correspondence-map.json)
(114 rows, same data, for programmatic P3–P6 filtering).*
