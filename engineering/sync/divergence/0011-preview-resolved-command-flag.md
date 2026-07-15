# Divergence 0011: `--preview` resolved-command flag

**Status**: Active
**Scind canon**: `docs/specs/shell-integration.md` (`scind compose-prefix` exposes the resolved command)
**Xcind reality**: `--preview` flag prints the resolved docker compose command without running it; `bin/xcind-compose`
**Category**: Structural
**Origin**: P4 XA-0039

## What differs
Xcind exposes the fully-resolved docker compose command via a `--preview` flag on
its compose wrapper. Scind exposes the same capability through a dedicated
`compose-prefix` command.

## Why Xcind diverges
Xcind's compose wrapper is a single binary (`bin/xcind-compose`); attaching a
`--preview` flag to it was the natural placement given that architecture.

## Why Scind should NOT simply adopt Xcind's approach
The *capability* — see the resolved command before running it — is **already covered
by Scind's `compose-prefix`**. Xcind's `--preview` is merely a different **flag
placement / arrangement detail**, not a new capability. There is nothing here for
Scind to adopt; it already has the function under a different surface.

## Canon-change test (required)
**Strongest canon-change argument:** "Flag-on-the-wrapper is more discoverable than a
separate command." **Why rejected:** this is a CLI-arrangement preference, not a
capability gap — and Scind's surface (`compose-prefix`) is itself entangled with the
shell-function architecture divergence (see 0035 / SA-0026, an open ESCALATE). The
substantive question (shell-function vs binary) is escalated there; `--preview`
placement is pure impl-shape. Low-risk Structural, admitted on one line.

## Revisit conditions
Fold into the SA-0026 ESCALATE resolution (shell-function vs binary compose
architecture) if that changes Scind's compose surface. Otherwise none.

## Links
- Origin finding: P4 XA-0039
- Related ADR(s): none; relates to SA-0026 ESCALATE (compose architecture)
- Correspondence-map row(s): `specs/shell-integration.md` (SCIND-ONLY),
  `reference/cli.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0039; see also SA-0026
