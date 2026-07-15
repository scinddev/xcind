# Divergence 0032: Visibility (public/protected) labels

**Status**: Active
**Scind canon**: `docs/specs/port-types.md`, `docs/specs/docker-labels.md` (`scind.export.{n}.proxy.{proto}.visibility` / `port.{n}.visibility` = `public|protected` advisory metadata for external tools)
**Xcind reality**: emits no visibility labels; **test-enforces rejection** of the `visibility` attribute; `test/test-xcind-proxy.sh:721-723`
**Category**: Scope
**Origin**: P5 SA-0019

## What differs
Scind emits per-export/port **visibility** labels (`public|protected`) in Docker
labels so external tools can filter services by intent. Xcind emits **no** visibility
labels and **test-enforces rejection** of the `visibility` attribute.

## Why Xcind diverges
Xcind carries no access-intent metadata — it emits the routing labels it needs and
rejects `visibility` to keep the label surface minimal and enforced.

## Why Scind should NOT simply adopt Xcind's approach
Scind names a **concrete consumer**: `port-types.md:43` says visibility rides in
Docker labels *"enabling external tools (such as Servlo) to distinguish public and
protected services for display or filtering."* It is **cheap intent-metadata with a
stated integration purpose**. Xcind rejecting it is a valid "we don't carry that
metadata" scope choice — it does **not** prove Scind should drop a label that serves a
named external tool.

## Canon-change test (required)
**Strongest canon-change argument (strongest form, special scrutiny):** "Scind's own
`port-types.md:41` admits *'Visibility does not change Scind's core behavior'* — it
enforces nothing, defaults to `protected`, and Xcind test-rejects it, so an
access-control-*named* label that controls no access looks like speculative
metadata." **Why rejected (adversarial re-check PERFORMED — P7):** the label has a
**named downstream consumer (Servlo)** for display/filtering — it is advisory
integration metadata, not access-control masquerading. Verdict:
**SURVIVES-AS-DIVERGENCE.** *Soft P6 note:* the "access-control" **framing is a
misnomer** — it is advisory display-metadata; worth a **wording clarification in
Scind**, but the label itself is legitimate and Xcind's rejection does not refute it.

## Revisit conditions
If Scind's external ecosystem (Servlo et al.) drops the need, or if Scind reframes/
removes the label. Re-audit each round.

## Links
- Origin finding: P5 SA-0019; confirms P4 reverse-gap RG-0002 (visibility labels
  dropped). Related ESCALATE L-0034 (per-export tls-key vs protocol+visibility).
- Related ADR(s): Scind `port-types.md` / `docker-labels.md` (visibility labels)
- Correspondence-map row(s): `specs/docker-labels.md` (DIVERGED — visibility is the
  Scind-only half → P5/P3), `specs/port-types.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0019; naming-clarification note → P6
