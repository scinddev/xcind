# Divergence 0007: Single-file config model (workspace + app)

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/specs/directory-structure.md` (distinct `workspace.yaml` roster with workspace-relative `path:` values + app-owned `application.yaml`)
**Xcind reality**: one `.xcind.sh` format for both roles (`XCIND_IS_WORKSPACE=1` marker), apps discovered by directory walk, inline exports; `lib/xcind/xcind-config-lib.bash`, `engineering/specs/context-detection.md`
**Category**: Design
**Origin**: P3 L-0027

## What differs
Scind uses **two distinct config artifacts**: a `workspace.yaml` that owns and
enumerates the application roster by name with workspace-relative `path:` values,
and an app-owned `application.yaml` that travels with each app's repo. Xcind uses a
**single `.xcind.sh` format** for both roles, distinguished by an
`XCIND_IS_WORKSPACE=1` marker, and discovers apps by walking directories rather than
consulting a roster.

## Why Xcind diverges
One sourceable format for both roles (see 0003) minimized machinery: no registry to
maintain, no second schema, apps found by convention (directory walk + parent
marker). It matched Xcind's stateless, per-app posture.

## Why Scind should NOT simply adopt Xcind's approach
Scind's `workspace.yaml` provides an **authoritative, named application roster**
and a clean **app-ownership boundary** (`application.yaml` lives with the repo it
configures) that a directory-walk-plus-marker forgoes. The current canon permits
workspace-relative `path:` values; it does not support the previously claimed
arbitrary-location indirection. Collapsing to one file and convention-based
discovery would still drop authoritative enumeration. Directory-walk discovery
does work end-to-end (Scind confirms this in CANON-CONFIRM L-0020), but "works" is
not "is a superset" — the roster is a real capability.

## Canon-change test (required)
**Strongest canon-change argument:** "Directory-walk discovery works (L-0020), so the
`workspace.yaml` registry is redundant ceremony Scind could drop." **Why rejected
(adversarial re-check PERFORMED — P3 + P7):** the reviewer found this rides entirely
on the settled config-model divergence (0003), and the authoritative roster plus
repo-local `application.yaml` are genuine capabilities Xcind forgoes, not ceremony.
The 2026-08 escalation decision separately accepted external `path:` support as a
canon change and retained app-side self-declaration as divergence 0038. Neither
outcome makes the single-file model a superset. Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
The 2026-08 escalation decision resolved L-0037: Scind keeps workspace-owned
membership, while external `path:` support proceeds as a separate canon change.
Reopen if divergence 0038 later resolves toward app-side ownership. Otherwise this
entry remains a consequence of 0003.

## Links
- Origin finding: P3 L-0027 (DIVERGENCE, adversarial re-check performed & survived);
  related L-0037 decision recorded in divergence 0038
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind
  `configuration-schemas.md` / `directory-structure.md`
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL),
  `specs/context-detection.md` (PARTIAL), `specs/directory-structure.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off L-0027; cross-linked to L-0037
