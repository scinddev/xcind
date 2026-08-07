# Divergence 0038: Application-side workspace self-declaration

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/specs/directory-structure.md`, `docs/specs/context-detection.md` (`workspace.yaml` owns and enumerates the application roster)
**Xcind reality**: `lib/xcind/xcind-lib.bash`, `engineering/specs/context-detection.md`, `engineering/specs/application-lifecycle.md` (an app can set `XCIND_WORKSPACE` and late-bind itself to a workspace identity)
**Category**: Design
**Origin**: P4 XA-0022 / P3 L-0037

## What differs
Scind declares workspace membership from the workspace: `workspace.yaml` enumerates
each application. Xcind also lets a workspaceless application's committed
`.xcind.sh` set `XCIND_WORKSPACE`; late binding then gives the application a
workspace identity without a parent workspace registry.

The inversion is bounded: self-declaration is a **fallback for applications with
no discovered workspace**, not an override. An application nested inside a
workspace directory cannot rename the workspace it belongs to —
`__xcind-guard-discovered-workspace` restores the discovered name and warns
(2026-08; the guard was missing until then, so the app value silently won).

## Why Xcind diverges
Xcind is per-app, registry-light, and workspaceless by default. App-side declaration
lets a standalone repository join a conceptual workspace network without adding a
physical parent workspace or an authoritative application roster.

## Why Scind should NOT simply adopt Xcind's approach
Scind's orchestrator must enumerate applications for workspace-wide lifecycle
commands, roster validation, and the aggregated manifest. App-side volunteers are
not discoverable without an unbounded filesystem scan. Workspace-declared external
paths can support repositories outside the workspace tree while preserving an
authoritative roster; ownership inversion adds no required capability.

## Canon-change test (required)
**Strongest canon-change argument:** Xcind proves that inverted membership works and
serves conceptual workspaces whose applications do not share a directory tree.
**Why rejected (adversarial re-check in the 2026-08 escalation decision brief):**
the useful external-repository case can flow to Scind as support for external
`applications.{name}.path` values while membership remains workspace-declared.
Inversion would make Scind's orchestrator roster and at-rest manifest unenumerable.
Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen if Scind drops authoritative workspace-wide enumeration, or if external
workspace-declared paths fail to serve the conceptual-workspace use case. Also
re-evaluate if divergence 0037 resolves toward a workspaceless Scind mode.

## Links
- Origin finding: P4 XA-0022; P3 L-0037
- Related ADR(s): Xcind ADR-0005 (structure vs state); Scind workspace/application configuration model
- Correspondence-map row(s): `specs/context-detection.md` (PARTIAL), `specs/directory-structure.md` (PARTIAL), `behaviors/workspace/self-declaration.feature` (XCIND-ONLY)
- Reconciliation-ledger ID(s): RL-098, RL-104
