# Divergence 0009: `.xcind.sh` trust/security warning

**Status**: Active
**Scind canon**: none — Scind is silent (parsed YAML is never executed)
**Xcind reality**: `status`/`list` emit a trust/security warning before sourcing a foreign workspace's `.xcind.sh`; `bin/xcind-workspace`, `lib/xcind/`
**Category**: Structural
**Origin**: P4 XA-0037

## What differs
When Xcind inspects a workspace it did not create, it warns that `.xcind.sh` is
about to be **executed** (sourced), because inspecting a foreign workspace runs that
workspace's shell code. Scind emits no such warning.

## Why Xcind diverges
Xcind's config *is executable shell* (divergence 0003). Merely listing or checking
the status of a foreign workspace sources its `.xcind.sh`, so a trust warning is a
genuine safety affordance.

## Why Scind should NOT simply adopt Xcind's approach
Scind config is **parsed YAML, never executed** — inspecting a foreign workspace runs
no code, so there is nothing to warn about. Adding the warning would be cargo-culting
a mitigation for a hazard Scind's design does not have. This is a direct consequence
of the settled config-mechanism divergence.

## Canon-change test (required)
**Strongest canon-change argument:** none survives — the warning mitigates
arbitrary-code-execution-on-inspect, which exists only because config is sourced
shell. Scind avoids the hazard entirely by parsing, so the mitigation is moot.
Impl-shape, low-risk Structural, admitted on one line.

## Revisit conditions
None — resolves only if 0003 does. Derivative of the config-model divergence.

## Links
- Origin finding: P4 XA-0037
- Related ADR(s): none directly (consequence of 0003 / 0005)
- Correspondence-map row(s): `reference/cli.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0037. Child of 0003.
