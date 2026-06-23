# ADR-0017: Reporting Prefers the Apex URL for the Headlining Export

**Status**: Accepted

## Context

When an app declares an apex template (the default — the
`*_APEX_URL_TEMPLATE` family), the `xcind-proxy-hook` GENERATE step emits
Traefik routers **and** docker labels for the short apex hostname
(`{app}.{domain}`, e.g. `myapp.localhost`) on the **first proxied** export.
The app is therefore reachable at the short apex URL, and that is the URL users
actually type.

But reporting never showed it. `xcind-application urls`, `exports`, and the
live `status` view all reported the longer **per-export** hostname
(`{app}-{export}.{domain}`, e.g. `myapp-app.localhost`). The apex URL — the
nicer, canonical one already serving traffic — was invisible to the CLI.

The apex hostname lived only inside the GENERATE hook. ADR-0015 established
`xcind-config --json` (the `assignedExports` / `proxiedExports` maps) as the
single, stable contract every introspection consumer reads, but the apex was
never propagated into it. Two reporting paths each independently stopped at the
per-export form: the computed-introspection path (`urls`/`exports`, which reads
`proxiedExports[].url`) and the live-label path (`status`, which scrapes
`xcind.export.*.host` labels). The shared `__xcind-proxy-apex-for-app` anchor
helper already existed (single source of truth for the apex hostname/scheme),
so the gap was purely in the contract and its consumers, not in routing.

Apex is single-export by construction: the template omits `{export}`, so it
names exactly one export per app. The hook assigns it to the first proxied
entry only. "Report the apex" therefore means: report it for the one headlining
(first proxied) export; all other proxied exports keep their per-export
hostname.

## Decision

1. **The apex is an additive field in the `xcind-config --json` contract, not a
   replacement.** `proxiedExports[<first-proxied>]` gains `apex_url` and
   `apex_host` (derived from the shared `__xcind-proxy-apex-for-app` anchor, so
   they stay byte-identical with the generated `xcind.apex.*` labels). The
   existing per-export `url` is preserved unchanged; other proxied exports omit
   the apex keys. Routing and labels are untouched — this is reporting-only.

2. **Consumers prefer the apex for the headlining export.**
   - `xcind-application urls` (text and `--json`) reports `apex_url` for that
     export — the canonical URL that serves traffic — and the per-export URL for
     every other export.
   - `xcind-application exports` keeps the per-export `url` **and** adds
     `apexUrl`/`apexHost` (camelCase, matching that command's rendered
     descriptor convention) so nothing is lost.
   - `xcind-application status` swaps the headlining export's scraped per-export
     host for the apex host in its live `urls[]` array. The swap is gated on the
     per-export host actually being scraped, so the apex appears exactly when its
     container is running; sibling exports keep their own hosts.

3. **When no apex template is configured, every surface reports the per-export
   host, exactly as before.** The `apex_url`/`apex_host` keys are then omitted.

## Consequences

### Positive

- The URL users actually type is the URL the CLI reports.
- One contract backs every consumer (ADR-0015): the apex hostname is computed
  once by `__xcind-proxy-apex-for-app` and flows into both labels and JSON, so
  the routing, label, and reporting surfaces cannot drift.
- Non-breaking: `url` is retained; consumers that ignore the new keys are
  unaffected.

### Negative

- `xcind-application urls` now returns the apex URL for the headlining export
  instead of its per-export URL — a behavior change for scripts that relied on
  the per-export form from `urls`. The per-export URL remains available via
  `exports` (the detailed view).
- In the rare case of multiple proxied exports sharing one compose service, the
  `status` live view replaces only the headlining export's host; the design
  intentionally keeps the others, identified via the per-export `apex_host`
  marker rather than guessing from labels.

### Neutral

- The `exports` rendered descriptor uses camelCase (`apexUrl`/`apexHost`) while
  the raw `xcind-config --json` contract uses snake_case (`apex_url`/
  `apex_host`), consistent with each surface's existing field-naming convention.

## Related Documents

- [ADR-0015: Application Export Introspection](0015-application-export-introspection.md) — establishes `xcind-config --json` as the single contract these consumers read.
- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) — what the proxy/routing actually owns (unchanged here).
- [ADR-0004: Convention-Based Naming](0004-convention-based-naming.md) — the per-export vs apex hostname templates.
- [`engineering/reference/cli.md`](../reference/cli.md#json-output-contract) — the `proxiedExports`/`apex` contract and the `urls`/`exports`/`status` behavior.
- [`engineering/specs/docker-labels.md`](../specs/docker-labels.md#apex-labels) — `xcind.apex.*` labels, now consumed by the status reader.
