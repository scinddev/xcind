# P5 — Scind-Ahead: Capabilities Specified in Scind, Unexercised in Xcind

**Status**: COMPLETE. Every `SCIND-ONLY` and `PARTIAL`(Scind-richer) P2 row plus
every Scind roadmap "Future" item evaluated and labeled.
**Date**: 2026-07-15   **Branch**: `sync/p1-self-sync`
**Inputs**: [`00-global-context.md`](../00-global-context.md) §2/§5,
[`05-scind-capabilities-unexercised-in-xcind.md`](../05-scind-capabilities-unexercised-in-xcind.md),
[`correspondence-map.md`](./correspondence-map.md) + `.json`.
**Method**: five parallel subagents by Scind capability cluster (state/generation,
networking/gateway, shell-integration, targeting/CLI-semantics, roadmap-futures),
each quoting Scind canon (`/Users/beausimensen/Code/scind/docs`, read-only) and
searching Xcind `bin/` + `lib/xcind/` + `test/` + `engineering/behaviors/`.
Overlapping findings (manifest, flavors, SNI/protocol, port-scan) deduplicated.
The flagship leads (host-gateway env exposure, ADR-0011 targeting) were also
verified directly by the coordinator.

**Machine-readable companion**: [`scind-ahead.json`](./scind-ahead.json) (26 gaps,
same data + `scind_promise` quotes and per-row `feeds`).

> **Human product-calls applied (2026-07-15).** After the initial pass, human
> product-calls were received; they **override** the coordinator's independent
> labels where they conflict, and affected rows are tagged
> `source: human product-call`:
> 1. **host-gateway container-injection** (SA-0002): code-dived and confirmed
>    Xcind emits `extra_hosts` only. Scind **keeps mandating** the `*_HOST_GATEWAY`
>    env var → labeled **DELIBERATELY-DEFERRED** (documented known divergence),
>    **explicitly NOT canon-overreach**; Scind canon is *not* softened.
> 2. **Scind reference appendices** (SA-0025): left as-is for Scind (no code
>    behind them yet); Xcind shows real usage under `docs/` (Diátaxis) →
>    **DELIBERATELY-DEFERRED** known divergence, **not a gap Xcind must close**.
> 3. **generated-manifest / shell-integration / stateless model** (SA-0007,
>    SA-0010): confirmed **DELIBERATELY-DEFERRED** architectural divergences.
> 4. **`scind-compose` shell script** (SA-0026, new): open question whether Scind
>    needs it → **ESCALATE**.
> 5. **`.feature` files**: verified they are **living-documentation only** — `make
>    test` runs only `test/test-xcind*.sh`; there is no cucumber/bats/`.feature`
>    runner. **No** IMPLEMENTED-UNTESTED or "tested → not a gap" call in this
>    artifact relied on a `.feature` file; all rest on the `test/*.sh` suites, so
>    the SA-0003 latent-bug flag and the host-gateway/assigned-port "tested"
>    determinations stand.

---

## The labels

| Label | Meaning | Destination |
|-------|---------|-------------|
| **NOT-IMPLEMENTED** | Xcind could/should build it; simply hasn't. | Xcind backlog. |
| **IMPLEMENTED-UNTESTED** | Code exists but nothing exercises it — correctness unproven. | Xcind test/behavior backlog. ⚠️ latent bug. |
| **DELIBERATELY-DEFERRED** | Xcind consciously scoped it out. | P7 divergence registry. |
| **CANON-OVERREACH** | Building Xcind shows the Scind spec is wrong/gold-plated. | **Change Scind** (P6) — reverse learning. |
| **ESCALATE** | Open question a human must resolve; not yet classifiable. | Human / P6 design decision. *(added per product-call)* |

## Tally

| Label | Count | IDs |
|-------|------:|-----|
| NOT-IMPLEMENTED | 4 | SA-0004, SA-0012, SA-0021, SA-0022 |
| IMPLEMENTED-UNTESTED | 1 | **SA-0003** ⚠️ |
| DELIBERATELY-DEFERRED | 19 | SA-0001, SA-0002, 0007–0011, 0013–0020, 0023–0025 |
| CANON-OVERREACH | 1 | **SA-0005** → P6 |
| ESCALATE | 1 | **SA-0026** → human/P6 |
| **Total** | **26** | |

> **SA-0002 moved** NOT-IMPLEMENTED → DELIBERATELY-DEFERRED and **SA-0026 added**
> (ESCALATE) per the human product-calls above.

Two rows carry an additional **CANON-OVERREACH *candidate*** flag routed to P3
without changing their primary label: **SA-0005** (also the confirmed overreach)
and **SA-0006** (primary-designation mechanism — the apex conflict is P3's to
adjudicate).

---

## ⚠️ Flagged rows (read these first)

### SA-0003 — IMPLEMENTED-UNTESTED (latent-bug risk)

**Shell completion FUNCTION behavior is unverified.**
`lib/xcind/xcind-completion-bash.bash:19-99` implements docker `__complete`
delegation, directive-bit parsing (`((directive & N))`, `${lastLine:0:1}`
slicing, `sed` line-delete) and per-command branches — **none exercised**. The
tests (`test/test-xcind.sh:2936-3002`) only assert the *emitted script text*
contains registration lines; no test sources the script, sets
`COMP_WORDS`/`COMP_CWORD`, calls a completion function, and inspects `COMPREPLY`.
Scind's `shell-integration.md:58-64,224-246` promises working tab-completion;
Xcind has the code but never proves it. **Fix**: add behavioral tests that source
the emitted script and drive the completion functions with fabricated
`COMP_WORDS`/`COMP_CWORD`. The docker `__complete` fallback path is the highest
risk.

### SA-0005 — CANON-OVERREACH (→ P6, change Scind)

**Scind's fail-fast on port-conflict at `up` will mis-fire on idempotent re-up.**
Scind (`state-management.md:99-113`) says: if a previously-assigned port is
unavailable at `workspace up`, fail with a conflict error. Xcind **deliberately
abandoned** probe-and-evict here: `xcind-assigned-lib.bash:789-797` "Sticky hit:
trust the TSV. We cannot tell *our own running container*…", and the regression
test `test/test-xcind-proxy.sh:2753-2772` records why — "probing and evicting
caused ports to flap on every cache miss while the container was up." A
`net.Listen` bind-probe cannot distinguish the workspace's **own already-running
container** (a normal re-up) from an external process, so Scind's fail-fast
would raise false conflicts on the common re-up case. **Reverse learning**:
Scind's startup check must exclude ports bound by the workspace's own running
containers before declaring a conflict. Confidence *medium* — it hinges on
whether Scind's `port_inventory` actually attributes a bound port to its owner;
verify in P6.

---

## Findings by cluster

### 1. State / generation

Xcind is **deliberately stateless**: no persisted `state.yaml`, no computed
`manifest.yaml`, no `port_inventory` status model, no workspace state machine.
Every gap here is a conscious architectural divergence (basis: Xcind ADR-0005 +
`application-lifecycle.md:12-14` "no separate state store, no manifest"). The one
overlapping capability — assigned-port stickiness — is built **and** tested
(`test/test-xcind-proxy.sh:2693-2772`), and Scind's mtime-staleness detection is
functionally matched by Xcind's SHA-cache invalidation. **No IMPLEMENTED-UNTESTED
here.** The startup-conflict behavior (SA-0005) surfaced as the one reverse
learning.

- **SA-0007** Generated manifest — DELIBERATELY-DEFERRED (→P7). Topology derived
  on demand via `xcind-application …` + `xcind-config --json`.
- **SA-0008** Flavors (variant configs + `default_flavor` + resolution +
  `flavor` commands) — DELIBERATELY-DEFERRED (→P7). Flat `XCIND_COMPOSE_FILES`
  is the equivalent; ADR-0005 dropped every flavor row. *Soft P6 note: make the
  deferral explicit in ADR-0005.*
- **SA-0009** `port_inventory` + assigned/unavailable/released status model —
  DELIBERATELY-DEFERRED (→P7). Xcind's TSV tracks only active assignments;
  path-existence `prune` + manual `release` are the practical GC subset.
- **SA-0010** Workspace state machine + explicit generate/destroy —
  DELIBERATELY-DEFERRED (→P7). Status inferred from Docker live. (CLI facets:
  SA-0023 generate, SA-0024 destroy.)
- **SA-0005** Fail-fast port-conflict at startup — **CANON-OVERREACH** (→P6, see
  above).

### 2. Networking / gateway

Host-gateway normalization is **built and well-tested** — the P2 lead that this
was likely PARTIAL/untested is **resolved**: the `extra_hosts` detection
(WSL2 NAT/mirrored, Docker Desktop skip, opt-out, override, existing-entry
preservation, SHA invalidation) has ~15 tests. Two-layer networking is a MATCH.
One documented divergence:

- **SA-0002** Expose `*_HOST_GATEWAY` env var **inside containers** —
  **DELIBERATELY-DEFERRED** *(source: human product-call)*. Code dive confirmed
  `xcind-host-gateway-lib.bash:200-224` builds **only** a
  `services.<name>.extra_hosts` list (`host.docker.internal:<resolved>` +
  carried-forward entries) — no `environment:` block, no named gateway variable
  reaches any container. **Human product-call**: Scind **keeps mandating** the
  env-var exposure in canon — this is **NOT canon-overreach** and the spec is not
  softened. Xcind's extra-hosts-only behavior is a **documented known divergence**
  (→ P7); Xcind *may* optionally add `environment: - XCIND_HOST_GATEWAY=…` later
  (value already computed in-hook; unblocks Xdebug), but its absence is accepted,
  not a gap Scind must accommodate.
- **SA-0015** (tcp/SNI routing) is filed under roadmap-futures — Scind's own
  canon marks it `(future)`.

### 3. Shell integration

Xcind made `xcind-compose` a **real binary** rather than Scind's
`scind-compose` shell-function-over-`compose-prefix` — a legitimate architectural
divergence, not a gap. Genuine findings:

- **SA-0003** Completion function behavior untested — **IMPLEMENTED-UNTESTED**
  (see flagged section).
- **SA-0004** Fish support — NOT-IMPLEMENTED. `completion fish` errors
  "unsupported shell" (`test/test-xcind.sh:2989-2994`); no fish anywhere. Scind
  ships `fish-setup.fish` + `completion fish` + `init-shell fish` and lists
  Fish 3.0+. `is_deliberate: unknown` — the error is enforcement, not a
  documented decision; record an ADR **or** add fish.
- **SA-0026** `scind-compose` shell function + `scind compose-prefix` —
  **ESCALATE** *(source: human product-call)*. `bin/xcind-compose:1-76` is a real
  binary that resolves compose options internally and `exec`s docker compose; no
  shell function, no `compose-prefix` subcommand. Xcind proved a binary subsumes
  the mechanism, but forgoes the "completion for free" delegation Scind's design
  buys. **Open question for the Scind side**: keep the shell-function/compose-prefix
  architecture, adopt Xcind's binary, or support both — a canon design decision,
  not a settled divergence nor a plain Xcind gap.
- `init-shell` bootstrap — DELIBERATELY-DEFERRED consequence of the binary
  architecture; completions install standalone via
  `. <(xcind-config completion bash)`.
- Dynamic workspace/app-name completion — DELIBERATELY-DEFERRED: the
  `update-completions` skill mandates self-contained scripts that "must not
  reference internal xcind functions," precluding registry-backed name
  completion that Scind's fish setup does via `(scind app list -q)`.

> **Reverse-direction note (not a P5 gap)**: Xcind ships `bin/xcind-prompt`
> (Starship integration, apex OSC-8 hyperlinks, 194 test asserts) — Scind's
> shell-integration spec has **no** prompt segment. That is an Xcind-ahead
> back-port candidate for P4/Scind canon, not a Scind-ahead gap.

### 4. Targeting / CLI-semantics

The flagship ADR-0011 item resolves cleanly, plus the Scind command surface
Xcind lacks:

- **SA-0001** Options-based targeting by name (`--workspace`/`--app` from
  anywhere; ADR-0011) — DELIBERATELY-DEFERRED (→P7). **Zero** targeting flags
  exist; Xcind targets by cwd upward-walk + positional `[DIR]` + `XCIND_APP_ROOT`
  (documented in `context-detection.md`). Real sub-gap: **no target-by-name
  resolver** — you must be in/point at the directory. No Xcind ADR records the
  deviation → **recommend filing one**.
- **SA-0013** Workspace-wide `up/down/restart` orchestration —
  DELIBERATELY-DEFERRED, but the **highest-value reconsider candidate**:
  `xcind-workspace status` already enumerates all apps, so a thin loop over app
  dirs would be a natural addition. ADR-0010 up/down *verb* semantics themselves
  MATCH (inherited from docker compose).
- **SA-0006** Explicit `primary: true` designation + multi-primary validation —
  DELIBERATELY-DEFERRED; **CANON-OVERREACH candidate → P3**. Xcind's positional
  first-proxied-export apex works; whether Scind's explicit-primary is
  gold-plated is the P3 apex-DIVERGED adjudication (`correspondence-map.md:291`).
- **SA-0011** `port scan` / `port gc` — DELIBERATELY-DEFERRED. Xcind's
  auto-running `prune` is the dead-path subset of `gc`; the unbound-reclamation +
  `scan` halves need the persisted inventory Xcind omits (SA-0009).
- **SA-0012** `port assign` (manual pin) — **NOT-IMPLEMENTED**. The only Scind
  port command with no Xcind scope decision on record. Decide: keep auto-only or
  add an escape hatch.
- **SA-0014** `workspace clone` (repo URLs) — DELIBERATELY-DEFERRED. Xcind config
  has no `repository` concept; workspaces are directories the user brings.
- **SA-0021** Context-detection UX (`Using workspace: …` feedback, exit code 5,
  "Available apps" hints) — NOT-IMPLEMENTED. Generic `Error: No .xcind.sh found`,
  exit 1. Low-value polish. Absorbs Scind's `error-messages` appendix.
- **SA-0022** Universal `--yaml`/`--quiet`/`--verbose`/`--color` flags —
  NOT-IMPLEMENTED. `--json` covers most machine-readable needs; `--quiet`
  names-only + `--yaml` are the language-independent gaps.
- **SA-0023** Explicit `workspace generate` / **SA-0024** `workspace destroy` —
  DELIBERATELY-DEFERRED CLI facets of the stateless model (SA-0010).

### 5. Roadmap-futures

Every item here is `(Future)` in Scind's **own** canon and unbuilt in Xcind —
all DELIBERATELY-DEFERRED, none latent bugs. Two sub-tiers:

- **Both defer, Xcind still plans it** (low urgency, not a permanent divergence):
  **SA-0016** application dependencies (`depends_on`), **SA-0018** health checks —
  both retained on Xcind's roadmap.
- **Dropped from Xcind's roadmap / test-enforced-out** (permanent subset → P7):
  **SA-0015** port-type plugins + tcp/SNI, **SA-0017** shared volumes,
  **SA-0019** visibility (public/protected — *test-enforced rejection*,
  `test/test-xcind-proxy.sh:721-723`), **SA-0020** customizable `%VAR%` template
  surface, and **SA-0008** flavors (spec-level, cross-listed under
  state/generation).

### Reference docs (P2 human-call #3, resolved)

- **SA-0025** Scind reference appendices (detailed-examples, error-messages,
  complete-examples) — DELIBERATELY-DEFERRED, **not a gap Xcind must close**
  *(source: human product-call)*. **Product-call**: leave Scind's appendices
  as-is (no code exists behind them yet); Xcind demonstrates real usage under its
  out-of-scope two-track USER `docs/` (Diátaxis) — `docs/reference/cli.md`,
  `docs/getting-started/*`, `docs/guides/*` (12 guides) — with worked examples
  folded inline. Known divergence → P7. The one piece with no Xcind analog, an
  error/exit-code **catalog**, is tracked as UX polish under SA-0021.

---

## Hand-offs

**→ P6 (change Scind / reconciliation)**
- **SA-0005** CANON-OVERREACH: fix Scind's startup port-conflict check to exclude
  the workspace's own running containers.
- Soft note (SA-0008): make the flavors deferral explicit in Xcind ADR-0005.
- *(Withdrawn per human product-call: the earlier note to soften Scind's
  host-gateway env-var "mandate" is dropped — Scind keeps mandating it.)*

**→ ESCALATE (human / P6 design decision)**
- **SA-0026** `scind-compose` shell function + `compose-prefix`: open canon
  question — does Scind still need this design given Xcind's binary works?

**→ P3 (learnings / apex adjudication)**
- **SA-0006** primary-designation mechanism — CANON-OVERREACH candidate feeding
  the existing apex-DIVERGED verdict.

**→ P7 (divergence registry)** — the 19 DELIBERATELY-DEFERRED rows: SA-0001,
**SA-0002** (host-gateway extra-hosts-only, known divergence — *human
product-call*), SA-0007–SA-0011, SA-0013–SA-0015, SA-0017, SA-0019, SA-0020,
SA-0023, SA-0024, SA-0025 (permanent/architectural/doc-presentation divergences),
with SA-0008 cross-listed. SA-0016 & SA-0018 stay on the **Xcind backlog**
(shared future work, not divergences).

**→ Xcind backlog (build or decide)** — SA-0003 (test the completion functions,
⚠️ latent bug), SA-0004 (fish), SA-0012 (`port assign`), SA-0013 (workspace
orchestration), SA-0021 / SA-0022 (CLI UX). SA-0002's env-var injection is an
*optional* backlog item (its absence is an accepted divergence, not a required
gap).

---

## Done criteria

- [x] Every `SCIND-ONLY`/`PARTIAL`(Scind-richer) P2 row + every Scind roadmap
      future item evaluated.
- [x] Each of the 26 gaps labeled exactly one of NOT-IMPLEMENTED /
      IMPLEMENTED-UNTESTED / DELIBERATELY-DEFERRED / CANON-OVERREACH — plus one
      ESCALATE added per human product-call — with cited evidence.
- [x] `CANON-OVERREACH` (SA-0005) handed to P6; `DELIBERATELY-DEFERRED` rows to
      P7; SA-0006 overreach-candidate to P3; SA-0026 ESCALATE to human/P6.
- [x] `IMPLEMENTED-UNTESTED` (SA-0003) flagged as a latent-bug risk.
- [x] Human product-calls (2026-07-15) folded in and tagged
      `source: human product-call`; overrides applied where they conflicted.
- [x] Xcind `.feature` files verified as living-documentation only (not executed);
      no test-based label depended on them.
- [x] `scind-ahead.md` + `.json` written; JSON re-validated.
