# Proxy Infrastructure

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind uses `xcind-proxy` CLI commands and `xcind-proxy-hook` for proxy management.

---

## Proxy Layer

### Architecture Overview

Traefik serves as the reverse proxy, routing external requests to application services by hostname.

```
[External Request] → [Traefik:80] → [xcind-proxy network] → [Service Container]
```

#### Components

- **Traefik container**: Single instance managing all workspace routing
- **xcind-proxy network**: Host-level Docker network connecting Traefik to services
- **Dynamic configuration**: Label-based routing rules on service containers

See [ADR-0008: Traefik for Reverse Proxy](../decisions/0008-traefik-reverse-proxy.md).

### Entry Points

| Entrypoint | Port | Purpose |
|------------|------|---------|
| `XCIND_PROXY_HTTP_ENTRYPOINT` (default `web`) | Configurable (`XCIND_PROXY_HTTP_PORT`, default `80`) | HTTP traffic |
| `XCIND_PROXY_HTTPS_ENTRYPOINT` (default `websecure`) | Configurable (`XCIND_PROXY_HTTPS_PORT`, default `443`) | HTTPS traffic (only when `XCIND_PROXY_TLS_MODE != disabled`) |

Entrypoint *names* are configurable so generated router labels can target an
external proxy's entrypoints (see [External Proxy Mode](#external-proxy-mode));
the managed defaults are `web`/`websecure`.

When `XCIND_PROXY_DASHBOARD=true`, `init` adds `--api.dashboard=true`, an `api: {dashboard: true, insecure: true}` block, and a host publish of the dashboard port; no separate entrypoint is generated — the dashboard rides Traefik's built-in insecure-API listener.
The HTTPS entrypoint and a `file` provider (watching `$XCIND_PROXY_STATE_DIR/dynamic/`) are only emitted when TLS is enabled.

### Dynamic Routing

Routing rules are defined via Docker labels on service containers. Traefik watches for container changes and updates routing automatically via its Docker provider.

See [Docker Labels — Traefik Routing Labels](./docker-labels.md#traefik-routing-labels) for label documentation.

---

## Lifecycle

### `xcind-proxy init`

Creates proxy infrastructure across two directories:

- **Config** (`~/.config/xcind/proxy/`): `config.sh` containing persisted proxy settings; optional `certs/wildcard.{crt,key}` for user-supplied certificates
- **State** (`~/.local/state/xcind/proxy/`): generated `compose.yaml`, `traefik.yaml`, `dynamic/tls.yaml`, and `certs/`. The same directory also holds the assigned-port state (`assigned-ports.tsv` and its `assigned-ports.lock`), which `dispose` removes together with the generated files.

Steps:

1. Sources any existing `config.sh` so known `XCIND_PROXY_*` values become defaults
2. Applies CLI flag overrides
3. Regenerates `config.sh` from the known proxy settings, preserving existing known values when no override is supplied and persisting any flags passed to `init`
4. Sources `config.sh` again for generated-file variable expansion
5. Generates `compose.yaml` (always regenerated) in state dir; includes `:443`, `./certs`, and `./dynamic` bind mounts when TLS is enabled
6. Generates `traefik.yaml` (always regenerated) in state dir; includes `websecure` entrypoint and file provider when TLS is enabled
7. Generates `dynamic/tls.yaml` pointing at the wildcard cert (TLS-enabled modes only)
8. Removes any stale generated files from legacy locations — `docker-compose.yaml` / `traefik.yaml` in the config dir (pre-config/state split) and `docker-compose.yaml` in the state dir (pre-rename to Compose-Specification-standard `compose.yaml`)
9. Creates the configured proxy Docker network (`XCIND_PROXY_NETWORK`, default `xcind-proxy`) if it doesn't exist

In external mode (`XCIND_PROXY_MODE=external`) steps 5–8 are skipped. Instead,
the external branch removes the stale managed `traefik.yaml` and
`dynamic/tls.yaml`; it removes `compose.yaml` only when no xcind-managed proxy
container is still running, and it leaves `certs/` in place — see
[External Proxy Mode](#external-proxy-mode).

`xcind-proxy init` rewrites `config.sh` on each invocation using the current known proxy values plus any provided flags. The lower-level auto-init path used by hooks only creates `config.sh` when it is missing, but still regenerates the state files from the current config.

Certificate provisioning happens lazily on `xcind-proxy up` / auto-start — see [TLS Certificate Management](#tls-certificate-management).

### `xcind-proxy up`

Always regenerates generated files from current `config.sh`, then starts the Traefik container via `__xcind-proxy-ensure-running`.

With `--force`: tears down existing containers, removes the network, re-initializes, and starts fresh.

### `xcind-proxy down`

Stops the Traefik container via `docker compose down`.

### `xcind-proxy dispose [--purge] [--yes]`

Stops the proxy, removes its network, and removes the state directory —
including `assigned-ports.tsv`, so the confirmation prompt reports how
many assigned-port bindings will be lost. `--purge` also removes the
config directory; without it, `config.sh` (and `certs/`) survive.
`--yes`/`-y` skips the prompt. When nothing exists to remove, exits `0`
without prompting.

### `xcind-proxy status [--json]`

Reports:
- Running/stopped state and proxy mode
- Traefik image version
- HTTP port (and HTTPS port when TLS is enabled)
- TLS mode and whether TLS is enabled
- Whether the generated files are current or stale relative to `config.sh`
- Dashboard URL (if enabled)
- Network existence
- Assigned ports (the current entries from `assigned-ports.tsv`)

JSON output additionally carries `http_entrypoint`, `https_entrypoint`,
and `certresolver`.

In external mode a mode-specific report is rendered instead — see
[External Proxy Mode](#external-proxy-mode). JSON output carries a `mode`
field in both modes.

Stale assigned-port entries (those whose app path no longer exists) are pruned as part of `status`.

With `--json`: outputs a JSON object containing an `assigned_ports` array for machine consumption.

### `xcind-proxy release PORT`

Removes a single assigned-port entry from the state file, freeing the host port for reassignment.

### `xcind-proxy prune`

Removes all assigned-port entries whose app path no longer exists. Pruning also runs automatically as part of `init`, `up`, and `status`.

### Auto-Start

When `XCIND_PROXY_EXPORTS` is configured for an application, the `xcind-proxy-hook` calls `__xcind-proxy-ensure-running` which automatically initializes and starts the proxy if needed.

Set `XCIND_PROXY_AUTO_START=0` to disable auto-start (the network is still created for compose overlay compatibility).

---

## External Proxy Mode

See [ADR-0022](../decisions/0022-external-proxy-mode.md). When
`XCIND_PROXY_MODE=external`, a proxy that xcind does not manage (e.g. a
Coolify host's Traefik) serves the apps: xcind only attaches app containers to
the configured shared network (`XCIND_PROXY_NETWORK`, pointed at the external
proxy's network) and emits router labels using the configured entrypoint names
and optional `tls.certresolver`. No `compose.yaml`/`traefik.yaml` are
generated, no certificates are provisioned (the external proxy terminates
TLS), and `--tls-mode custom` is rejected at `init`. One retention rule:
when a running xcind-managed proxy container is detected, `init` keeps the
old managed `compose.yaml` — it is the only remaining handle for stopping
that proxy — and warns that the managed Traefik is still running.

Typical initialization for a Coolify host:

```bash
xcind-proxy init --mode external --network coolify \
  --http-entrypoint http --https-entrypoint https \
  --certresolver letsencrypt --proxy-domain apps.example.com
```

Command behavior in external mode:

| Command | Behavior | Exit |
|---------|----------|------|
| `init` | Writes config, removes stale managed artifacts (retains `compose.yaml` and warns when a managed proxy still runs), verifies/creates the network | 0 |
| `up` | Verifies the network; reports a detected proxy-like container; starts nothing | 0 |
| `up --force` | Refuses (would remove a network shared with the external proxy) | 1 |
| `down` | Refuses; exception: stops a leftover xcind-managed Traefik when **both** a running `xcind.component=proxy` container and the old managed compose file exist (migration escape hatch) | 1 / 0 |
| `logs` | Refuses, with a `docker logs <container>` hint | 1 |
| `status [--json]` | External report: mode, initialized, domain, TLS mode, network existence, entrypoints, certresolver, detected proxy container, assigned ports | 0 |
| `dispose [--purge] [--yes]` | Runs: stops a retained xcind-managed proxy via the old compose file (leaving state intact for a retry if that teardown fails), removes generated state including `assigned-ports.tsv`, but **never** removes the shared external network | 0 |
| `release` / `prune` | Unchanged (assigned ports are orthogonal to proxy mode) | 0 |

`__xcind-proxy-ensure-running` (the EXECUTE-hook path) reduces to "ensure the
configured network exists" — it never starts Traefik and never matches on
`xcind.component=proxy` containers.

External mode short-circuits before `XCIND_PROXY_AUTO_START` is read, so
the two settings do not conflict. The observable effect matches
`XCIND_PROXY_AUTO_START=0` (network only), but error handling differs:
the external path propagates a network-creation failure in strict mode,
while the auto-start opt-out swallows it.

`xcind-config doctor` also reports the proxy mode and, in external mode,
flags a missing proxy network as a diagnostic (app overlays would fail to
start).

---

## Traefik Configuration

For complete configuration examples, see the [Proxy Infrastructure Appendix](./appendices/proxy-infrastructure/).

### Generated `traefik.yaml`

```yaml
entryPoints:
  web:                    # name from XCIND_PROXY_HTTP_ENTRYPOINT
    address: ":80"
  websecure:              # name from XCIND_PROXY_HTTPS_ENTRYPOINT; only when TLS is enabled
    address: ":443"

providers:
  docker:
    exposedByDefault: false
    network: xcind-proxy  # from XCIND_PROXY_NETWORK
  file:                   # only when TLS is enabled
    directory: /etc/traefik/dynamic
    watch: true

log:
  level: INFO
```

When `XCIND_PROXY_DASHBOARD=true`, the dashboard configuration is appended:

```yaml
api:
  dashboard: true
  insecure: true
```

### Generated `dynamic/tls.yaml`

Emitted into `$XCIND_PROXY_STATE_DIR/dynamic/tls.yaml` when TLS is enabled. Points Traefik at the wildcard cert written by the cert-provisioning helper.

```yaml
tls:
  certificates:
    - certFile: /etc/traefik/certs/wildcard.crt
      keyFile: /etc/traefik/certs/wildcard.key
  stores:
    default:
      defaultCertificate:
        certFile: /etc/traefik/certs/wildcard.crt
        keyFile: /etc/traefik/certs/wildcard.key
```

### Generated `compose.yaml`

```yaml
name: xcind-proxy

services:
  traefik:
    image: ${XCIND_PROXY_IMAGE}
    command:
      - "--configFile=/etc/traefik/traefik.yaml"
    ports:
      - "${XCIND_PROXY_HTTP_PORT}:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yaml:/etc/traefik/traefik.yaml:ro
    networks:
      - xcind-proxy
    restart: unless-stopped
    labels:
      - "xcind.managed=true"
      - "xcind.component=proxy"

networks:
  xcind-proxy:
    external: true
```

The network name comes from `XCIND_PROXY_NETWORK` (default `xcind-proxy`
shown); the compose project name (`name: xcind-proxy`) is hardcoded.

Dashboard port mapping and `--api.dashboard=true` command are added when `XCIND_PROXY_DASHBOARD=true`.
HTTPS port mapping, `./certs`, and `./dynamic` bind mounts are only added when `XCIND_PROXY_TLS_MODE != disabled`.

---

## TLS Certificate Management

Governed by `XCIND_PROXY_TLS_MODE` (see [ADR-0009](../decisions/0009-flexible-tls-configuration.md)).

| Mode | Behaviour |
|------|-----------|
| `auto` (default) | Resolve (in order): user-provided wildcard at `$XCIND_PROXY_CONFIG_DIR/certs/wildcard.{crt,key}` (always wins; copied into state when newer) → previously generated state cert for the same domain (fast path) → `mkcert` → openssl self-signed fallback. |
| `custom` | Use `XCIND_PROXY_TLS_CERT_FILE` and `XCIND_PROXY_TLS_KEY_FILE` (both required). |
| `disabled` | Skip cert provisioning; no `websecure` entrypoint, no HTTPS routers. |

Certificates are written to `$XCIND_PROXY_STATE_DIR/certs/wildcard.{crt,key}`. A sibling `domain` marker file records the domain the cert was minted for so `xcind-proxy up` can detect a changed `XCIND_PROXY_DOMAIN` and regenerate.

Wildcard certs cover `*.${XCIND_PROXY_DOMAIN}` and the bare domain, so every generated hostname works over HTTPS without per-app cert management.

### Multi-Label Domain Constraint

`XCIND_PROXY_DOMAIN` must contain at least one dot (be multi-label). A single-label
domain (e.g. bare `localhost`) produces a wildcard cert `*.localhost` that strict
TLS clients (macOS curl/Safari, Go) reject. When the proxy sees a single-label
domain under a non-`disabled` TLS mode, it emits an advisory warning rather than
failing. This is why the default is `localhost.scind.io` rather than `localhost`.
See [ADR-0016](../decisions/0016-proxy-domain-wildcard-constraint.md).

---

## DNS Configuration

The default domain `localhost.scind.io` (and subdomains like `app-web.localhost.scind.io`) is a public name whose records resolve to `127.0.0.1`, so it needs no local DNS configuration while still satisfying the [multi-label constraint](#multi-label-domain-constraint).

The single-label `localhost` (and subdomains like `app-web.localhost`) resolves to `127.0.0.1` automatically per RFC 6761, but is subject to the wildcard-cert trust limitation above — use it only when TLS is `disabled`.

For other custom domains, configure DNS resolution:

1. **dnsmasq**: Route all subdomains of your domain to `127.0.0.1`
   ```
   address=/localhost.scind.io/127.0.0.1
   ```
2. **/etc/hosts**: Manual entries for each hostname
3. **Local DNS server**: More complex but flexible

---

## Related Decisions

- [ADR-0002: Two-Layer Networking](../decisions/0002-two-layer-networking.md)
- [ADR-0008: Traefik for Reverse Proxy](../decisions/0008-traefik-reverse-proxy.md)
- [ADR-0009: Flexible TLS Configuration](../decisions/0009-flexible-tls-configuration.md)
- [ADR-0022: External Proxy Mode](../decisions/0022-external-proxy-mode.md)

## Related Documents

- [CLI Reference — xcind-proxy](../reference/cli.md#xcind-proxy) — Command usage
- [Configuration Reference — Global Proxy Configuration](../reference/configuration.md#global-proxy-configuration) — Proxy config variables
