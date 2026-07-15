# P4 — Capabilities in Xcind, Absent from Scind ("Xcind is ahead")

**Status**: COMPLETE.
**Date**: 2026-07-15   **Branch**: `sync/p1-self-sync`
**Plan**: [`04-xcind-capabilities-missing-from-scind.md`](../04-xcind-capabilities-missing-from-scind.md)
**Inputs**: [`00-global-context.md`](../00-global-context.md) (§2 operating model, §2a
DIVERGENCE-must-be-earned, §5 Go/Bash exclusion), [`correspondence-map.md`](./correspondence-map.md)
(every `XCIND-ONLY` row + PARTIAL rows feeding P4), and direct as-built code mining
of `bin/xcind-*` + `lib/xcind/*.bash`.
**Feeds**: P6 (PROMOTE → propose a Scind change), P7 (DIVERGENCE → registry),
P3 (one apex row handed back).
**Machine companion**: [`xcind-ahead.json`](./xcind-ahead.json) (44 capability records + 2 reverse gaps).

> **Supplement (2026-07-15) — human product-calls folded in.** After the initial
> synthesis, three human product-calls were received; they **override** the
> independent classification where they conflict (affected rows tagged
> *source: human product-call*):
> 1. **Two-track docs (ADR-0014)** → **PROMOTE** (new row **XA-0043**).
> 2. **XDG Base Directory split** → **PROMOTE** (new row **XA-0044**).
> 3. **`behaviors/` `.feature` files** → **verified not test-exercised** (see the
>    [Behaviors verification](#behaviors-verification-supplement-item-3) note). Human
>    intent: drop `behaviors/` from both projects.

---

## Method

Five parallel subsystem subagents each **enumerated Xcind's real capability from
code first** (not just eng-docs) and diffed it against Scind canon
(`/Users/beausimensen/Code/scind/docs`) **by topic** — because a capability can
live in a Scind spec even if no ADR names it, and Xcind can implement things absent
even from its own eng-docs:

1. **CLI-surface** — every subcommand/flag across all six `bin/` entrypoints.
2. **Proxy/export** — proxy, exports, TLS, apex, wildcard-domain, service-discovery.
3. **Identity/isolation** — `XCIND_INSTANCE`, worktree, project naming, workspace net.
4. **Hooks/generation** — hook lifecycle, generation cache, overlays, `--generate-*`.
5. **Config/env** — config resolution, env files, host-env symmetry, `XCIND_*` surface.

A synthesis pass **de-duplicated cross-agent overlaps**, re-checked every DIVERGENCE
against the §2a *earned* test, flagged design/scope divergences for the P7
adversarial re-check, and separated **reverse gaps** (Xcind *behind* Scind — out of
P4 scope).

### The rule applied to every row (global-context §2/§2a)

> **PROMOTE** — the capability improves the *design*; Scind should adopt it. Names a
> target Scind change (→ P6).
> **DIVERGENCE** — makes sense only for the Bash impl / is a compromise. **Must be
> earned**: a one-sentence "why Scind should NOT adopt it" (→ P7). Design/scope
> divergences get the adversarial re-check.
> **ESCALATE** — ambiguous / needs a human product call. When unsure, this — never a
> silent divergence.

Language/build artifacts (Go vs Bash idioms, packaging, tech-stack) are **excluded**
(§5). Where a capability's *concept* is language-neutral but its *mechanism* is
Bash-flavored, we promote the concept and note the mechanism as excluded.

---

## Results at a glance

| Recommendation | Count |
|----------------|------:|
| **PROMOTE** (→ P6) | **20** |
| **DIVERGENCE** (→ P7) | **13** |
| **ESCALATE** (human call) | **11** |
| **Total capabilities** | **44** |
| Reverse gaps (Xcind *behind*; → P5/P3, out of scope) | 2 |

*(Counts include the two supplement PROMOTE rows XA-0043/XA-0044.)*

**Not filed here (owned elsewhere):** the core `XCIND_INSTANCE` per-worktree
isolation token and its auto-detection — global-context §2a Example B already rules
it a **CANON-CHANGE against Scind ADR-0001**, owned by P6/P3 (ADR-0019). The apex
*designation* conflict (Scind 0013 explicit-`primary:true` vs Xcind 0007/0017
positional) is a **P3-owned DIVERGED row**; only apex *reporting mechanics* surface
here, and they are handed back to P3 (XA-0025).

---

## PROMOTE — 18 capabilities Scind should adopt

Each names a target Scind change for P6.

### Proxy / export (8) — the richest Xcind-ahead surface

| ID | Capability | Target Scind change |
|----|-----------|---------------------|
| **XA-0002** | Proxy domain **must be multi-label** (contain a dot); non-fatal warning under non-disabled TLS. Empirically, `*.singlelabel` wildcards are rejected by RFC 6125-strict stacks (macOS curl/Safari, Go crypto/tls). Scind's `.scind.test` default masks the bug; the *rule* generalizes. | `proxy-infrastructure.md`/ADR-0009: mandate ≥1 dot + startup warning; cite ADR-0016 evidence. |
| **XA-0003** | Assigned exports get a **`_HOST_PORT`** discovery var (allocated host-published port), splitting in-network (`_HOST`/`_PORT`) from host-side reachability. Additive, forward-compatible. | Add `SCIND_{APP}_{SERVICE}_HOST_PORT` to the assigned set in `environment-variables.md`. |
| **XA-0004** | **Configurable proxy host ports** (`XCIND_PROXY_HTTP_PORT`/`HTTPS_PORT`/`DASHBOARD_PORT`), with discovery `_PORT`/`_URL` correctly reflecting a non-default port. Scind hardcodes 80/443/8080. | Add the three port vars to proxy config; specify discovery URLs include the non-default port. |
| **XA-0005** | **Per-export TLS metadata** (`tls=auto\|require\|disable`) + shared redirect middleware + `noop@internal` redirect-only routers. Lets one app mix HTTP-only and HTTPS-required exports. Scind's ADR-0009 is a stub. | Add a per-export `tls` attribute to `port-types.md`/ADR-0009; document the redirect-middleware pattern. |
| **XA-0006** | **`traefik.docker.network` label + pinned router→service binding.** On a multi-network container (which Scind ADR-0002 guarantees), an omitted network label causes intermittent mis-routing — a correctness bug. | Add `traefik.docker.network` + explicit router→service to required labels in `docker-labels.md`. |
| **XA-0007** | **Preferred scheme-agnostic `.url` label** (`xcind.export.{n}.url` / apex) so consumers get "the URL to use" without re-deriving https-preference. | Add `scind.export.{name}.url` / `scind.apex.url` to `docker-labels.md`. |
| **XA-0008** | **TLS cert cascade + domain-change regeneration marker.** Deterministic order (user > cache > mkcert > openssl) and a `domain` marker so a domain change re-mints the wildcard instead of serving a stale-CN cert. Scind hand-waves the mechanics. | Specify the auto-mode resolution order + domain-change regeneration in `proxy-infrastructure.md`. |
| **XA-0009** | **Path-existence GC of assigned ports** (`prune` + auto-prune on init/up/status) + `release PORT`. Catches a case Scind's inventory model misses: a deleted app dir still holding its reservation. | Add a "drop entry whose app path no longer exists" GC rule to `state-management.md`. |

### CLI-surface (7)

| ID | Capability | Target Scind change |
|----|-----------|---------------------|
| **XA-0010** | **Context-aware shell prompt segment** — `xcind-prompt` (workspace/app + clickable apex URL via OSC 8, `<500ms` fast path) + `--generate-starship` block. Scind's shell-integration spec has completion + `scind-compose` but **no prompt concept at all**. | Add a `scind prompt` command + Starship-snippet generate path to `shell-integration.md`/`cli.md`. |
| **XA-0011** | **Per-app export introspection** — `ports`/`urls`/`exports` with `[SERVICE]` filter and **bare-scalar output** for scripting (`open $(xcind-application urls web)`). Scind has workspace-level `urls` but no per-app scalar command. | Add `scind app urls`/`ports`/`exports` with `-q` scalar output to `cli.md`. |
| **XA-0012** | **Unified per-export descriptor** merging assigned + proxied by export name (type/service/port/url/tls/apex) in one view. Scind splits the two port types across separate commands. | Define a unified export descriptor in `port-types.md`; expose via `app show`/`exports`. |
| **XA-0013** | **Resolved/flattened compose-config export** to stdout or arbitrary file (`--generate-docker-compose-configuration`), the substrate for the **Dev Container** workflow. Scind's `workspace generate` writes override *deltas* to a fixed path only. *(Merged: CLI + hooks/generation `--generate-*` + devcontainer.)* | Add a resolved-compose output (stdout + file) to `cli.md`/`generated-manifest.md`; document the devcontainer consumer. |
| **XA-0014** | **POSIX docker/docker-compose wrapper generation** — real executable wrappers for tools (JetBrains, CI) that exec a literal `docker`/`docker-compose` binary and **cannot call a shell function**. Scind's answer is the `scind-compose` shell function — unreachable by such tools. | Add a wrapper-script generator to `shell-integration.md`/`cli.md`. |
| **XA-0015** | **Build provenance in `--version`** (source channel / short rev / dirty / date). Scind's version output is a bare string. *(The env-injection mechanism is Bash-flavored/excluded; the capability is the provenance disclosure.)* | Specify a SemVer build-metadata suffix in the Version Information section of `cli.md`. |
| **XA-0016** | **Fine-grained registry ops** — `register PATH` (a cloned-but-never-run workspace with no Docker labels) and `forget PATH` (drop one moved/deleted entry). Scind registers only via `init`, prunes only stale, rebuilds from labels — none handle these. | Add `scind workspace register/forget PATH` to `cli.md`/`state-management.md`. |

### Config / env + hooks (3)

| ID | Capability | Target Scind change |
|----|-----------|---------------------|
| **XA-0017** | **Host/container env symmetry** via opt-in host-view env file (`XCIND_HOST_ENV_FILE`/`_MODE`): assigned exports resolve to `127.0.0.1` + host port on the host, proxied/apex stay routable, reusing the same discovery seam — a committed `DATABASE_URL` resolves identically on host and in-container. **Self-flagged PROMOTE in ADR-0020.** Scind specs only the container view. | Add a "host-view env export" to `environment-variables.md` + an ADR analogous to Scind 0018. |
| **XA-0018** | **App-level env-file interpolation-vs-injection split**: `XCIND_COMPOSE_ENV_FILES`→`--env-file` (YAML `${VAR}` interpolation) vs `XCIND_APP_ENV_FILES`→`env_file:` overlay on every service (container-visible). Scind has **no application-level dotenv concept**. | Add `compose_env_files` + `app_env_files` fields to `application.yaml` in `configuration-schemas.md`. |
| **XA-0001** | **Generation-cache live-state correctness** (`XCIND_HOOKS_ALWAYS`): overlays embedding live-allocated ports/discovery values re-run on an otherwise-valid cache hit; pure overlays replay. A correctness principle for *any* config-keyed cache, Go included. | Specify config-derived vs live-state-derived content in staleness detection (`generated-manifest.md`/`state-management.md`). |

### Supplement — human product-calls (2)

*Source: human product-call — these override the initial classification.*

| ID | Capability | Target Scind change |
|----|-----------|---------------------|
| **XA-0043** | **Two-track documentation (ADR-0014)** — a user-facing Diátaxis track (`docs/`) plus a separate engineering LDS track (`engineering/`) mirroring the design canon, so the two audiences evolve independently. Scind keeps a single `docs/` LDS tree. *(Overrides the initial likely-PROCESS/DIVERGENCE reading.)* | Rename Scind `docs/` → `engineering/` (matching Xcind's LDS track); optionally add a placeholder `docs/README.md` stating intent for a future Diátaxis track (no real Diátaxis content exists yet in either project). |
| **XA-0044** | **XDG Base Directory split** — config under `$XDG_CONFIG_HOME` (`~/.config/xcind`), ephemeral state (assigned-port TSV, registry, proxy state) under `$XDG_STATE_HOME` (`~/.local/state/xcind`). Scind defaults **both** `SCIND_CONFIG_DIR` and `SCIND_STATE_DIR` to `~/.config/scind`, collapsing state under config-home. This is ADR-0005 (structure-vs-state) encoded at the filesystem level. | Default `SCIND_STATE_DIR` to `$XDG_STATE_HOME/scind`; keep `SCIND_CONFIG_DIR` under `$XDG_CONFIG_HOME/scind`; align with the XDG spec (config vs state vs data) in `environment-variables.md`/`state-management.md`. |

---

## DIVERGENCE — 13 intentional Xcind-only differences (→ P7)

Each carries an earned "why Scind should NOT adopt." **Design/scope** divergences
(marked ⚠) reach into Scind's promises/assumptions and get the **P7 adversarial
re-check** before the label stands; **implementation-shape** divergences are safe to
record (they don't hide learnings — global-context §2a).

| ID | Capability | Class | Why Scind should NOT adopt |
|----|-----------|-------|----------------------------|
| **XA-0036** | `--check` runtime dependency checker (jq/yq/sha256sum) | impl-shape | A static Go binary embeds YAML/JSON/hashing and shells out to none of them; the check is meaningless in Scind. |
| **XA-0037** | `.xcind.sh` trust/security warning in status/list | impl-shape | Scind config is parsed YAML, never executed — inspecting a foreign workspace runs no code, so no warning is warranted. (Direct consequence of the settled config-mechanism divergence.) |
| **XA-0038** | `--generate-starship --format nix` output | impl-shape | A package-ecosystem-specific serialization riding on XA-0010; if Scind adopts a prompt segment, its output formats are its own concern. |
| **XA-0039** | `--preview` resolved-command flag | impl-shape | Already covered by Scind's `compose-prefix`; Xcind's flag placement is an arrangement detail, not a new capability. |
| **XA-0040** | Shell `${VAR}`/`$(cmd)` expansion in file patterns | impl-shape | Scind's typed **flavor** system is the deliberate equivalent for env-driven file selection; shell expansion reintroduces the arbitrary-shell-in-config shape (+ injection surface) the settled typed-YAML divergence rejects. |
| **XA-0041** | Per-file `.override` sibling auto-derivation | impl-shape | Scind already provides the equivalent (`overrides/{app}.yaml` with a preservation guarantee); the per-file sibling is a layout/mechanism choice. |
| **XA-0042** | `XCIND_ADDITIONAL_CONFIG_FILES` includes | impl-shape | Scind's typed schema layering already composes config; a "source these files" include recreates the arbitrary-shell-in-config shape the settled divergence rejects. |
| **XA-0034** ⚠ | Default domain `localhost.scind.io` | design | `scind.io` is an Xcind-owned registration with trade-offs Scind may not want (hostname leakage to public resolvers, external-registration upkeep, DNS-rebinding failures); `.scind.test` is a legitimate default. *(The promotable insight — the multi-label constraint — is split out as XA-0002.)* |
| **XA-0035** ⚠ | Assigned-port **sticky-trust** allocation (no probe, no fail-at-startup) | design | Scind's **fail-closed** model (explicit conflict error + scan/release remediation) is a valid, arguably safer contract; with Go `net.Listen` probing it should not adopt sticky-trust, a trade specific to Xcind's self-vs-foreign bind ambiguity. |
| **XA-0033** ⚠ | Stateless identity/registry (path+timestamp TSV; no `state.yaml`/manifest) | design | Scind's richer persistence (flavor state, computed manifest, label-reconstructable registry) is intentional infra for its tooling/dashboards/staleness checks; downgrading to a metadata-free TSV drops capabilities its design relies on. |
| **XA-0030** ⚠ | Concern-split **8 per-hook overlays** (vs 1 monolithic override) | scope | Scind regenerates one override atomically; splitting into 8 files adds merge-order/filesystem complexity with no output difference, and only pays off with Xcind's per-hook caching. *(The transferable learning — separate live-state from pure — is preserved as XA-0001.)* |
| **XA-0031** ⚠ | Internal 4-array **phase vocabulary** (CONFIGURED/RESOLVED/GENERATE/EXECUTE) | design | Scind's monolithic generator already separates generate from up without named phase arrays; the vocabulary adds ceremony with no consumer **absent the extensibility surface** (XA-0019). *Contingent on XA-0019* — re-evaluate if that promotes. |
| **XA-0032** ⚠ | Per-app SHA-keyed `config.json` introspection artifact | design | Scind already has an equivalent-or-broader introspection surface (the aggregated workspace `manifest.yaml`); Xcind's per-app SHA JSON is shaped to its content-addressed cache and would duplicate the manifest rather than add capability. *(Reverse-gap note: Xcind has no human-readable aggregated manifest — a Scind-ahead item for P5.)* |

⚠ = design/scope divergence, **requires P7 adversarial re-check** (the skeptic argues
"this is just how Xcind happens to work"; if it fails, the row promotes to a learning).

---

## ESCALATE — 11 rows needing a human product call

Genuine capability gaps where the right answer is a product/architecture decision,
not a mechanical port. Per §2a, when unsure we route here — never to a silent
divergence.

| ID | Capability | The open question |
|----|-----------|-------------------|
| **XA-0019** | Extensible generation **hook lifecycle** (user-registrable GENERATE/EXECUTE hooks) | Should Scind expose a first-class generation extensibility surface (Go plugin API or hook-directory contract), or keep generation monolithic? Scind can't source shell functions, so adopting means *designing* a plugin contract. |
| **XA-0020** | **Content-addressed** (SHA-of-inputs) generation cache | Should Scind replace manifest-vs-config staleness detection with content addressing (+ per-SHA generated dirs)? More robust, but a substantial architecture change. |
| **XA-0021** | **Workspaceless** standalone app mode (`XCIND_WORKSPACELESS`) | Should Scind support a truly workspaceless single-app mode, or is the mandatory `workspace.yaml` boundary a deliberate context-hijack guardrail? |
| **XA-0022** | **Late-bind workspace self-declaration** (app names its workspace) | Should Scind let an app declare its own membership (app→workspace), inverting the `workspace.yaml`-lists-apps ownership model? Depends on XA-0021. |
| **XA-0023** | `XCIND_APP_ROOT` env root-pin escape hatch | Worth adding vs the existing `--app/-a` flag (ADR-0011)? Likely already covered — probably not a real gap. (low) |
| **XA-0024** | On-demand **proxy auto-start** on app `up` + `XCIND_PROXY_AUTO_START=0` opt-out | Should Scind auto-start the proxy as a side effect of an *app* `up` (not just workspace up), with a first-class opt-out? Intersects ADR-0010 up/down semantics. *(Merged: proxy + config/env.)* |
| **XA-0025** | **Apex reporting mechanics** (prefer-apex, opt-out, live host swap) | **HAND TO P3.** Entangled with the positional-vs-`primary:true` designation conflict (Scind 0013 vs Xcind 0017). Fold apex reporting + single-export opt-out into P3's apex decision, not decided twice. |
| **XA-0026** | `proxy init` accepts full config as flags (TLS/cert/dashboard/ports) | The underlying capabilities promote separately (XA-0004/0005/0008); the remaining question is the *interface* — init flags vs a declarative `proxy.yaml`. |
| **XA-0027** | `config doctor` generation/routing diagnostic | Scind already owns `doctor` for host/Docker/DNS health. The intent ("explain why routing/generation didn't happen") is general; the Bash internals (sourcing order, hook registration) don't transfer. Scope + naming call. |
| **XA-0028** | **Zero-config** default compose/env candidate resolution | Should Scind auto-detect conventionally-named compose files (`compose.yaml`, `.env`) when none are declared, or keep explicit per-flavor `compose_files`? Convention-based for naming (ADR-0004) yet explicit for files — ambiguous. |
| **XA-0029** | `XCIND_TOOLS` declarative host→container tool shortcuts | Should Scind model declarative per-project tool shortcuts (host command → service + exec/run mode) as a typed field, or keep only generic `exec`? |

---

## Behaviors verification (supplement item 3)

**Claim checked:** are Xcind's `engineering/behaviors/*.feature` files exercised by
any test target? **Result: NO.**

`make test` runs three hand-written **bash assertion scripts** —
`test/test-xcind.sh`, `test/test-xcind-proxy.sh`, `test/test-xcind-prompt.sh`
(9,045 lines total). There is **no cucumber / godog / behave / gherkin runner**, and
no test script, `Makefile`, or `package.json` references any `.feature` file. The 12
`.feature` files under `engineering/behaviors/` are **documentation-only Gherkin**.

**Impact on this artifact:** no capability row rests *solely* on a `.feature` file.
Every behavior-derived row (**XA-0018, XA-0021, XA-0022, XA-0023, XA-0028, XA-0040,
XA-0041**) also cites `lib/xcind/` code and, in most cases, is covered by the bash
test scripts — so the rows remain **real**. Only the `.feature` citation is
downgraded from "test-exercised" to "design-doc" evidence.

**Human intent:** drop `behaviors/` from **both** projects. Treat `.feature`
citations here as design-doc evidence, not executable proof.

---

## Reverse gaps — Xcind *behind* Scind (out of P4 scope)

Surfaced by the proxy/export agent while diffing; recorded for completeness and
handed to **P5/P3** (P4 is the Xcind-ahead direction only). These are **not** P4
capability rows.

- **RG-0001 — `*_HOST_GATEWAY` env injection.** Scind's `host-gateway-resolution.md`
  mandates (SHOULD) exposing the resolved workstation host as `SCIND_HOST_GATEWAY`
  *inside containers* (Xdebug `client_host` use case). Xcind's host-gateway hook
  writes only `extra_hosts: host.docker.internal:<value>` and **never injects the env
  var** (`lib/xcind/xcind-host-gateway-lib.bash:150-224`). Either implement it or
  record a deliberate divergence — decide in P5/P3. *(This confirms the
  correspondence-map §3 "human call #2" — Xcind does NOT inject it.)*
- **RG-0002 — per-export/port `visibility` labels.** Scind emits
  `scind.export.{n}.proxy.{proto}.visibility` / `port.{n}.visibility`
  (`public|protected`) so external tools filter by intent. Xcind emits **no
  visibility labels** and drops the `proxy.` label segment. Decide whether Xcind
  restores them and whether the naming should re-converge.

---

## Done-criteria check

- [x] Every `XCIND-ONLY` P2 row evaluated **and** the code surface enumerated beyond
      the docs (full `bin/` subcommand/flag sweep + the ~100-entry `XCIND_*` variable
      inventory mined directly from `lib/xcind/*.bash`).
- [x] Each capability real + cited (`bin/`/`lib/` path, mostly with a behavior/spec),
      confirmed absent from Scind by topic, with a PROMOTE / DIVERGENCE / ESCALATE
      recommendation + rationale.
- [x] `PROMOTE` items name the target Scind change (hand-off to P6).
- [x] `DIVERGENCE` items are registry-ready with an earned "why not adopt" and a
      class/re-check flag (hand-off to P7); design/scope ones marked for adversarial
      re-check.
- [x] `xcind-ahead.md` + `.json` written.
- [x] Supplement (2026-07-15) folded in: XA-0043 (two-track docs) + XA-0044 (XDG)
      added as PROMOTE per human product-call; `behaviors/` `.feature` files verified
      not test-exercised.

**Cross-plan hand-offs:** XA-0025 → **P3** (apex reporting, fold into the designation
decision). RG-0001/RG-0002 → **P5/P3** (Xcind-behind). Core `XCIND_INSTANCE` remains
**P6/P3** (ADR-0019 canon-change, not re-filed here). `behaviors/`-drop is a
docs-process action for **P6** (both projects).
