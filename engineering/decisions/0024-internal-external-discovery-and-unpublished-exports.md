# ADR-0024: Internal/External Discovery Variables and Unpublished Exports

**Status**: Accepted

## Context

[ADR-0018](0018-service-discovery-env-injection.md) injects
`XCIND_{APP}_{EXPORT}_*` discovery variables into containers, and
[ADR-0020](0020-host-env-symmetry.md) writes the same set, with host values, to an
opt-in host env file. Three gaps showed up in real use:

1. **A proxied export has no in-network address.** Its `_HOST`/`_PORT` are always
   the proxied hostname and the proxy port, in both views. A container that must
   talk to the service directly (for example an SMTP or API client on the Docker
   network) cannot learn the service alias or the container port. Applications
   invented variable names that Xcind never emits.
2. **Every export is exposed.** `XCIND_PROXY_EXPORTS` knows only `proxied` (a
   Traefik router) and `assigned` (a managed host port). A port that only other
   containers need — the SMTP side of a mail catcher, a metrics endpoint — cannot
   get discovery variables without also being routed or published, and an
   `assigned` export adds a sticky host-port allocation for no reason.
3. **The host env file always says `127.0.0.1`.** When the proxy domain is a
   wildcard DNS name that resolves to the Docker host (for example a LAN address
   reachable from a VM, its host OS, and other machines), a hostname is a better
   external address than loopback. Assigned ports bind all interfaces, so the
   hostname plus the host port works.

The base `_HOST`/`_PORT` already carry two meanings: for assigned exports they
change with the view, and for proxied exports they never change. Changing their
values would break existing consumers and diverge from Scind's variable table.

## Decision

### Explicit internal and external pairs

Keep every base variable as it is. Add two explicit pairs:

- **`_INTERNAL_HOST` / `_INTERNAL_PORT`** — the address *inside Docker*: the
  workspace alias (`XCIND_WORKSPACE_SERVICE_TEMPLATE`, default `{app}-{service}`)
  in a workspace, else the compose service name, plus the container port. Emitted
  in the **container view only**. They mean nothing to a host process.
- **`_EXTERNAL_HOST` / `_EXTERNAL_PORT`** — the address *outside Docker*.
  **View-invariant**: the same value in both views, equal to the host view's base
  `_HOST`/`_PORT`. Inside a container they answer "what do I tell an outside
  client?", not "what do I dial from here?".

| Export type | Container view | Host view |
|---|---|---|
| `proxied` | base (proxied host, proxy port, `_SCHEME`, `_URL`, protocol variants) + `_INTERNAL_*` + `_EXTERNAL_*` | base + `_EXTERNAL_*` |
| `assigned` | base = internal, `_HOST_PORT`, `_INTERNAL_*`, `_EXTERNAL_*` | base = external, `_HOST_PORT`, `_EXTERNAL_*` |
| `unpublished` | base = internal, `_INTERNAL_*` | nothing |
| apex | unchanged | unchanged |

A proxied `_INTERNAL_PORT` is the entry's explicit port, else the single port
mapping inferred from the resolved compose config (the same inference the proxy
hook uses).

### New export type: `unpublished`

`type=unpublished` declares a port for discovery only:

```bash
XCIND_PROXY_EXPORTS+=("smtp=mailpit:1025;type=unpublished")
# container view: XCIND_SHOP_SMTP_HOST=shop-mailpit  XCIND_SHOP_SMTP_PORT=1025
#                 XCIND_SHOP_SMTP_INTERNAL_HOST=…    XCIND_SHOP_SMTP_INTERNAL_PORT=1025
# host view:      (nothing)
```

- No Traefik router, no host port, no assigned-port state, and nothing in the
  host env file. The proxy and assigned hooks skip it; Traefik is not started for
  an app whose exports are all unpublished.
- The port must resolve: explicit, or inferred from a single port mapping. The
  compose service must exist. Either failure is an export-named generation error.
- `tls=` is accepted and ignored, as it is for `assigned`.
- `xcind-config --json` reports it in a new `unpublishedExports` map
  (`{compose_service, container_port}`), and `xcind-application exports` lists it
  with `type: "unpublished"`. `ports` and `urls` exclude it.

**Naming.** The `type` slot says how a port is reached from outside Docker
(`proxied`, `assigned`), so the new value says the same: it is not published.
Rejected names:

- `internal` and `private` describe a restriction the type does not impose; any
  container on the network can already reach the service. Scind also uses
  "private" for a service that is not exported at all.
- `protected` collides with Scind's per-port `visibility: public | protected`,
  whose default is already `protected` for every port.

### Opt-in hostname for the assigned external host

`XCIND_HOST_ENV_ASSIGNED_HOST` selects the external host of an assigned export:

- `loopback` (default) — `127.0.0.1`, as before.
- `hostname` — the export's URL-template hostname
  (`XCIND_APP_URL_TEMPLATE`, e.g. `dev-shop-db.example.test`).

Any other value is an error. The setting drives the host view's base `_HOST` and
`_EXTERNAL_HOST` in **both** views, so the two views never disagree.

### Prefix collisions are errors

Two declarations that produce the same `XCIND_{APP}_{EXPORT}` prefix now fail
generation. Examples: one name declared as both `proxied` and `unpublished`
(`mailpit:8025` and `mailpit:1025;type=unpublished`), `a-b` next to `a_b`, or an
export named `apex` while apex variables are active. Byte-identical repeats (the
same entry appended by two config files) remain allowed. Two ports on one
service need two export names, which Scind already requires for two proxied
ports.

The prefix check cannot see suffix overlaps: an export named `api-internal`
produces `XCIND_{APP}_API_INTERNAL_HOST`, and so does the internal pair of an
export named `api` (the same holds for `-external`, `-host`, `-http`, and
`-https`). So the pair builder also checks every variable name it emits: a
repeated name with the same value is emitted once, and a repeated name with a
different value fails generation instead of letting the last value win. Entry
comparison normalizes the port (`80` equals `80/tcp`) and ignores `tls=` on
non-proxied entries.

The pair builder now returns an error status, and both of its callers (the
discovery GENERATE hook and the host env EXECUTE hook) fail on it, instead of
reading its output through a process substitution that dropped the status.

## Relationship to Scind canon (P6)

**PROMOTE candidate.** Scind specifies two port types and the base variable
table only. These are Xcind-surfaced extensions, recorded as
[`XA-0045`](../sync/artifacts/xcind-ahead.md) for P6:

- `_INTERNAL_*` / view-invariant `_EXTERNAL_*` pairs for every export type.
- A third port type, `unpublished` (Scind shape: `ports: [{type: unpublished, port: 1025}]`).
- An opt-in external-host mode for assigned exports in the host-view env file
  (Scind ADR-0015).
- Prefix collisions as a generation error (Scind's naming rule leaves them
  undefined).

Not a divergence: none of these narrows Scind's behavior.

Scind inconsistency observed while deciding the name (left for P6, not changed
here): Scind ADR-0002 says "protected services remain internal", but Scind's
port-types spec defines `visibility` as advisory metadata that enforces nothing,
and both visibilities route through Traefik.

## Consequences

### Positive

- A container can reach any exported service directly, and can also tell an
  outside client the right address, without hard-coding names.
- Ports that only containers need are declared once and stay unexposed, with no
  sticky host-port allocation.
- Setups with wildcard DNS get readable, LAN-reachable addresses in the host env
  file.
- Silent variable shadowing between exports is now impossible: overlapping
  names fail generation.

### Negative

- More variables per export (two or four extra lines in every container).
- A configuration that declared one export name twice with different
  definitions, or two names where one is the other plus `-internal`,
  `-external`, `-host`, `-http`, or `-https`, silently produced overlapping
  variables before and now fails. Rename one export.
- The discovery pair builder needs the resolved compose config to infer a
  proxied or unpublished container port that the entry does not state.

### Neutral

- `XCIND_HOST_ENV_ASSIGNED_HOST` keeps the host-env name family even though it
  also sets `_EXTERNAL_HOST` inside containers; the host view is where it matters.

## Related Documents

- [ADR-0007: Port Type System](0007-port-type-system.md)
- [ADR-0018: Service-Discovery Environment Variable Injection](0018-service-discovery-env-injection.md)
- [ADR-0020: Host/Container Environment Symmetry](0020-host-env-symmetry.md)
- [Environment Variables](../specs/environment-variables.md)
- [Port Types](../specs/port-types.md)
