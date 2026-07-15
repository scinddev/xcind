# Xcind Self-Sync Report (Phase 0)

**Date**: 2026-07-15     **Commit**: `ba5ea17` (branch `sync/p1-self-sync`)

This is the P1 / Phase 0 gate for the Scind↔Xcind synchronization effort. It ran
Xcind's own [`engineering/maintenance/sync.md`](../../maintenance/sync.md) process
end-to-end across all LDS layers, reconciling the eng-docs (`engineering/`) against
the as-built code (`bin/`, `lib/xcind/`), with emphasis on the surface that changed
since the 2026-04-11 audit (XCIND_INSTANCE / worktree isolation, host-env symmetry /
XCIND_HOST_ENV_FILE, apex-url reporting, assigned-port lifecycle, hook lifecycle).

The audit fanned out across five subagents by LDS layer × code area (Reference,
Specs A = proxy/ports/labels/host-gateway, Specs B = config/context/env/naming,
Lifecycle, ADRs); a single coordinating pass verified each finding against code,
applied the fixes, and ran `make check`.

**Resolution rule applied:** where an eng-doc was wrong and the code was right, the
eng-doc was fixed (docs are canonical for Xcind). Where code appeared wrong against a
still-valid decision, it was filed as an implementation bug — **not** patched away by
rewriting a doc/ADR.

---

## Summary

| Category | Issues Found | Resolved (doc fixed) | Remaining (bug filed / follow-up) |
|----------|--------------|----------------------|-----------------------------------|
| CLI Reference | 4 | 4 | 0 |
| Config Reference | 8 | 8 | 0 |
| Specifications | 17 | 17 | 0 |
| Behaviors (Gherkin) | 0 | 0 | 0 |
| Cross-Links | 0 | 0 | 0 |
| ADRs | 2 | 2 | 2 (NEW-ADR-NEEDED, non-blocking) |
| Implementation bugs | 1 | 0 | 1 (filed below) |

`make check` result: **PASS** — shfmt + shellcheck clean, **189/189 tests green**,
and `git diff --name-only` shows changes only under `engineering/` (no code touched).

---

## What drifted, and what was fixed

### CLI Reference (`reference/cli.md`) — 4 fixed

1. Header said "five commands"; the tree ships **six** — `bin/xcind-prompt` had no
   section at all. → Corrected to six and added a full `## xcind-prompt` section
   (`--print {both|workspace|app|apex|apex-url}`, `--apex`, `--no-hyperlink`,
   `--detect`, the `XCIND_PROMPT_HYPERLINKS=0` env toggle, no-trailing-newline
   contract, Starship cost note).
2. `xcind-config` modes table omitted `--generate-starship[=FILE] [--format toml|nix]`.
   → Added row + usage examples.
3. `xcind-proxy init` `--proxy-domain` default listed as `localhost`. → `localhost.scind.io`.
4. (verified) `completion` note correctly lists the 5 commands + `xcind-app` alias and
   deliberately excludes `xcind-prompt` (no completion registered for it) — no change.

### Config Reference (`reference/configuration.md`) — 8 fixed

1. `XCIND_HOOKS_GENERATE` default listed 7 hooks; code has **8** (adds
   `xcind-discovery-hook`, `xcind-lib.bash:93`). → Added.
2. `XCIND_HOOKS_EXECUTE` default listed 2; code has **3** (adds
   `__xcind-hostenv-execute-hook`, `:94`). → Added.
3. `yq`-missing soft-skip list omitted `xcind-discovery-hook` (which soft-skips,
   `xcind-discovery-lib.bash:254-256`). → Added; also documented `XCIND_HOOKS_ALWAYS`
   (`xcind-assigned-hook`, `xcind-discovery-hook`) re-run behavior.
4. `XCIND_PROXY_DOMAIN` default `"localhost"` with an RFC-6761 rationale. → Changed to
   `"localhost.scind.io"` with the multi-label constraint + ADR-0016 rationale
   (single-label wildcard certs are untrusted by strict TLS clients).
5. Global-proxy-config table default domain — same fix.
6. **`XCIND_INSTANCE` / `XCIND_INSTANCE_AUTO`** were undocumented. → Added sections
   (precedence: explicit → worktree auto-detect unless `_AUTO=0`; folds into project
   name + workspace network only; participates in the cache SHA when non-empty).
7. **`XCIND_HOST_ENV_FILE` / `XCIND_HOST_ENV_MODE`** were undocumented. → Added sections
   (opt-in host-view dotenv; `own` default vs `block` region markers; `jq` required with
   assigned exports; relative paths resolve against app root).
8. (verified) The 2026-04-11 deliberately-undocumented internals
   (`XCIND_SUPPRESS_DEP_WARNING`, `XCIND_APP`, `XCIND_APP_ROOT`) remain intentionally out.

### Specifications — 17 fixed across 9 spec files

- **`proxy-infrastructure.md`**: default domain + rewritten DNS section
  (`localhost.scind.io` needs no local DNS; `localhost` only under `tls=disabled`); new
  **Multi-Label Domain Constraint** subsection (ADR-0016); added `xcind-proxy release`
  / `prune` to Lifecycle; `status` now documents assigned ports + auto-prune and the
  nested-`assigned_ports`-array JSON (was "flat").
- **`port-types.md`**: proxied hostname example → `localhost.scind.io`; added apex
  (headlining first-proxied-export) note (ADR-0017); added assigned-port **Lifecycle**
  (release/prune + auto-prune on init/up/status).
- **`environment-variables.md`**: added `XCIND_INSTANCE`/`_AUTO` to the behavioral-flags
  table; new **Host-View Env File** section (`XCIND_HOST_ENV_FILE`/`_MODE`); label
  examples → `localhost.scind.io`.
- **`configuration-schemas.md`**: Level-1 proxy var list gained the 4 TLS/HTTPS vars;
  Default-Hooks table gained `xcind-discovery-hook` + an EXECUTE-phase note (incl.
  `__xcind-hostenv-execute-hook`).
- **`naming-conventions.md`**: project-name table + new workspace-network-name table now
  fold `XCIND_INSTANCE`; new **Instance Token** subsection; hostname examples →
  `localhost.scind.io`.
- **`directory-structure.md`**: added `compose.discovery.yaml` (8th overlay) to the tree
  and Generated-Files table; added `config.json` under `.xcind/cache/{sha}/`.
- **`generated-override-files.md`**: cache-key list gained the `XCIND_INSTANCE` input;
  `XCIND_HOOKS_ALWAYS` note gained `xcind-discovery-hook`; clarified that
  `resolved-config.yaml`/`config.json` live in `.xcind/cache/{sha}/` (distinct from the
  `.xcind/generated/{sha}/` overlays); proxy example hostnames → `localhost.scind.io`.
- **`hook-lifecycle.md`**: cache-key-inputs prose gained `XCIND_INSTANCE`; EXECUTE
  built-in-hooks table gained `__xcind-hostenv-execute-hook`.
- **`workspace-lifecycle.md`** / **`application-lifecycle.md`**: intros + inspection
  sections now list the full subcommand sets (`workspace`: list/register/forget;
  `application`: ports/urls/exports); added a "Managing the Workspace Registry"
  subsection; annotated the `docker network rm dev-internal` example for the non-empty
  `XCIND_INSTANCE` (worktree) case.

### ADRs — 2 fixed

1. **ADR-0015** (Application Export Introspection) was `Proposed` but fully shipped
   (PR #69; `ports`/`urls`/`exports` in `bin/xcind-application`, `proxiedExports` in
   `xcind-config --json`). → Status flipped to **Accepted** (ADR body + `decisions/README.md`),
   with a note that only the *global* `xcind-proxy urls` follow-up remains proposed.
2. **ADR-0001** (Project-Name Isolation) described only `{workspace}-{application}` and
   never mentioned `XCIND_INSTANCE`. → Added a non-destructive "Update (worktree
   isolation)" note documenting the instance fold and pointing at Naming Conventions.

**Previously-flagged, now confirmed RESOLVED:** the 2026-04-11 audit's ADR-0009 concern
(TLS "Proposed + unimplemented") is gone — ADR-0009 is Accepted and TLS is fully
implemented (`XCIND_PROXY_TLS_MODE` auto/custom/disabled, mkcert→openssl fallback,
per-export `tls=`). The same audit's "hook-lifecycle understates the SHA cache key" and
"seven hooks" items are also resolved in the current tree (8 hooks enumerated; cache-key
list now complete after this pass's `XCIND_INSTANCE` addition).

---

## Verified-clean areas   ← P2+ may trust these

These eng-doc areas were checked against code this pass and found accurate (as amended
above). Downstream cross-project work may rely on them without re-verifying against code:

- **CLI surface** (`reference/cli.md`): every `bin/xcind-*` command, subcommand, flag,
  and default now matches captured `--help` — including `xcind-config` (`doctor [--json]`,
  `completion {bash|zsh}`, `--generate-*` incl. starship), `xcind-proxy`
  (init options, `release`, `prune`, `logs`), `xcind-workspace`
  (init/status/list/register/forget), `xcind-application`
  (init/status/list/ports/urls/exports), and the new `xcind-prompt`.
- **`xcind-config --json` contract** (`assignedExports`, `proxiedExports` with
  per-export `apex_url`/`apex_host` on the headlining export, and the always-present
  `apex` object) — matches `xcind-discovery-lib.bash` / proxy hook.
- **Config variables** (`reference/configuration.md`): all documented `XCIND_*` names,
  defaults, and the URL/router/apex template tables match code, now including
  `XCIND_INSTANCE`/`_AUTO`, `XCIND_HOST_ENV_FILE`/`_MODE`, and corrected hook-array and
  domain defaults.
- **Proxy / TLS / labels**: `proxy-infrastructure.md` and `docker-labels.md` generated
  `traefik.yaml`/`compose.yaml`/`dynamic/tls.yaml`, TLS resolution order, entrypoints,
  router naming, redirect middleware, and apex-label emission all match
  `xcind-proxy-lib.bash`.
- **Port types**: entry format, metadata keys (`type`, `tls`), fail-fast on unknown
  keys, assigned-port state file / flock / `MAX_ATTEMPTS=100`, and port inference match
  `xcind-proxy-lib.bash` + `xcind-assigned-lib.bash`.
- **Service discovery** (`environment-variables.md`, ADR-0018): injected
  `XCIND_{APP}_{EXPORT}_*` schema (proxied/apex/assigned, both-scheme `_HTTPS_*`/`_HTTP_*`,
  `_HOST_PORT`, `XCIND_WORKSPACE_NAME`, merged-last precedence) matches
  `xcind-discovery-lib.bash`.
- **Context detection** (`context-detection.md`): upward `$PWD` walk, `XCIND_APP_ROOT`
  trust, workspace parent-dir detection, late-bind self-declaration, app-name basename,
  and both error strings match `xcind-lib.bash`.
- **Hook lifecycle** (`hook-lifecycle.md`): all 8 GENERATE hooks + ordering,
  `XCIND_HOOKS_ALWAYS` (assigned + discovery) re-run semantics, `.complete`/`.hook-output`
  cache-hit rules, per-hook `yq` soft-skip/hard-fail policy, the `CONFIGURED`/`RESOLVED`
  "not yet implemented" status (no such arrays exist in code), and — after this pass —
  the full cache-key input set incl. `XCIND_INSTANCE` and the EXECUTE hostenv hook.
- **Generated overrides** (`generated-override-files.md`, `directory-structure.md`): the
  8-overlay set, merge order, and the cache/generated directory split.
- **Host-gateway** (ADR-0013): Docker Desktop / native-Linux / WSL2 detection,
  `XCIND_HOST_GATEWAY` override, `_ENABLED=0` opt-out, preserved `extra_hosts`, yq
  soft-skip — match `xcind-host-gateway-lib.bash`.
- **Naming** (`naming-conventions.md`): hostname/router/apex/alias templates and the
  now-documented `XCIND_INSTANCE` project-name/workspace-network fold match
  `xcind-naming-lib.bash` + `xcind-workspace-lib.bash`.
- **Workspace registry / application no-registry** (`workspace-lifecycle.md`,
  `application-lifecycle.md`): `workspaces.tsv` registry wiring
  (list/register/forget/`--prune`) and the intentional absence of an app registry match
  `xcind-registry-lib.bash` + `bin/*`.
- **ADRs 0002–0008, 0010–0014, 0016–0018**: Accepted + faithfully implemented; 0015 now
  Accepted; 0009 confirmed implemented.

## Unverified / low-confidence areas   ← P2+ must re-check against code

These were not fully exercised (read-only source audit, no runtime execution) or fall
just outside the audited seam. Treat eng-doc claims here as **provisional** and
re-verify against code at point of use downstream:

- **Runtime behavior not executed**: TLS handshake, live container env injection, actual
  proxy startup, and assigned-port allocation were verified by code/symbol reading, not
  by running the stack. Any P2+ finding that depends on *observed* runtime output should
  drive it, not trust the spec alone.
- **`xcind-application status --json` field list** (`reference/cli.md` "Status" prose):
  the `app`/`path`/`workspace`/`composeFiles`/…/`urls`/`total`/`running` fields were not
  re-verified field-by-field against current `bin/xcind-application`.
- **`xcind-discovery-hook` yq-missing classification detail**: confirmed it soft-skips;
  did not trace every downstream consequence of the skip.
- **Hard-fail yq behavior of `xcind-app-env-hook` / `xcind-proxy-hook` /
  `xcind-assigned-hook`**: asserted by the spec and internally consistent, but the
  print-to-stderr-and-`return 1` path was not directly opened for all three.
- **`docs/` (user-facing Diátaxis tree)** was out of scope for this gate; it is
  corroborating evidence only and was not reconciled here.
- **Internal/derived variables** (`XCIND_NO_REGISTRY`, `XCIND_WORKSPACE_NAME` injected,
  `XCIND_DOCKER_COMPOSE_OPTS`, `XCIND_ASSIGNED_LISTENERS_OVERRIDE`,
  `XCIND_HOOKS_SKIPPED_NO_YQ`, `XCIND_DEBUG`, proxy label/template internals): observed
  but intentionally not documented as user-facing config. `XCIND_DEBUG` (surfaced in
  `xcind-config --help`) is a candidate for future documentation.
- **Example-hostname consistency**: example domains were updated to the `localhost.scind.io`
  default where they implied "the default"; a few purely-illustrative examples elsewhere
  may still read `.localhost`. Cosmetic, not behavioral.

---

## Implementation bugs filed (code wrong vs valid decision)

1. **`xcind-workspace status` is instance-blind for the workspace network name.**
   `bin/xcind-workspace:330` computes `local network_name="${ws_name}-internal"` and does
   **not** fold `XCIND_INSTANCE`, whereas the runtime naming helper
   `__xcind-workspace-network-name` (`lib/xcind/xcind-workspace-lib.bash:31-38`) renders
   `{workspace}-{instance}-internal`. Run inside a git worktree with a non-empty instance
   token, `xcind-workspace status` therefore inspects/reports the wrong (un-instanced)
   network name and will show the workspace network as "not created" when it in fact
   exists under the instanced name. This is an **implementation bug** (code inconsistent
   with its own runtime naming introduced by BDS-25), not a doc defect — the specs were
   corrected to describe the *runtime* behavior, and `workspace-lifecycle.md`'s
   `docker network rm dev-internal` example was annotated for the instanced case.
   **Recommended fix (separate change):** have `xcind-workspace status` resolve
   `XCIND_INSTANCE` and reuse `__xcind-workspace-network-name` instead of hardcoding the
   suffix. Worth a Linear issue under the Xcind project.

## Recommended follow-ups (non-blocking; do not gate P2)

- **NEW-ADR-NEEDED ×2**: two recently-landed, load-bearing features have no ADR —
  `XCIND_INSTANCE` / git-worktree isolation (commit `ba5ea17`, BDS-25) and
  `XCIND_HOST_ENV_FILE` / host-env symmetry (commit `1d0b8c7`, BDS-24). Authoring these
  is a design act beyond a drift-reconciliation pass, so they are recorded here rather
  than written wholesale. (Note: the global-context worked example already frames
  `XCIND_INSTANCE` as a Scind **canon-change** learning for P6 — its Xcind ADR should be
  written with that in mind.)
- **Stale handoff status**: `implementation/handoffs/config-json-cache-staleness.md` and
  `assigned-hook-cache-hit-skip.md` are marked "Status: open" but their described
  behavior (post-hook `config.json` write; `XCIND_HOOKS_ALWAYS`) is implemented. Low
  priority doc-hygiene — left untouched as historical work records; flagged for a future
  update/refine pass.

---

## Done criteria

- [x] `sync.md` process completed across all LDS layers (reference, specs, behaviors,
      cross-links, ADRs).
- [x] `make check` passes — shfmt + shellcheck clean, 189/189 tests, no code changes.
- [x] Recently changed surface explicitly verified (XCIND_INSTANCE / worktree isolation,
      host-env symmetry, apex-url reporting, assigned-port lifecycle, hook lifecycle).
- [x] `p1-self-sync-report.md` written with the verified/unverified split.
- [x] Code-wrong-vs-decision case filed as an implementation bug, not a doc rewrite.
