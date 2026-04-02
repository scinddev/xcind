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

The dashboard entrypoint is only added when `XCIND_PROXY_DASHBOARD=true`.

### Dynamic Routing

Routing rules are defined via Docker labels on service containers. Traefik watches for container changes and updates routing automatically via its Docker provider.

See [Docker Labels — Traefik Routing Labels](./docker-labels.md#traefik-routing-labels) for label documentation.

---

## Lifecycle

### `xcind-proxy init`

Creates proxy infrastructure across two directories:

- **Config** (`~/.config/xcind/proxy/`): user-editable `config.sh`
- **State** (`~/.local/state/xcind/proxy/`): generated `docker-compose.yaml` and `traefik.yaml`

Steps:

1. Creates `config.sh` (only if it doesn't exist — never overwrites user config)
2. Sources `config.sh` for variable expansion
3. Generates `docker-compose.yaml` (always regenerated) in state dir
4. Generates `traefik.yaml` (always regenerated) in state dir
5. Removes any stale generated files from the config dir (migration cleanup)
6. Creates `xcind-proxy` Docker network if it doesn't exist

### `xcind-proxy up`

Always regenerates generated files from current `config.sh`, then starts the Traefik container via `__xcind-proxy-ensure-running`.

With `--force`: tears down existing containers, removes the network, re-initializes, and starts fresh.

### `xcind-proxy down`

Stops the Traefik container via `docker compose down`.

### `xcind-proxy status`

Reports:
- Running/stopped state
- Traefik image version
- HTTP port
- Dashboard URL (if enabled)
- Network existence

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

providers:
  docker:
    exposedByDefault: false
    network: xcind-proxy

log:
  level: INFO
```

When `XCIND_PROXY_DASHBOARD=true`, the dashboard configuration is appended:

```yaml
api:
  dashboard: true
  insecure: true
```

### Generated `docker-compose.yaml`

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
