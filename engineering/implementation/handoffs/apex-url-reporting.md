# Handoff: apex URL is routed but never reported for proxied exports

**Status**: resolved — see [ADR-0017](../../decisions/0017-apex-url-reporting.md)
**Surfaced**: 2026-06-19, while wiring an app (single proxied `app` export) behind the proxy — the app is reachable at the apex host `myapp.<domain>`, but every `xcind-application` view reports the longer per-export host `myapp-app.<domain>`.

## Symptom

When an app declares an apex template (the default, via
`XCIND_*_APP_APEX_URL_TEMPLATE`), the GENERATE hook emits Traefik routers
**and** docker labels for the apex hostname (`{app}.{domain}`, e.g.
`myapp.localhost`) for the first proxied export. The app is therefore
reachable at the short apex URL, and that is the URL users actually type.

But none of the reporting surfaces ever show it. `xcind-application urls`,
`xcind-application exports`, and the `xcind-application` status view all
report the **per-export** hostname (`{app}-{export}.{domain}`,
e.g. `myapp-app.localhost`) instead. The apex URL — the nicer, canonical one
that is already serving traffic — is invisible to the CLI.

Concretely, for a workspaceless app `myapp` with `XCIND_PROXY_EXPORTS=("app:8080")`
and domain `localhost`:

- Reported today: `http(s)://myapp-app.localhost`
- Actually canonical / desired: `http(s)://myapp.localhost`

## Scope note (read before designing)

Apex is a **single-export** concept by construction: the apex template omits
`{export}`, so it can name exactly one export per app. The GENERATE hook
already encodes this — it assigns the apex to the **first proxied** entry only
(`is_first_proxied && apex_enabled`). "Report the apex for *any* proxied
export" therefore means: report the apex for the one headlining (first
proxied) export; all other proxied exports keep their per-export hostname.
Do **not** attempt to apex-ify multiple exports — their hostnames would
collide. This handoff preserves per-export hostnames/routers untouched and
only *adds* apex visibility to reporting.

## Location

Two independent reporting paths each ignore the apex; both must change.

**Path 1 — computed introspection (used by `urls` / `exports`):**

- `lib/xcind/xcind-proxy-lib.bash` — `__xcind-proxy-json-for-app()` (≈ lines
  759–820). Builds `{ "<export>": { compose_service, container_port, url, tls } }`.
  The `url` is computed as `"$scheme://$hostname"` where `hostname` comes from
  `__xcind-proxy-export-hostname` — the **per-export** template only. It never
  consults the apex template, and has no notion of "first proxied".
- `lib/xcind/xcind-proxy-lib.bash` — `__xcind-proxy-export-hostname()` (≈ 726–734):
  renders `XCIND_APP_URL_TEMPLATE` (per-export). There is no apex analogue helper.
- `bin/xcind-application` — the `urls` / `exports` subcommands (jq around
  ≈ 699–740) read `.proxiedExports[].url` from this JSON. Text output uses
  `.value.hostPort // .value.url`.

**Path 2 — live-label status (the default `xcind-application` view):**

- `bin/xcind-application` (≈ lines 329–351). It scans running containers and
  collects URLs from docker labels, but the `docker inspect` Go template
  filters to **prefix `xcind.export.` AND suffix `.host`** only. The apex
  labels (`xcind.apex.host`, `xcind.apex.url`) are emitted but never read, so
  the status `urls[]` array shows per-export hosts exclusively.

**Reference — how routing already does it (mirror this logic):**

- `lib/xcind/xcind-proxy-lib.bash` — `apex_enabled` is set true iff
  `XCIND_APP_APEX_URL_TEMPLATE` is non-empty (≈ 848–851).
- `lib/xcind/xcind-proxy-lib.bash` — apex hostname/routers are rendered for the
  first proxied entry only (≈ 910–924), using `XCIND_APP_APEX_URL_TEMPLATE`
  and `XCIND_APEX_ROUTER_TEMPLATE`.
- `lib/xcind/xcind-proxy-lib.bash` — apex docker labels
  (`xcind.apex.host` / `.http.url` / `.https.url` / `.url`) at ≈ 511–517,
  emitted once for the first proxied export (label block ≈ 1077+).
- `lib/xcind/xcind-lib.bash` — `__xcind-resolve-url-templates()` (≈ 1018–1055):
  defines both template families and assigns `XCIND_APP_URL_TEMPLATE`,
  `XCIND_APP_APEX_URL_TEMPLATE`, `XCIND_APEX_ROUTER_TEMPLATE`. Empty apex
  template (set via `${VAR-default}`, no colon) disables apex.

## Root cause

The apex hostname lives only inside the GENERATE hook. It was implemented as
a routing/label concern and never propagated to the introspection contract or
the status reader. The two reporting paths each independently re-derive (Path
1) or re-scrape (Path 2) hostnames and both stop at the per-export form. There
is no single field that says "the canonical URL for this export is the apex."

## Proposed fix (sketch)

Make the apex a first-class, *additive* field in the introspection contract,
then have the consumers prefer it. Keep `url` (per-export) for backward
compatibility; do not change routing.

### 1. Introspection: emit `apex_url` (and `apex_host`) for the first proxied export

In `__xcind-proxy-json-for-app`:

- Replicate the GENERATE hook's gating: compute `apex_enabled`
  (`[[ -n ${XCIND_APP_APEX_URL_TEMPLATE:-} ]]`) and track the first proxied
  entry with an `is_first_proxied` flag, exactly as the hook does.
- For that first proxied entry when `apex_enabled`, render the apex hostname
  with `XCIND_APP_APEX_URL_TEMPLATE` (workspace/app/domain — note: **no**
  `export` key) and add to that export's object:
  - `apex_url`: `"$scheme://$apex_hostname"` (same scheme rule as `url`)
  - `apex_host`: `"$apex_hostname"`
- Other exports: omit the apex keys (or `null`). The shape stays
  `{ "<export>": { compose_service, container_port, url, tls, apex_url?, apex_host? } }`.

**Critical gotcha — template availability in this subshell.**
`__xcind-proxy-json-for-app` runs under command substitution and only sources
the *global* proxy `config.sh` for the domain; it does **not** run the full
prepare pipeline, so `XCIND_APP_URL_TEMPLATE` / `XCIND_APP_APEX_URL_TEMPLATE`
may be unset there. Per-export `url` works today only because callers happen
to have `XCIND_APP_URL_TEMPLATE` in scope. Before relying on the apex
template, confirm where these are set for the introspection path and, if they
are not guaranteed, call `__xcind-resolve-url-templates` (or otherwise resolve
the same defaults) inside the function. Verify this first — it is the part
most likely to silently no-op. Add a test that runs introspection in a clean
shell (no prepare pipeline) to lock the behavior down.

### 2. Consumers in `bin/xcind-application`: prefer apex when present

- `urls` / `exports` jq (≈ 699–740): when an export has `apex_url`, prefer it
  for the human/text output; in `--json` output include both `url` and
  `apex_url` so nothing is lost. Suggested text precedence:
  `.value.hostPort // .value.apex_url // .value.url`.
- Status view label scan (≈ 329–351): broaden the `docker inspect` template to
  also capture `xcind.apex.host` (e.g. accept prefix `xcind.apex.` + suffix
  `.host`, or add a second pass), so the live view surfaces the apex host for
  running containers too. Decide whether to show apex *instead of* or *in
  addition to* the per-export host in this list; recommend **apex in place of**
  the first proxied export's per-export host to avoid a confusing duplicate,
  matching the `urls`/`exports` behavior.

### 3. Keep the two paths consistent

The whole point of `__xcind-proxy-export-hostname` being "the single source of
truth shared by the hook and introspection" is to prevent drift. Add the apex
equivalent as a shared helper too — e.g. `__xcind-proxy-apex-hostname()` —
and call it from both the GENERATE hook (replacing the inline render at
≈ 913) and the introspection path, so apex hostname rendering also has one
source of truth.

## Decisions for the implementer

- **Contract shape**: additive `apex_url`/`apex_host` (recommended,
  non-breaking) vs. overwriting `url` (breaking; simpler consumers). Recommend
  additive. If the introspection JSON is considered stable public API, this is
  ADR-worthy (Layer 1) — see `engineering/decisions/` and the LDS guide; a
  short ADR documenting "reporting prefers apex for the headlining export"
  would fit alongside ADR-0008 (Traefik) / ADR-0004 (naming).
- **Status-view behavior**: replace vs. augment the per-export host in the
  live `urls[]`. Recommend replace-for-first-proxied for parity with `urls`.

## Tests

Suite is plain shell (no bats): `test/test-xcind-proxy.sh`, helpers in
`test/lib/`. Add cases:

1. Introspection JSON includes `apex_url`/`apex_host` for the first proxied
   export when an apex template is set; both absent (or null) when apex is
   disabled (`XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=''`).
2. Multiple proxied exports → only the first proxied entry carries apex keys;
   an `assigned` entry placed first does not consume the apex slot (mirror the
   hook's `is_first_proxied` semantics).
3. `xcind-application urls` / `exports` print the apex host when apex is
   enabled, the per-export host when disabled.
4. Introspection invoked in a clean shell (no prepare pipeline) still resolves
   the apex template — guards the "template availability" gotcha above.
5. Regression: assigned-only and apex-disabled apps report exactly as before.

## Docs to update

- `engineering/specs/configuration-schemas.md` (and/or wherever the
  introspection JSON is specified) — document the new `apex_url`/`apex_host`
  fields.
- `engineering/specs/docker-labels.md` — note that `xcind.apex.*` labels are
  now consumed by the status reader, not only emitted.
- `docs/` (user-facing): `docs/explanation/conventions.md` and the glossary
  already describe the apex template; add a line that `xcind-application`
  reports the apex URL for the headlining export when a template is set.
- `CHANGELOG.md` is generated by git-cliff (`cliff.toml`) from Conventional
  Commits — no manual edit; commit as e.g.
  `feat(proxy): report apex URL for the headlining proxied export`.

## Acceptance criteria

- For a workspaceless app `myapp`, domain `localhost`,
  `XCIND_PROXY_EXPORTS=("app:8080")`, default apex template:
  - `xcind-application urls` shows `…://myapp.localhost` (not `myapp-app.localhost`).
  - `xcind-application exports --json` includes both `url` (`myapp-app.localhost`)
    and `apex_url` (`myapp.localhost`) for the `app` export.
  - The status view's `urls[]` shows the apex host for the running app container.
- With `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=''` (apex disabled), all
  surfaces report the per-export host, unchanged from today.
- With two proxied exports, only the first carries `apex_url`; the second
  reports its per-export host only.
- Per-export routing and labels are unchanged; this is reporting-only.
- `test/test-xcind-proxy.sh` passes, including the new cases.
