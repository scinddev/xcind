# Divergence 0005: Config shell-injection/escaping surface

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/reference/configuration.md` (parsed YAML; config is never executed)
**Xcind reality**: `config.sh` written as a sourceable shell file with shell-escaped values; `lib/xcind/xcind-config-lib.bash`
**Category**: Structural
**Origin**: P3 L-0025

## What differs
Because Xcind persists resolved configuration as a **re-sourceable shell file**
(`config.sh`), it must shell-escape every value it writes so that re-sourcing does
not execute or mangle it — an entire injection/escaping surface. Scind persists
**parsed YAML** and never executes config, so the concern does not exist.

## Why Xcind diverges
It is a direct, unavoidable consequence of the sourceable-shell config model
(divergence 0003): if you round-trip config through `source`, you own the escaping
of everything you write. The language forced both the mechanism and its hazard.

## Why Scind should NOT simply adopt Xcind's approach
There is nothing to adopt — this is a *liability*, not a capability. The
shell-injection class exists **only because** config is persisted as executable
shell. Scind parses YAML and never `eval`s config, so it has no injection surface to
begin with. Importing Xcind's mechanism would mean importing the vulnerability.

## Canon-change test (required)
**Strongest canon-change argument:** none exists — no reading of "Scind should
persist config as an escaped shell file" survives contact, since it would strictly
*worsen* Scind's security posture. This is a pure Bash-ism (global-context §2a),
low-risk Structural, admitted on one line. The record exists so a future sync round
seeing Xcind's escaping code does not mistake it for a missing Scind capability.

## Revisit conditions
None — resolves only if 0003 does (it won't). Purely derivative of the config-model
divergence.

## Links
- Origin finding: P3 L-0025
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Xcind ADR-0006 (config schemas)
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL),
  `reference/configuration.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off L-0025. Child of 0003.
