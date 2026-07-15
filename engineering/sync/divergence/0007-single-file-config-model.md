# Divergence 0007: Single-file config model (workspace + app)

**Status**: Active
**Scind canon**: `docs/specs/configuration-schemas.md`, `docs/specs/directory-structure.md` (distinct `workspace.yaml` registry with `path:` indirection + app-owned `application.yaml`)
**Xcind reality**: one `.xcind.sh` format for both roles (`XCIND_IS_WORKSPACE=1` marker), apps discovered by directory walk, inline exports; `lib/xcind/xcind-config-lib.bash`, `engineering/specs/context-detection.md`
**Category**: Design
**Origin**: P3 L-0027

## What differs
Scind uses **two distinct config artifacts**: a `workspace.yaml` that acts as a
**registry** — listing apps by name with a `path:` field (name↔location indirection)
— and an app-owned `application.yaml` that travels with each app's repo. Xcind uses
a **single `.xcind.sh` format** for both roles, distinguished by an
`XCIND_IS_WORKSPACE=1` marker, and discovers apps by walking directories rather than
consulting a registry.

## Why Xcind diverges
One sourceable format for both roles (see 0003) minimized machinery: no registry to
maintain, no second schema, apps found by convention (directory walk + parent
marker). It matched Xcind's stateless, per-app posture.

## Why Scind should NOT simply adopt Xcind's approach
Scind's `workspace.yaml` registry buys **name↔location indirection** (`path:` can
point an app name at an arbitrary location) and a clean **app-ownership boundary**
(`application.yaml` lives with the repo it configures) that a directory-walk-plus-
marker forgoes. Collapsing to one file and convention-based discovery would drop
both. Directory-walk discovery does work end-to-end (Scind confirms this in
CANON-CONFIRM L-0020), but "works" is not "is a superset" — the registry is a real
capability.

## Canon-change test (required)
**Strongest canon-change argument:** "Directory-walk discovery works (L-0020), so the
`workspace.yaml` registry is redundant ceremony Scind could drop." **Why rejected
(adversarial re-check PERFORMED — P3 + P7):** the reviewer found this rides entirely
on the settled config-model divergence (0003), and the registry's `path:` indirection
plus repo-local `application.yaml` are genuine capabilities Xcind forgoes, not
ceremony. **Crucially, the one truly-open question** — whether apps should
*self-declare* their workspace (inverting Scind's workspace-owns-apps model) — is
**separately escalated as L-0037**, so no learning is buried here. Verdict:
**SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen if **L-0037** (app-self-declared workspace membership) resolves toward
inverting Scind's ownership model — that is a canon question owned by P6, tracked
independently of this entry. Otherwise consequence of 0003.

## Links
- Origin finding: P3 L-0027 (DIVERGENCE, adversarial re-check performed & survived);
  related open question L-0037 (ESCALATE → P6)
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind
  `configuration-schemas.md` / `directory-structure.md`
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL),
  `specs/context-detection.md` (PARTIAL), `specs/directory-structure.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off L-0027; cross-linked to L-0037
