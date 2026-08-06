# Divergence 0037: Workspaceless standalone application mode

**Status**: Active
**Scind canon**: `docs/specs/context-detection.md`, `docs/specs/directory-structure.md`, `docs/reference/cli.md` (a `workspace.yaml` boundary is mandatory; a single-app workspace uses `path: .`)
**Xcind reality**: `lib/xcind/xcind-naming-lib.bash`, `xcind-workspace-lib.bash`, `xcind-discovery-lib.bash`; `engineering/specs/application-lifecycle.md` (workspaceless mode is the default)
**Category**: Design
**Origin**: P4 XA-0021

## What differs
Scind requires every application to belong to a workspace, including the supported
single-app `workspace.yaml` form with `path: .`. Xcind defaults to a truly
workspaceless application and branches its naming, hostname, network, and discovery
behavior when no workspace exists.

## Why Xcind diverges
Xcind optimizes for a standalone repository with no workspace setup. It accepts the
permanent dual-mode identity and network surface to make that zero-ceremony path the
default.

## Why Scind should NOT simply adopt Xcind's approach
Scind keys its environment-isolation model on the workspace and uses the mandatory
workspace boundary to prevent context hijacking by nested or unrelated application
files. A generated five-line single-app workspace gives users the same one-repo
outcome without adding workspaceless branches to every identity-sensitive feature.

## Canon-change test (required)
**Strongest canon-change argument:** Xcind proves that a zero-workspace onboarding
path is practical and better matches what users expect when they try one repository.
**Why rejected (adversarial re-check in the 2026-08 escalation decision brief):**
Xcind also demonstrates the cost: dual naming templates, hostnames, apex behavior,
networks, and discovery rules. Scind can scaffold `path: .` and preserve one
workspace-keyed model. Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen after real Scind onboarding reports show that the scaffolded single-app
workspace remains material friction, or if Scind chooses to target Xcind's
standalone-by-default users.

## Links
- Origin finding: P4 XA-0021
- Related ADR(s): Scind ADR-0001 (workspace isolation), ADR-0016 (instance identity)
- Correspondence-map row(s): `specs/context-detection.md` (PARTIAL), `specs/directory-structure.md` (PARTIAL), `specs/naming-conventions.md` (PARTIAL)
- Reconciliation-ledger ID(s): RL-103
