# Divergence 0008: `--check` runtime dependency checker

**Status**: Active
**Scind canon**: none — Scind is silent (a static Go binary has no external runtime deps)
**Xcind reality**: `--check` verifies `jq`/`yq`/`sha256sum` are present at runtime; `bin/xcind-config`, `lib/xcind/`
**Category**: Structural
**Origin**: P4 XA-0036

## What differs
Xcind ships a `--check` command that verifies its external runtime dependencies
(`jq`, `yq`, `sha256sum`) are installed. Scind specifies nothing analogous.

## Why Xcind diverges
Bash tools shell out to external binaries and fail cryptically when they are absent,
so an up-front dependency check is a real usability need for a shell program.

## Why Scind should NOT simply adopt Xcind's approach
A static Go binary **embeds** YAML/JSON parsing and hashing (via its pinned
libraries) and shells out to none of these tools. There is nothing to check — a
dependency checker would verify dependencies that do not exist in Scind's build. The
command is meaningless in the Go target.

## Canon-change test (required)
**Strongest canon-change argument:** "Runtime-environment health checks are generally
useful — Scind has `doctor`." **Why rejected:** Scind's `doctor` covers host/Docker/
DNS health; a *dependency* checker specifically for `jq`/`yq`/`sha256sum` only makes
sense when those are runtime deps, which the static binary makes them not. Pure
impl-shape (global-context §5 language boundary), low-risk Structural, admitted on
one line.

## Revisit conditions
None — resolves only if Scind abandoned static-binary distribution (it will not).

## Links
- Origin finding: P4 XA-0036
- Related ADR(s): none (consequence of 0001 Bash-vs-Go)
- Correspondence-map row(s): `reference/cli.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0036. Consequence of 0001.
