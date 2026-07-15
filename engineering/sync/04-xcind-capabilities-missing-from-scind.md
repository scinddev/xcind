# P4 — Capabilities in Xcind, Absent from Scind

**Prerequisite**: [P2](./02-correspondence-map.md) correspondence map exists.
**Read first**: [`00-global-context.md`](./00-global-context.md) — §2 (operating
model), §4 (seed divergences), §5 (Go/Bash — do not report language artifacts).
**Feeds**: P6 (promote to canon or reconcile), P7 (record as divergence).

---

## Goal

Find every capability, feature, flag, behavior, or convention that **Xcind
actually implements** but **Scind's canon does not specify**, and decide (as a
recommendation) whether each should be **promoted into Scind** or **recorded as
an intentional Xcind-only divergence**.

This serves your original goal #2. It is the "Xcind is ahead" direction of the
gap analysis. Its sibling is [P5](./05-scind-capabilities-unexercised-in-xcind.md)
(the "Scind is ahead" direction); run them in parallel.

## Starting set (from P2)

Every `XCIND-ONLY` row in the correspondence map is a candidate. Known seeds:

- **Xcind-only ADRs**: 0012 unified-generate-flag-semantics, 0015
  application-export-introspection, 0016 proxy-domain-wildcard-constraint, 0018
  service-discovery-env-injection. *(0014 two-track-documentation is a
  docs-process decision, likely `PROCESS`/DIVERGENCE, not a product capability —
  confirm.)*
- **Xcind-only specs**: `hook-lifecycle`, `application-lifecycle`.
- **Xcind-only behaviors**: the extra `.feature` files under `proxy/`,
  `workspace/`, `config-resolution/`.

But P2's doc-level map is not enough — Xcind may implement capabilities that
aren't even in its **own** eng-docs. So also mine **as-built code directly**.

## Research questions

For each candidate capability:

1. **Is it real and reachable?** Cite the `bin/`/`lib/xcind/` code and, ideally,
   a behavior/test that exercises it.
2. **Is it truly absent from Scind?** Re-check Scind canon by *topic* (P2 rows
   can miss cross-layer coverage — a capability may live in a Scind spec even if
   no ADR names it).
3. **Why does it exist?** Emergent need during implementation? User request?
   Bash-specific workaround?
4. **Should Scind adopt it?** Apply the §2 rule:
   - Genuinely improves the *design* → **PROMOTE** (recommend a Scind addition).
   - Only makes sense for the Bash impl / is a compromise → **DIVERGENCE**.
   - Ambiguous / needs a human product call → **ESCALATE**.

   **DIVERGENCE must be earned** (global-context §2a): to choose it you must be
   able to state why Scind should not adopt the capability. If you cannot, it is a
   PROMOTE or ESCALATE — never a silent divergence. Design/Scope divergences get
   the P7 adversarial re-check before they may be recorded.

## Mine the code, not just the docs

Enumerate the real surface and diff it against Scind canon:

- **Every subcommand and flag**: `bin/xcind-{compose,config,proxy,workspace,application,prompt}`
  `--help` and their argument parsers. The 2026-04-11 audit found `release` and
  `prune` subcommands undocumented even in Xcind — expect Scind gaps too.
- **Every user-facing variable**: `XCIND_*` in `lib/xcind/*.bash` (e.g.
  `XCIND_ASSIGNED_EXPORTS`, `XCIND_PROXY_AUTO_START`, `XCIND_INSTANCE`,
  `XCIND_HOST_ENV_FILE`, `XCIND_TOOLS`). For each, is the *concept* in Scind?
- **Every generated overlay**: the `compose.*.yaml` files Xcind emits and their
  hooks — does Scind's `generated-override-files` / `generated-manifest` cover
  the same set?
- **Every hook**: the seven-hook lifecycle — is hook extensibility a Scind
  concept at all?

## Subagent fan-out

By subsystem, each owning "enumerate Xcind's real capability, then diff vs
Scind":

1. **CLI-surface agent** — all subcommands/flags across all `bin/` entrypoints.
2. **Proxy/export agent** — proxy, exports (proxied + assigned), TLS, apex,
   wildcard-domain, service-discovery env injection (ADRs 0016, 0017, 0018).
3. **Identity/isolation agent** — `XCIND_INSTANCE`, worktree isolation, project
   naming, workspace networking, app/workspace identity.
4. **Hooks/generation agent** — hook lifecycle, generation cache, generated
   overlays, `unified-generate-flag` (ADR-0012, 0015).
5. **Config/env agent** — config resolution, env files, host-env symmetry,
   variable expansion, `.xcind.sh` discovery.

Each returns capability records; a synthesis pass de-dupes and applies the
PROMOTE/DIVERGENCE/ESCALATE recommendation consistently.

## Output artifact

Write **`engineering/sync/artifacts/xcind-ahead.md`** + **`xcind-ahead.json`**:

```json
{
  "id": "XA-0004",
  "capability": "XCIND_INSTANCE per-worktree isolation token",
  "xcind_evidence": ["lib/xcind/xcind-naming-lib.bash", "engineering/decisions/..."],
  "scind_coverage": "absent",
  "why_it_exists": "Running the same repo from multiple git worktrees collided on compose project name + network.",
  "recommendation": "PROMOTE",
  "rationale": "Multi-environment-on-one-host is Scind's core promise; worktree collision is a real design gap, not a Bash quirk.",
  "target_scind_change": "New ADR + isolation spec; touches project-name-isolation ADR-0001.",
  "confidence": "high"
}
```

Exclude pure language/build artifacts (global-context §5). If unsure whether
something is a capability or a Bash-ism, mark `ESCALATE` rather than guessing.

## Done criteria

- [ ] Every `XCIND-ONLY` P2 row evaluated **and** the code surface enumerated
      beyond the docs.
- [ ] Each capability: real+cited, confirmed absent from Scind, with a
      PROMOTE / DIVERGENCE / ESCALATE recommendation + rationale.
- [ ] `PROMOTE` items name the target Scind change (hand-off to P6).
- [ ] `DIVERGENCE` items are registry-ready (hand-off to P7).
- [ ] `xcind-ahead.md` + `.json` committed.
