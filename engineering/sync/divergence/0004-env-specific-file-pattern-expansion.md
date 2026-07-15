# Divergence 0004: Env-specific file-pattern expansion

**Status**: Active
**Scind canon**: `docs/reference/configuration.md`, `docs/specs/configuration-schemas.md` (typed named **flavors**, resolved by CLI/state)
**Xcind reality**: `${APP_ENV}` expansion inside Bash file-pattern arrays (e.g. `XCIND_COMPOSE_FILES`/`XCIND_APP_ENV_FILES`); `lib/xcind/xcind-config-lib.bash`, `engineering/behaviors/config-resolution/variable-expansion.feature`
**Category**: Structural
**Origin**: P3 L-0024

## What differs
For environment-specific configuration, Scind uses **typed named flavors** — declared
variant configs resolved by the CLI against persisted state. Xcind instead relies on
**shell variable expansion** (`${APP_ENV}`, `$(cmd)`) inside file-pattern arrays, so
a file list like `compose.${APP_ENV}.yaml` resolves at source-time from the ambient
environment.

## Why Xcind diverges
Expansion is only meaningful *because* config is a sourced Bash file (see 0003): once
you are in the shell, `${VAR}` interpolation and command substitution are free and
idiomatic. It gave Xcind environment-specific file selection with zero new machinery
and, crucially, **no state to persist** the active selection.

## Why Scind should NOT simply adopt Xcind's approach
Shell expansion is only available inside a sourced Bash file; in a compiled Go tool
it would mean re-introducing an embedded shell evaluator (the arbitrary-shell-in-
config shape that divergence 0003/0005 rejects). Scind's flavor system serves the
same need **declaratively, validated, and discoverable** — `scind flavor list` can
enumerate flavors, the schema validates them, and the resolver records the active
one. That is strictly better for a typed tool than string-substituting an ambient
env var. This divergence rides entirely on the settled config-model divergence 0003.

## Canon-change test (required)
**Strongest canon-change argument:** "Env-var-driven file selection is simpler than a
whole flavor subsystem — maybe flavors are over-built." **Why rejected:** the
flavor-vs-expansion question was seriously weighed and is preserved as the ESCALATE
**L-0039** (flavors' state-coupling may be heavier than needed) and the flavors
deferral **0024/SA-0008** — so the open question is *not* buried here. What remains at
0004 is purely the *mechanism*: shell expansion vs typed flavors. Expansion is a
direct Bash consequence, low-risk Structural, admitted on this justification. If
L-0039 later concludes flavors are gold-plated, that is a canon change owned by
P6 — it would not retroactively make Xcind's shell expansion adoptable.

## Revisit conditions
Reopen only in tandem with L-0039 (flavor state-coupling review) or 0024 — and even
then the outcome would change *flavors*, not promote shell expansion. Consequence of
0003; resolves only if 0003 does (it won't).

## Links
- Origin finding: P3 L-0024 (see also ESCALATE L-0039, flavors review)
- Related ADR(s): Xcind ADR-0005 (structure-vs-state — flavors dropped);
  Xcind ADR-0006 (config schemas)
- Correspondence-map row(s): `reference/configuration.md` (PARTIAL),
  `specs/configuration-schemas.md` (PARTIAL); behavior `variable-expansion.feature`
  (XCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off L-0024; cross-linked to L-0039, 0024
