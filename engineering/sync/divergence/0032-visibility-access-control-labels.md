# Divergence 0032: Visibility labels and label-schema shape

**Status**: Active
**Scind canon**: `docs/specs/port-types.md`, `docs/specs/docker-labels.md` (`scind.export.{n}.proxy.{proto}.visibility` / `port.{n}.visibility` = `public|protected` advisory metadata for external tools)
**Xcind reality**: emits no visibility or assigned-port labels, drops Scind's `proxy.` label segment, and **test-enforces rejection** of the `visibility` attribute; `lib/xcind/xcind-proxy-lib.bash:610-651`, `test/test-xcind-proxy.sh:721-723`
**Category**: Scope
**Origin**: P5 SA-0019

## What differs
Scind emits per-export/port **visibility** labels (`public|protected`) in Docker
labels so external tools can filter services by intent. Its proxied-export schema
uses a `proxy.` segment (for example, `scind.export.{n}.proxy.http.url`) and its
separate assigned-port schema emits `port.{n}.assigned` labels. Xcind emits no
visibility or assigned-port labels, test-enforces rejection of `visibility`, and
flattens proxied labels by dropping the segment (for example,
`xcind.export.{n}.http.url`).

## Why Xcind diverges
Xcind carries no access-intent metadata and emits labels only for proxied routing.
Because it emits no assigned-port labels in the same namespace, it does not need
Scind's `proxy.` segment to distinguish the two label families.

## Why Scind should NOT simply adopt Xcind's approach
Scind names a **concrete consumer**: `port-types.md:43` says visibility rides in
Docker labels *"enabling external tools (such as Servlo) to distinguish public and
protected services for display or filtering."* It is **cheap intent-metadata with a
stated integration purpose**. Xcind rejecting it is a valid "we don't carry that
metadata" scope choice — it does **not** prove Scind should drop a label that serves a
named external tool. Scind's segmented schema also separates proxied-export labels
from assigned-port labels. Xcind's flatter proxy-only schema does not show that the
segmentation is unnecessary in Scind.

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
If Scind's external ecosystem (Servlo et al.) drops the visibility need, or if a
tool must consume both `scind.*` and `xcind.*` labels and needs naming convergence,
reopen this entry. A second consumer that needs visibility enforcement rather than
display also reopens the canon design question. Re-audit each round.

## Links
- Origin finding: P5 SA-0019; confirms P4 reverse-gap RG-0002 (visibility labels,
  dropped `proxy.` segment, and absent assigned-port labels). L-0034 was resolved by
  the 2026-08 escalation decision brief.
- Related ADR(s): Scind `port-types.md` / `docker-labels.md` (visibility labels)
- Correspondence-map row(s): `specs/docker-labels.md` (DIVERGED — visibility is the
  Scind-only half → P5/P3), `specs/port-types.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off SA-0019; naming-clarification note → P6
