<!--
Copy this file to NNNN-{slug}.md. Assign NNNN from the single sequence (see the
index in README.md — take the next unused number). Fill EVERY field; the
"Canon-change test" field is required and is what keeps a learning from being
silently paved over. For Design/Scope entries, name the adversarial reviewer/pass
that challenged the entry. After writing, add a row to registry.json and a line to
the README index.
-->

# Divergence NNNN: {short title}

**Status**: Active | Superseded | Resolved (canon changed to match)
**Scind canon**: docs/{path} (or "none — Scind is silent")
**Xcind reality**: bin/… , lib/… , engineering/{path}
**Category**: Structural | Design | Scope | Process
**Origin**: {P3 L-xxxx | P4 XA-xxxx | P5 SA-xxxx | pre-existing}

## What differs
{One paragraph: what Scind says/implies vs what Xcind does.}

## Why Xcind diverges
{The reason. For Bash-isms: the language forced it. For scope: the deliberate cut.}

## Why Scind should NOT simply adopt Xcind's approach
{The key field — this is what makes it a *divergence* and not a learning. If you
cannot write this convincingly, STOP: this is a CANON-CHANGE, not a divergence.
Route it back to P3/P6.}

## Canon-change test (required)
{Was this seriously considered as a CANON-CHANGE? State the strongest argument that
it proves a Scind assumption wrong, and why that argument was rejected. For
Design/Scope entries, name the adversarial reviewer/pass that challenged it. This
field guarantees the learning is never silently lost — a later round can reopen it
from here.}

## Revisit conditions
{What would make us reconsider — e.g. "when Scind's Go impl exists," "if users ask."}

## Links
- Origin finding: {L-/XA-/SA-xxxx}
- Related ADR(s): {Xcind/Scind ADR numbers}
- Correspondence-map row(s): {file↔file or ADR-topic rows}
- Reconciliation-ledger ID(s): {P6 keys off the same origin-finding IDs}
