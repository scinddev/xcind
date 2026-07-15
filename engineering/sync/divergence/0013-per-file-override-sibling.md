# Divergence 0013: Per-file `.override` sibling auto-derivation

**Status**: Active
**Scind canon**: `docs/specs/generated-override-files.md` (`overrides/{app}.yaml` with a preservation guarantee)
**Xcind reality**: auto-derives a per-file `.override` sibling next to each config file (e.g. auto-sources `.xcind.override.sh`); `lib/xcind/`, `engineering/behaviors/config-resolution/override-files.feature`
**Category**: Structural
**Origin**: P4 XA-0041

## What differs
Xcind derives an override by looking for a **sibling file** next to each config file
(e.g. `.xcind.override.sh` beside `.xcind.sh`), auto-sourcing it if present. Scind
provides overrides through a dedicated `overrides/{app}.yaml` location with an
explicit user-field preservation guarantee.

## Why Xcind diverges
Sibling auto-derivation is a lightweight, convention-based layout that fits Xcind's
directory-walk, source-what-you-find posture — no override directory to manage.

## Why Scind should NOT simply adopt Xcind's approach
Scind **already provides the equivalent capability** — `overrides/{app}.yaml`, with a
preservation guarantee that unrelated user-authored fields survive regeneration. The
per-file sibling is a **layout/mechanism choice**, not a new capability; Scind's
version is arguably cleaner (a single overrides location vs. siblings scattered
beside every config file).

## Canon-change test (required)
**Strongest canon-change argument:** "Sibling files are more discoverable / local
than a separate overrides dir." **Why rejected:** it is a layout preference over an
already-covered capability; the substantive override *guarantee* (preserve user
fields on rewrite) is a separate learning (L-0015 → P6). Impl-shape, low-risk
Structural, admitted on one line.

## Revisit conditions
None — Scind already has the capability; this is arrangement only.

## Links
- Origin finding: P4 XA-0041 (override-preservation guarantee is L-0015 → P6)
- Related ADR(s): Xcind ADR-0003 (pure overlay design)
- Correspondence-map row(s): `specs/generated-override-files.md` (PARTIAL); behavior
  `override-files.feature` (XCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off XA-0041; cross-linked to L-0015
