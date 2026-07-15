# Divergence 0016: Assigned-port sticky-trust allocation

**Status**: Active
**Scind canon**: `docs/specs/state-management.md` (fail-closed: explicit conflict error at startup + scan/release remediation)
**Xcind reality**: sticky-trust — trust the recorded TSV port without a bind-probe, no fail-at-startup; `lib/xcind/xcind-assigned-lib.bash:789-797`, `test/test-xcind-proxy.sh:2753-2772`
**Category**: Design
**Origin**: P4 XA-0035

## What differs
When an app has a previously-assigned host port recorded in its TSV, Xcind **trusts
it** — it does not bind-probe to confirm availability and does not fail at startup on
an apparent conflict. Scind's model is **fail-closed**: if a previously-assigned port
looks unavailable at `up`, raise an explicit conflict error and point the user at
scan/release remediation.

## Why Xcind diverges
Xcind's regression test records the reason: probe-and-evict "caused ports to flap on
every cache miss while the container was up." A bind-probe cannot distinguish the
workspace's **own already-running container** (a normal re-up) from a foreign
process, so Xcind chose to trust the sticky assignment rather than fight its own
containers. Doing the self-vs-foreign disambiguation dance in Bash was not worth it.

## Why Scind should NOT simply adopt Xcind's approach (NARROWED)
Scind can do better than *either* extreme. It **labels its own containers**
(`workspace.name`/`path`, per its registry-reconstruction model), so it can
distinguish self from foreign via Docker inspection and keep **fail-closed only for
genuine conflicts** — strictly better than sticky-trust's blanket deferral to a raw
`docker compose up` bind error. So Scind should not adopt *blanket no-probe/no-fail*
sticky-trust; that compromise is specific to Xcind's Bash-level self-vs-foreign
ambiguity.

## Canon-change test (required)
**Strongest canon-change argument (this was the reviewer's hardest attempt):** the
code's rationale is a **language-neutral truth, not a Bash-ism** — Go's `net.Listen`
has the *identical* blind spot, so Scind's specified fail-fast **will false-positive
on its own running containers** on an idempotent re-up. **Why it does not promote
*here*:** that defect is **precisely P5's SA-0005** (fail-fast mis-fires on idempotent
re-up), already routed to P6 as a CANON-OVERREACH — so the promotable half **is
captured and MUST stay routed to P6.** This entry is *narrowed* to only the blanket
no-probe compromise, which does not survive as canon but is a valid Xcind choice.
Verdict: **SURVIVES-AS-DIVERGENCE (narrowed)** — the reviewer noted it would have
promoted outright had SA-0005 not already existed. **Do not let this entry absorb the
SA-0005 learning.**

## Revisit conditions
Reopen if P6's SA-0005 fix (exclude self-owned running containers before declaring a
conflict) changes the calculus — Scind may then have a fail-closed model that no
longer mis-fires, further isolating this entry to the pure Bash compromise. Re-audit
each round.

## Links
- Origin finding: P4 XA-0035; **paired reverse-learning P5 SA-0005 (→ P6, keep
  routed)**
- Related ADR(s): Xcind ADR-0005 (structure-vs-state); Scind `state-management.md`
- Correspondence-map row(s): `specs/state-management.md` (SCIND-ONLY),
  `specs/port-types.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off XA-0035 **and** SA-0005 (distinct rows —
  the sticky-trust divergence vs. the fail-fast overreach)
