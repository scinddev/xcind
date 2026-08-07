# ADR-0022: External Proxy Mode

**Status**: Accepted

## Context

[ADR-0008](0008-traefik-reverse-proxy.md) chose Traefik with the Docker
provider as xcind's reverse proxy, and until now xcind always ran that Traefik
itself, bound to host ports 80/443. On a host that already runs its own Traefik
— the concrete motivating case is a Coolify server, whose `coolify-proxy`
Traefik owns ports 80/443, lives on the `coolify` Docker network, names its
entrypoints `http`/`https`, and terminates TLS with an ACME certresolver named
`letsencrypt` — the managed proxy cannot bind its ports. Moving the managed
proxy to alternate ports works but produces second-class URLs and two proxy
stacks doing the same job.

Because xcind's routing is *already* expressed as Docker-provider labels, the
existing host Traefik can serve xcind apps directly — provided the labels
reference *its* entrypoint names, the app containers share a network with it,
and HTTPS routers name its certresolver. Three things stood in the way, all
hardcoded: the network name (`xcind-proxy`), the entrypoint names
(`web`/`websecure`), and the absence of any certresolver label.

## Decision

Add a proxy **mode** with two values, persisted in the global proxy config:

- `managed` (default) — exactly today's behavior: xcind generates, starts, and
  stops its own Traefik.
- `external` — xcind never starts, stops, or configures a proxy. Apps attach
  to the configured shared network and emit labels tuned for the host proxy;
  the host proxy's Docker provider discovers them.

Five config keys (all set via `xcind-proxy init` flags, all meaningful in both
modes) make the label surface configurable:

| Key | Default | Coolify value |
|---|---|---|
| `XCIND_PROXY_MODE` | `managed` | `external` |
| `XCIND_PROXY_NETWORK` | `xcind-proxy` | `coolify` |
| `XCIND_PROXY_HTTP_ENTRYPOINT` | `web` | `http` |
| `XCIND_PROXY_HTTPS_ENTRYPOINT` | `websecure` | `https` |
| `XCIND_PROXY_CERTRESOLVER` | (empty) | `letsencrypt` |

When `XCIND_PROXY_CERTRESOLVER` is non-empty, every generated HTTPS router
(per-export and apex) gains a
`traefik.http.routers.<router>.tls.certresolver=<name>` label. This is
mode-independent: a managed Traefik configured with an ACME resolver benefits
identically.

Managed mode's generated `traefik.yaml` also follows the configured entrypoint
and network names, so label generation is a single code path with no per-mode
branching; the defaults reproduce the previous output byte-for-byte.

### Network topology

Two wirings work; the **recommended** one is to point `XCIND_PROXY_NETWORK` at
the network the host proxy already lives on (e.g. `coolify`). App overlays
declare the network `external: true`, so they simply join it — the host proxy
container is never touched. This matters on platform-managed hosts: Coolify
recreates its proxy container on upgrade/redeploy, which would silently drop a
manual `docker network connect`.

The alternate topology — keep `XCIND_PROXY_NETWORK=xcind-proxy` and run
`docker network connect xcind-proxy <proxy-container>` — also works and needs
no host-proxy config awareness, but carries exactly that recreation caveat and
must be re-applied whenever the proxy container is recreated.

If the configured network does not exist, xcind still creates it (the overlays
would otherwise fail to start) but warns loudly in external mode, since a
freshly created network by definition has no external proxy attached.

### Division of TLS labor

`XCIND_PROXY_TLS_MODE` keeps its meaning of *which routers exist* (`auto` →
HTTP+HTTPS, `disabled` → HTTP-only), and per-export `tls=auto|require|disable`
([ADR-0009](0009-flexible-tls-configuration.md)) is unchanged. What external
mode removes is cert *provisioning*: the mkcert/openssl machinery is skipped
entirely — the host proxy terminates TLS. Consequently `--tls-mode custom` is
a hard error together with external mode: it configures cert files xcind would
never install anywhere.

The `tls=require` redirect middleware (`xcind-redirect-to-https`) is pure
Docker-provider label config, so it works on any host Traefik with the Docker
provider enabled. The name keeps its `xcind-` prefix and is not further
namespaced: every xcind app emits a byte-identical definition, and repeated
identical definitions are idempotent in Traefik. Known caveats, accepted and
documented rather than worked around:

- A host-level *entrypoint* HTTP→HTTPS redirect (Coolify's "Force HTTPS")
  shadows xcind's HTTP routers before routing. Harmless — requests still land
  on the HTTPS routers.
- Host Traefiks using `providers.docker.constraints` will not discover xcind
  containers unless the constraint's label is added to the app (out of scope;
  documented in the guide).

### Command semantics in external mode

`up` keeps its idempotent "make the proxy layer ready" contract, which external
mode satisfies by verifying the shared network (exit 0, with best-effort
detection of a proxy-like container). `up --force`, `down`, and `logs` refuse
(exit 1) rather than silently no-op: removing a shared network, stopping a
foreign proxy, or tailing nothing would all betray what the user asked for.
One escape hatch: `down` still stops a *leftover xcind-managed* Traefik (by
its `xcind.component=proxy` label) when the old managed compose file exists,
so a managed→external migration can be completed without raw docker commands.

`status` renders an external-specific report (mode, network existence,
entrypoints, certresolver, detected proxy container) and gains a `mode` field
in both modes' JSON.

`dispose` still runs in external mode: it can stop a retained xcind-managed
proxy via the old compose file and removes generated state, but it never
removes the shared external network. See the
[proxy infrastructure spec](../specs/proxy-infrastructure.md#external-proxy-mode)
for the full command table.

### Precedence and cache invalidation

The new keys follow the established precedence: `config.sh` is sourced after
environment defaults, so config wins. The generate-cache fingerprint already
hashes the global proxy `config.sh`, so changing mode/network/entrypoints
automatically regenerates every app's `compose.proxy.yaml`.

## Consequences

- A Coolify (or any existing-Traefik) host serves xcind apps on real ports
  80/443 with ACME certs, one proxy hop, zero host-proxy modification:
  `xcind-proxy init --mode external --network coolify --http-entrypoint http
  --https-entrypoint https --certresolver letsencrypt --proxy-domain
  apps.example.com`.
- Managed-mode defaults are unchanged; existing nine-key `config.sh` files
  load fine (missing keys take defaults) and are upgraded on the next `init`.
- Switching external→managed requires passing the managed values back
  explicitly (e.g. `--network xcind-proxy`), since `init` merges existing
  config.
- The label vocabulary xcind emits is now a public-ish contract with foreign
  proxies; entrypoint names and certresolver are the configuration surface for
  that contract.

## Related Decisions

- [ADR-0002](0002-two-layer-networking.md) — the shared proxy network layer
  this mode re-points at an existing network
- [ADR-0008](0008-traefik-reverse-proxy.md) — Docker-provider labels are
  what make an external Traefik a drop-in consumer
- [ADR-0009](0009-flexible-tls-configuration.md) — TLS mode semantics external
  mode builds on
