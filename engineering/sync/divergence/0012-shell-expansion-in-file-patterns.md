# Divergence 0012: Shell expansion in file patterns

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/reference/configuration.md` (typed **flavor** system for env-driven file selection)
**Xcind reality**: `${VAR}` / `$(cmd)` expansion inside file-pattern arrays; `lib/xcind/xcind-config-lib.bash`, `engineering/behaviors/config-resolution/variable-expansion.feature`
**Category**: Structural
**Origin**: P4 XA-0040

## What differs
Xcind allows shell parameter expansion `${VAR}` and command substitution `$(cmd)`
inside its file-pattern arrays, so which files are selected depends on the ambient
shell environment. Scind's typed **flavor** system is the declarative equivalent for
env-driven file selection.

## Why Xcind diverges
Config is sourced Bash (0003), so `${VAR}`/`$(cmd)` are free and idiomatic — the
zero-machinery way to make file selection environment-sensitive.

## Why Scind should NOT simply adopt Xcind's approach
Shell expansion reintroduces the **arbitrary-shell-in-config** shape (and the
injection surface, 0005) that Scind's typed-YAML divergence deliberately rejects.
Scind's flavor system is the intentional, validated, discoverable equivalent — it
selects files by named variant, resolved and recorded, without evaluating shell.
Adopting expansion would undo a settled design choice.

## Canon-change test (required)
**Strongest canon-change argument:** "Expansion is more flexible than predeclared
flavors." **Why rejected:** the flexibility is arbitrary shell evaluation, a
liability for a typed tool, and the flavor-vs-expansion trade is already tracked as
the ESCALATE **L-0039** (whether flavors' state-coupling is heavier than needed) —
so the open question is not buried here. This entry is the *mechanism* twin of
divergence 0004; both ride on 0003. Impl-shape, low-risk Structural.

## Revisit conditions
Reopen only with L-0039 / divergence 0004 (flavors review) — and even then the change
would land on *flavors*, not promote shell expansion.

## Links
- Origin finding: P4 XA-0040 (see also L-0024 / divergence 0004, and ESCALATE L-0039)
- Related ADR(s): Xcind ADR-0005 (flavors dropped); Xcind ADR-0006 (config schemas)
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL); behavior
  `variable-expansion.feature` (XCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off XA-0040; cross-linked to L-0024, L-0039
