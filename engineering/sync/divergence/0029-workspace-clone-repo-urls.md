# Divergence 0029: `workspace clone` from repo URLs

**Status**: Active
**Scind canon**: `docs/reference/cli.md` (`workspace clone` from repository URLs; `repository:` field in config)
**Xcind reality**: no `repository` concept; workspaces are directories the user brings; `lib/xcind/`, `bin/xcind-workspace`
**Category**: Scope
**Origin**: P5 SA-0014

## What differs
Scind can bootstrap a workspace from **repository URLs** — a `workspace clone` command
plus a `repository:` field in config. Xcind has **no repository concept**: workspaces
are directories the user has already cloned/created; Xcind never fetches source.

## Why Xcind diverges
Xcind scoped itself as a "slim docker compose wrapper" over directories that already
exist. Source-fetching (git clone orchestration) was outside that boundary.

## Why Scind should NOT simply adopt Xcind's approach
Multi-repo workspace bootstrap is a **real, common dev-env need** (devcontainers,
meta, mrconfig all do it) and coheres with Scind's "bring up a whole workspace" value
proposition. Xcind's abstention is a deliberate **scope choice**, not evidence the
capability is wrong. Scind should keep it.

## Canon-change test (required)
**Strongest canon-change argument:** "Baking `repository:` URLs + a clone command into
a compose tool is mission-creep; Xcind stays cleanly out of source-fetching." **Why
rejected (adversarial re-check PERFORMED — P7):** multi-repo bootstrap is a genuine
need that fits Scind's broader orchestration scope; Xcind's narrower "slim wrapper"
framing is a valid scope decision, not a disproof of the capability. Verdict:
**SURVIVES-AS-DIVERGENCE** — a coherent optional convenience within Scind's model.

## Revisit conditions
If Xcind broadens scope to workspace bootstrap (unlikely given its "slim wrapper"
framing). Re-audit each round.

## Links
- Origin finding: P5 SA-0014
- Related ADR(s): Scind `reference/cli.md`; Xcind product `vision.md` ("slim docker
  compose wrapper" — narrowed scope)
- Correspondence-map row(s): `reference/cli.md` (PARTIAL), `product/vision.md`
  (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0014
