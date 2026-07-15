# Divergence 0021: Options-based targeting by name

**Status**: Active
**Scind canon**: `docs/decisions/0011-options-based-targeting.md` (`--workspace`/`--app` name-targeting from anywhere, paired with context auto-detection)
**Xcind reality**: no targeting flags — targets by cwd upward-walk + positional `[DIR]` + `XCIND_APP_ROOT`; `engineering/specs/context-detection.md`, `bin/xcind-*`
**Category**: Scope
**Origin**: P5 SA-0001

## What differs
Scind (ADR-0011) supports targeting a workspace or app **by name from anywhere**
(`--workspace foo` / `--app bar`), backed by its registry. Xcind has **zero
targeting flags**: it resolves context by walking up from the current directory,
accepts a positional `[DIR]`, and honors `XCIND_APP_ROOT` — you must be in or point
at the directory. No Xcind ADR records the deviation.

## Why Xcind diverges
Xcind has no persisted name→location registry (see divergence 0017), so
target-by-name has nothing to resolve against. Context-by-location (walk + `[DIR]`)
was the natural, stateless targeting model and matches git/docker-compose ergonomics.

## Why Scind should NOT simply adopt Xcind's approach
Scind's `workspace.yaml` registry makes name-targeting-from-anywhere a **coherent
superset** capability: it can do everything Xcind's location-based targeting does
*plus* resolve a bare name against the registry. Narrowing Scind to context-only
would drop a real capability. Note ADR-0011 pairs flags *with* auto-detection — Scind
already has the context path too; the flags are additive.

## Canon-change test (required)
**Strongest canon-change argument:** "ADR-0011 is a thin stub and Xcind's cwd-walk
proves flag-targeting is unnecessary typing." **Why rejected (adversarial re-check
PERFORMED — P7):** the reviewer confirmed Scind ships context-detection too *and* has
a real registry that makes name-targeting a coherent superset Xcind genuinely lacks —
Scind is a superset, not over-specified. Xcind chose the context-only subset because
it lacks the registry. Verdict: **SURVIVES-AS-DIVERGENCE.** *Soft P6/Xcind note:
Xcind should file an ADR recording the deliberate targeting-model deviation.*

## Revisit conditions
If Xcind adds a name→location registry, target-by-name becomes buildable and this may
resolve. Re-audit each round.

## Links
- Origin finding: P5 SA-0001
- Related ADR(s): Scind ADR-0011 (options-based targeting) — SCIND-ONLY, no Xcind
  analog (recommend Xcind file one)
- Correspondence-map row(s): ADR-topic "Options-based targeting" (SCIND-ONLY);
  `reference/cli.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0001. Tied to divergence 0017.
