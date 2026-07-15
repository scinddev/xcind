# P5 — Capabilities Specified in Scind, Unexercised in Xcind

**Prerequisite**: [P2](./02-correspondence-map.md) correspondence map exists.
**Read first**: [`00-global-context.md`](./00-global-context.md) — §2, §5.
**Feeds**: P6 (reconciliation / Scind roadmap), P7 (divergence registry).

---

## Goal

Find every capability, behavior, or guarantee that **Scind's canon specifies**
but **Xcind has not exercised**, and label *why* — so we know which gaps are
"Xcind hasn't gotten to it yet," which are "Xcind chose not to," and which are
"Scind over-specified something unbuildable/unnecessary."

This serves your original goal #3. It is the "Scind is ahead" direction and the
sibling of [P4](./04-xcind-capabilities-missing-from-scind.md); run in parallel.

## The labels (every gap gets exactly one)

| Label | Meaning | Typical destination |
|-------|---------|--------------------|
| **NOT-IMPLEMENTED** | Xcind could/should build it; simply hasn't. | Xcind backlog / roadmap. |
| **IMPLEMENTED-UNTESTED** | Code exists but no behavior/test/spec exercises it — correctness unproven. | Xcind test/behavior backlog. |
| **DELIBERATELY-DEFERRED** | Xcind consciously scoped it out (for now or forever). | Divergence registry (P7). |
| **CANON-OVERREACH** | Building Xcind suggests the Scind spec is wrong, gold-plated, or unbuildable as written. | **Change Scind** (P6) — a reverse learning. |

`CANON-OVERREACH` is important: P5 is not only "Xcind is behind." Sometimes the
*spec* is the problem, and the correct fix is to trim/repair Scind canon.

## Starting set (from P2)

Every `SCIND-ONLY` and `PARTIAL` (Scind-richer) row is a candidate. Known seeds:

- **Scind-only specs**: `state-management`, `host-gateway-resolution`,
  `generated-manifest`, `shell-integration`.
  - *host-gateway-resolution* — Xcind has `xcind-host-gateway-lib.bash`, so this
    is likely `PARTIAL`/`IMPLEMENTED-UNTESTED`, not truly absent. Verify.
  - *shell-integration* — Scind ships `bash/zsh/fish` setup appendices; Xcind
    has bash + zsh completions. Fish? Prompt integration? Check coverage.
  - *generated-manifest* / *state-management* — do Xcind's generated overlays +
    registry satisfy these, or is there a real gap?
- **Scind-only ADR**: 0011 options-based-targeting — is targeting-by-options a
  concept Xcind implements under another name, or genuinely unbuilt?
- **Scind roadmap "Future" items** (`product/roadmap.md`): port-type plugins,
  application dependencies (`depends_on`), shared volumes, health checks. These
  are explicitly future — label `DELIBERATELY-DEFERRED` unless Xcind quietly has
  them.

## Research questions

For each Scind-specified capability:

1. **What exactly does Scind promise?** Quote the spec/ADR claim precisely.
2. **Does Xcind do it?** Search `bin/`/`lib/xcind/` and behaviors. Distinguish
   "no code" (NOT-IMPLEMENTED) from "code but no test/spec" (IMPLEMENTED-UNTESTED).
3. **If absent, is that a choice?** Look for ADRs, archive PRDs, or comments
   showing a deliberate scope decision (DELIBERATELY-DEFERRED).
4. **Is the spec itself sound?** Would building it as written be sensible, or
   does Xcind's experience suggest the spec is wrong (CANON-OVERREACH)?

## Subagent fan-out

By Scind capability cluster:

1. **State/generation agent** — state-management, generated-manifest vs Xcind's
   generation cache + registry + generated overlays.
2. **Networking/gateway agent** — host-gateway-resolution, two-layer networking
   guarantees vs `xcind-host-gateway-lib.bash` + proxy libs.
3. **Shell-integration agent** — shell setup + completions + prompt across
   bash/zsh/fish; Scind appendices vs Xcind `completion-*` + `xcind-prompt`.
4. **Targeting/CLI-semantics agent** — options-based-targeting (ADR-0011),
   up/down semantics (ADR-0010) vs Xcind CLI behavior.
5. **Roadmap-futures agent** — port-type plugins, depends_on, shared volumes,
   health checks: present in Xcind at all? Else DELIBERATELY-DEFERRED.

## Output artifact

Write **`engineering/sync/artifacts/scind-ahead.md`** + **`scind-ahead.json`**:

```json
{
  "id": "SA-0003",
  "capability": "Options-based targeting (scind ADR-0011)",
  "scind_ref": "docs/decisions/0011-options-based-targeting.md",
  "xcind_status": "NOT-IMPLEMENTED",
  "evidence": "No --target/selector flags in any bin/xcind-* parser; targeting is positional only.",
  "is_deliberate": "unknown",
  "recommendation": "Xcind backlog item OR confirm deferral with maintainer.",
  "confidence": "medium"
}
```

Flag every `IMPLEMENTED-UNTESTED` clearly — those are latent-bug risks (Scind
promises behavior Xcind has but never verifies). Flag every `CANON-OVERREACH`
for P6 as a reverse learning (change Scind, not Xcind).

## Done criteria

- [ ] Every `SCIND-ONLY`/`PARTIAL`(Scind-richer) P2 row + every Scind roadmap
      future item evaluated.
- [ ] Each gap labeled NOT-IMPLEMENTED / IMPLEMENTED-UNTESTED /
      DELIBERATELY-DEFERRED / CANON-OVERREACH with cited evidence.
- [ ] `CANON-OVERREACH` items handed to P6; `DELIBERATELY-DEFERRED` to P7.
- [ ] `scind-ahead.md` + `.json` committed.
