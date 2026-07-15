# Divergence 0023: Computed generated manifest

**Status**: Active
**Scind canon**: `docs/specs/generated-manifest.md` (a computed workspace-wide `manifest.yaml`)
**Xcind reality**: no manifest file — topology derived on demand via `xcind-application …` + `xcind-config --json`; `engineering/specs/application-lifecycle.md` ("no separate state store, no manifest")
**Category**: Design
**Origin**: P5 SA-0007

## What differs
Scind computes and persists a workspace-wide `manifest.yaml` describing the full
topology. Xcind has **no manifest**: it derives topology **on demand** from
`xcind-application` + `xcind-config --json` whenever it is needed.

## Why Xcind diverges
Xcind is deliberately manifest-free (ADR-0005 posture, `application-lifecycle.md`): a
persisted computed file is one more thing to keep fresh, and Xcind can recompute the
same view on demand from live config.

## Why Scind should NOT simply adopt Xcind's approach
The manifest's one **non-redundant** property is being readable **at rest, without
Docker running** — a legitimate file-based integration surface for Scind's external
ecosystem (e.g. Servlo, DNS-updaters) that on-demand-JSON-from-a-running-binary and
container labels do not provide. That is a real design intent, not a defect Xcind
exposed. Xcind's on-demand derivation is a valid choice for a tool with no such
ecosystem.

## Canon-change test (required)
**Strongest canon-change argument (the reviewer's second-closest call):** "Xcind
never persists a manifest and is fine — it's redundant computed state that can go
stale, and Scind *already* has topology in Docker labels **and** could serve `--json`,
so `manifest.yaml` is a third redundant surface for the same data." **Why rejected
(adversarial re-check PERFORMED — P7):** the at-rest, Docker-not-running readability
is a property neither labels nor a running-binary `--json` provides — a genuine
integration surface. Verdict: **SURVIVES-AS-DIVERGENCE.** ⚠ **Soft P6 note (carry
forward):** re-examine whether a *persisted computed* manifest earns its keep once
labels + on-demand JSON exist — Scind now carries three surfaces for one dataset.
This is the manifest-necessity question also tracked as ESCALATE **L-0035**.

## Revisit conditions
Reopen with the L-0035 manifest-necessity ESCALATE, or if Scind consolidates its
three topology surfaces. Re-audit each round (Design entry).

## Links
- Origin finding: P5 SA-0007; manifest-necessity also ESCALATE L-0035 (→ P6).
  Cross-listed with divergences 0017, 0020, 0026.
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `generated-manifest.md`
- Correspondence-map row(s): `specs/generated-manifest.md` (SCIND-ONLY)
- Reconciliation-ledger ID(s): P6 keys off SA-0007; cross-linked to L-0035
