# Divergence 0014: `XCIND_ADDITIONAL_CONFIG_FILES` includes

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md` (typed schema layering composes config)
**Xcind reality**: `XCIND_ADDITIONAL_CONFIG_FILES` sources extra config files as a Bash include mechanism; `lib/xcind/xcind-config-lib.bash`
**Category**: Structural
**Origin**: P4 XA-0042

## What differs
Xcind lets a config declare `XCIND_ADDITIONAL_CONFIG_FILES` — a list of extra files
to **source** — as an include/composition mechanism. Scind composes configuration
through **typed schema layering** (workspace → app → override), not by sourcing
arbitrary files.

## Why Xcind diverges
When config is sourced Bash (0003), "include more config" is just "source these
files" — the idiomatic, zero-machinery composition primitive.

## Why Scind should NOT simply adopt Xcind's approach
Scind's typed schema layering **already composes configuration** in a validated,
well-defined precedence order. A "source these files" include recreates exactly the
**arbitrary-shell-in-config** shape (and injection surface, 0005) that the settled
typed-YAML divergence rejects. Adopting it would trade a validated layering model for
untyped, executable includes.

## Canon-change test (required)
**Strongest canon-change argument:** "Explicit includes give users more composition
power than fixed layering." **Why rejected:** the power is *arbitrary shell sourcing*,
a liability; Scind's typed layering delivers composition safely. This is the same
Bash-ism family as 0003/0005/0012. Impl-shape, low-risk Structural, admitted on one
line.

## Revisit conditions
None — resolves only if 0003 does. Derivative of the config-model divergence.

## Links
- Origin finding: P4 XA-0042
- Related ADR(s): Xcind ADR-0006 (three configuration schemas)
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0042. Child of 0003.
