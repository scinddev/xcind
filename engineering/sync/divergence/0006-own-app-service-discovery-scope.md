# Divergence 0006: Own-app-only service-discovery scope (v1)

**Status**: Active
**Scind canon**: `docs/specs/environment-variables.md` (workspace-wide cross-app `SCIND_*` injection)
**Xcind reality**: `lib/xcind/xcind-discovery-lib.bash` — injects discovery vars for the app's **own** services only; `engineering/decisions/0018-service-discovery-env-injection.md`
**Category**: Design
**Origin**: P3 L-0026

## What differs
Scind injects service-discovery environment variables **workspace-wide**: every app
sees `SCIND_{OTHERAPP}_{SERVICE}_*` vars for its siblings, enabling cross-app
connectivity by env var. Xcind v1 injects discovery vars for the **invoking app's
own** services only — no cross-app env injection.

## Why Xcind diverges
Xcind's config model is per-app (each app resolves from its own `.xcind.sh`), and
its ADR-0018 discovery hook runs in that per-app context. Own-app-only was the
natural v1 scope: forward-compatible with a workspace-wide v2, and cross-app
connectivity in Xcind is already served by **DNS aliases on the shared
`dev-internal` network** (real routing, not env strings).

## Why Scind should NOT simply adopt Xcind's approach
Cross-app injection is **Scind's core value proposition** — it is the reason a
workspace exists. Narrowing Scind to own-app-only would gut that. Moreover, the
env-var channel carries information DNS aliases cannot: proxied URLs, preferred
schemes, and the allocated `_HOST_PORT`. Scind's sticky global port state also lets
it inject cross-app values without the staleness Xcind would risk. Scind must keep
its workspace-wide scope.

## Canon-change test (required)
**Strongest canon-change argument:** "Xcind runs fine on own-app-only, so cross-app
env injection is over-engineered — DNS aliases are the real connectivity." **Why
rejected (adversarial re-check PERFORMED — P3 + P7):** the P7 reviewer confirmed
Xcind's own scope comment (`xcind-discovery-lib.bash:7`) calls this "own-app only
(v1) … forward-compatible with a workspace-wide v2" — an **un-built limitation, not
a discovery that cross-app is unneeded.** This is closer to Xcind being *behind*
than a real divergence, but it survives because Scind must not *narrow* its core
value; Xcind simply hasn't built v2 yet. Verdict: **SURVIVES-AS-DIVERGENCE.** If
Xcind ships a workspace-wide v2, this resolves rather than promoting a learning.

## Revisit conditions
When Xcind implements a workspace-wide (v2) discovery scope — at which point the
divergence **resolves** (Xcind adopts canon). Re-audit each round per the Design
re-check rule.

## Links
- Origin finding: P3 L-0026 (DIVERGENCE, adversarial re-check performed & survived)
- Related ADR(s): Xcind ADR-0018 (service-discovery env injection); Scind
  `environment-variables.md` spec
- Correspondence-map row(s): `specs/environment-variables.md` (PARTIAL)
- Reconciliation-ledger ID(s): P6 keys off L-0026
