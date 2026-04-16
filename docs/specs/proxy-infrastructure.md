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
| `web` | Configurable (`XCIND_PROXY_HTTP_PORT`, default `80`) | HTTP traffic |
| `websecure` | Configurable (`XCIND_PROXY_HTTPS_PORT`, default `443`) | HTTPS traffic (only when `XCIND_PROXY_TLS_MODE != disabled`) |

The dashboard entrypoint is only added when `XCIND_PROXY_DASHBOARD=true`.
The `websecure` entrypoint and a `file` provider (watching `$XCIND_PROXY_STATE_DIR/dynamic/`) are only emitted when TLS is enabled.

### Dynamic Routing

Routing rules are defined via Docker labels on service containers. Traefik watches for container changes and updates routing automatically via its Docker provider.

See [Docker Labels — Traefik Routing Labels](./docker-labels.md#traefik-routing-labels) for label documentation.

---

## Lifecycle

### `xcind-proxy init`

Creates proxy infrastructure across two directories:

- **Config** (`~/.config/xcind/proxy/`): user-editable `config.sh`; optional `certs/wildcard.{crt,key}` for user-supplied certificates
- **State** (`~/.local/state/xcind/proxy/`): generated `compose.yaml`, `traefik.yaml`, `dynamic/tls.yaml`, and `certs/`

Steps:

1. Creates `config.sh` (only if it doesn't exist — never overwrites user config)
2. Sources `config.sh` for variable expansion
3. Generates `compose.yaml` (always regenerated) in state dir; includes `:443`, `./certs`, and `./dynamic` bind mounts when TLS is enabled
4. Generates `traefik.yaml` (always regenerated) in state dir; includes `websecure` entrypoint and file provider when TLS is enabled
5. Generates `dynamic/tls.yaml` pointing at the wildcard cert (TLS-enabled modes only)
6. Removes any stale generated files from legacy locations — `docker-compose.yaml` / `traefik.yaml` in the config dir (pre-config/state split) and `docker-compose.yaml` in the state dir (pre-rename to Compose-Specification-standard `compose.yaml`)
7. Creates `xcind-proxy` Docker network if it doesn't exist

Certificate provisioning happens lazily on `xcind-proxy up` / auto-start — see [TLS Certificate Management](#tls-certificate-management).

### `xcind-proxy up`

Always regenerates generated files from current `config.sh`, then starts the Traefik container via `__xcind-proxy-ensure-running`.

With `--force`: tears down existing containers, removes the network, re-initializes, and starts fresh.

### `xcind-proxy down`

Stops the Traefik container via `docker compose down`.

### `xcind-proxy status [--json]`

Reports:
- Running/stopped state
- Traefik image version
- HTTP port
- Dashboard URL (if enabled)
- Network existence

With `--json`: outputs a flat JSON object for machine consumption.

### Auto-Start

When `XCIND_PROXY_EXPORTS` is configured for an application, the `xcind-proxy-hook` calls `__xcind-proxy-ensure-running` which automatically initializes and starts the proxy if needed.

Set `XCIND_PROXY_AUTO_START=0` to disable auto-start (the network is still created for compose overlay compatibility).

---

## Traefik Configuration

For complete configuration examples, see the [Proxy Infrastructure Appendix](./appendices/proxy-infrastructure/).

### Generated `traefik.yaml`

```yaml
entryPoints:
  web:
    address: ":80"
  websecure:              # only when TLS is enabled
    address: ":443"

providers:
  docker:
    exposedByDefault: false
    network: xcind-proxy
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

---

## DNS Configuration

For local development, the default domain `localhost` (and subdomains like `app-web.localhost`) resolves to `127.0.0.1` automatically per RFC 6761 — no DNS configuration needed.

For custom domains, configure DNS resolution:

1. **dnsmasq**: Route all `*.xcind.localhost` to `127.0.0.1`
   ```
   address=/xcind.localhost/127.0.0.1
   ```
2. **/etc/hosts**: Manual entries for each hostname
3. **Local DNS server**: More complex but flexible

---

## Related Decisions

- [ADR-0002: Two-Layer Networking](../decisions/0002-two-layer-networking.md)
- [ADR-0008: Traefik for Reverse Proxy](../decisions/0008-traefik-reverse-proxy.md)
- [ADR-0009: Flexible TLS Configuration](../decisions/0009-flexible-tls-configuration.md)

## Related Documents

- [CLI Reference — xcind-proxy](../reference/cli.md#xcind-proxy) — Command usage
- [Configuration Reference — Global Proxy Configuration](../reference/configuration.md#global-proxy-configuration) — Proxy config variables
