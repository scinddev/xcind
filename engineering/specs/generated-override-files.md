# Generated Override Files

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind uses a hook-based generation pipeline writing to `.xcind/generated/`.

---

## Overview

Xcind generates Docker Compose override files via hooks that extend application compose files without modifying them. This implements the pure overlay design (see [ADR-0003](../decisions/0003-pure-overlay-design.md)).

## Generated File Location

**Location**: `{app_root}/.xcind/generated/{sha}/`

Each hook writes a separate compose file:

| Hook | Generated File | Purpose |
|------|---------------|---------|
| `xcind-naming-hook` | `compose.naming.yaml` | Sets Docker Compose project `name:` |
| `xcind-app-hook` | `compose.app.yaml` | App identity labels (`xcind.app.*`) on all services |
| `xcind-app-env-hook` | `compose.app-env.yaml` | Injects `XCIND_APP_ENV_FILES` via `env_file:` |
| `xcind-host-gateway-hook` | `compose.host-gateway.yaml` | Maps `host.docker.internal` via `extra_hosts` |
| `xcind-proxy-hook` | `compose.proxy.yaml` | Traefik labels, proxy network, export labels |
| `xcind-assigned-hook` | `compose.assigned.yaml` | Stable host port bindings with flock-serialized state |
| `xcind-workspace-hook` | `compose.workspace.yaml` | Workspace network aliases and identity labels |
| `xcind-discovery-hook` | `compose.discovery.yaml` | Service-discovery `environment:` vars (`XCIND_{APP}_{EXPORT}_*`) on all services |

These files are gitignored and regenerated on cache miss.

---

## Caching

Hook output is cached under `{app_root}/.xcind/generated/{sha}/`, keyed by a SHA-256 hash that `__xcind-compute-sha` builds from every input the GENERATE hooks treat as pure. The complete input set is:

- **Compose files** — every `-f` path resolved into `XCIND_DOCKER_COMPOSE_OPTS`, sorted, plus the content hash of each path that exists.
- **Compose env files** — every path resolved from `XCIND_COMPOSE_ENV_FILES`, plus the content hash of each that exists.
- **App env files** — every path resolved from `XCIND_APP_ENV_FILES`, plus the content hash of each that exists.
- **App `.xcind.sh`** — content hash when present.
- **Workspace `.xcind.sh`** — content hash when in workspace mode (`XCIND_WORKSPACELESS=0` and `XCIND_WORKSPACE_ROOT` set).
- **Additional config files and their overrides** — every path tracked in `__XCIND_SOURCED_CONFIG_FILES` (workspace and app `XCIND_ADDITIONAL_CONFIG_FILES` plus their `.override.sh` siblings, and the workspace/app `.xcind.override.sh` files), excluding the app and workspace `.xcind.sh` already hashed above.
- **Global proxy config** — content hash of `${XDG_CONFIG_HOME:-$HOME/.config}/xcind/proxy/config.sh` when present.
- **`XCIND_TOOLS`** — the full declarations array, joined newline-separated, when non-empty.
- **Naming inputs** — the literal values of `XCIND_APP`, `XCIND_WORKSPACE`, and `XCIND_WORKSPACELESS`, so naming overrides invalidate the cache even if no file changed.
- **Host-gateway configuration** — the literal values of `XCIND_HOST_GATEWAY_ENABLED` and `XCIND_HOST_GATEWAY`.
- **Detected host-gateway value** — when `XCIND_HOST_GATEWAY_ENABLED` is not `0`, the output of `__xcind-detect-host-gateway` is included so DHCP/VPN/WSL2-mode changes invalidate the cache even when configuration is stable.

A cache entry is treated as a hit only when both:

1. A `.complete` marker file exists in `.xcind/generated/{sha}/` (written atomically after every GENERATE hook succeeds), and
2. Every hook currently registered in `XCIND_HOOKS_GENERATE` has a persisted `.hook-output-{name}` file in that directory.

A missing marker, a missing per-hook output, or a hook newly added to `XCIND_HOOKS_GENERATE` since the last run forces a full rebuild rather than a partial replay. On cache miss, the generated directory is rebuilt atomically: any prior contents are removed, the directory is recreated, hooks run in registration order, and the `.complete` marker (which records the registered hook list for diagnostics) is written only after every hook succeeds. If a hook fails mid-run, the partial generated directory is removed before the error propagates so the next invocation rebuilds from scratch.

Hooks listed in `XCIND_HOOKS_ALWAYS` (currently `xcind-assigned-hook`) are exempt from the replay-only behavior: on a cache hit they are re-run against current live state, their persisted `.hook-output-{name}` is refreshed, and any deleted overlay file they own is regenerated. Pure GENERATE hooks (naming, app, app-env, host-gateway, proxy, workspace) continue to replay from `.hook-output-{name}` without re-execution. See [Hook Lifecycle: GENERATE](./hook-lifecycle.md#generate) for the full contract.

The cache directory also stores two sibling artifacts that are not part of hook output:

- `resolved-config.yaml` — `docker compose config` output, written **before** hooks run so hooks that need the resolved service list can read it.
- `config.json` — `xcind-config --json` output, written **after** `__xcind-run-hooks` so the cached JSON reflects post-hook updates such as `assignedExports` populated by `xcind-assigned-hook`. Written via a `.tmp` sidecar and `mv` so a failed `jq` run never leaves a corrupt file; the write is a no-op when `jq` is unavailable.

---

## Generated Content Examples

### `compose.naming.yaml`

Sets the Docker Compose project name to prevent container/volume/network collisions:

```yaml
name: dev-frontend
```

In workspaceless mode:

```yaml
name: frontend
```

### `compose.app.yaml`

Generated for all apps. Applies `xcind.app.name` and `xcind.app.path` labels to every service, making all xcind-managed containers discoverable via Docker labels:

```yaml
services:

  web:
    labels:
      - "xcind.app.name=frontend"
      - "xcind.app.path=/Users/beau/dev/frontend"

  worker:
    labels:
      - "xcind.app.name=frontend"
      - "xcind.app.path=/Users/beau/dev/frontend"
```

### `compose.app-env.yaml`

Generated when `XCIND_APP_ENV_FILES` is configured. Injects environment files into all compose services via `env_file:`:

```yaml
services:

  web:
    env_file:
      - /Users/beau/dev/frontend/.env
      - /Users/beau/dev/frontend/.env.local

  worker:
    env_file:
      - /Users/beau/dev/frontend/.env
      - /Users/beau/dev/frontend/.env.local
```

Paths are resolved to absolute paths. Only files that exist on disk are included.

### `compose.host-gateway.yaml`

Generated by default (unless disabled with `XCIND_HOST_GATEWAY_ENABLED=0`). Maps `host.docker.internal` to the developer's workstation for every service that doesn't already define the mapping. The target value is auto-detected based on the platform (native Linux, WSL2, Docker Desktop) or can be overridden with `XCIND_HOST_GATEWAY`.

> For details on the detection algorithm and platform-specific behavior, see the [Scind specification for host.docker.internal normalization](https://github.com/scinddev/scind).

```yaml
services:

  web:
    extra_hosts:
      - "host.docker.internal:host-gateway"

  worker:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Services that already have a `host.docker.internal` entry in `extra_hosts` (using either `:` or `=` separator) are omitted. On Docker Desktop, where `host.docker.internal` is resolved via DNS automatically, the hook produces no output.

### `compose.proxy.yaml`

Generated when `XCIND_PROXY_EXPORTS` is configured. Contains Traefik routing labels, network attachments, and export labels. Context labels (`xcind.app.*`, `xcind.workspace.*`) are handled by the dedicated app and workspace hooks:

```yaml
services:

  web:
    networks:
      default: {}
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.docker.network=xcind-proxy"
      # HTTP router
      - "traefik.http.routers.dev-frontend-web-http.rule=Host(`dev-frontend-web.localhost`)"
      - "traefik.http.routers.dev-frontend-web-http.entrypoints=web"
      - "traefik.http.routers.dev-frontend-web-http.service=dev-frontend-web-http"
      - "traefik.http.services.dev-frontend-web-http.loadbalancer.server.port=80"
      # HTTPS router (emitted when XCIND_PROXY_TLS_MODE != disabled)
      - "traefik.http.routers.dev-frontend-web-https.rule=Host(`dev-frontend-web.localhost`)"
      - "traefik.http.routers.dev-frontend-web-https.entrypoints=websecure"
      - "traefik.http.routers.dev-frontend-web-https.tls=true"
      - "traefik.http.routers.dev-frontend-web-https.service=dev-frontend-web-https"
      - "traefik.http.services.dev-frontend-web-https.loadbalancer.server.port=80"
      # Apex routers
      - "traefik.http.routers.dev-frontend-http.rule=Host(`dev-frontend.localhost`)"
      - "traefik.http.routers.dev-frontend-http.entrypoints=web"
      - "traefik.http.routers.dev-frontend-http.service=dev-frontend-http"
      - "traefik.http.services.dev-frontend-http.loadbalancer.server.port=80"
      - "traefik.http.routers.dev-frontend-https.rule=Host(`dev-frontend.localhost`)"
      - "traefik.http.routers.dev-frontend-https.entrypoints=websecure"
      - "traefik.http.routers.dev-frontend-https.tls=true"
      - "traefik.http.routers.dev-frontend-https.service=dev-frontend-https"
      - "traefik.http.services.dev-frontend-https.loadbalancer.server.port=80"
      # Export labels — preferred URL is https when TLS is enabled
      - "xcind.export.web.host=dev-frontend-web.localhost"
      - "xcind.export.web.http.url=http://dev-frontend-web.localhost"
      - "xcind.export.web.https.url=https://dev-frontend-web.localhost"
      - "xcind.export.web.url=https://dev-frontend-web.localhost"
      - "xcind.apex.host=dev-frontend.localhost"
      - "xcind.apex.http.url=http://dev-frontend.localhost"
      - "xcind.apex.https.url=https://dev-frontend.localhost"
      - "xcind.apex.url=https://dev-frontend.localhost"

networks:
  xcind-proxy:
    external: true
```

The example above reflects the default `XCIND_PROXY_TLS_MODE=auto` behavior. When TLS is disabled (`XCIND_PROXY_TLS_MODE=disabled` or per-export `tls=disable`), only HTTP routers are emitted and `.url` labels use `http://`. For a complete unabridged example, see the [Generated Override Files Appendix](./appendices/generated-override-files/).

### `compose.workspace.yaml`

Generated only in workspace mode. Applies `xcind.workspace.name` and `xcind.workspace.path` labels and connects all services to the workspace internal network with aliases:

```yaml
services:

  web:
    labels:
      - "xcind.workspace.name=dev"
      - "xcind.workspace.path=/Users/beau/dev"
    networks:
      default: {}
      dev-internal:
        aliases:
          - frontend-web

  db:
    labels:
      - "xcind.workspace.name=dev"
      - "xcind.workspace.path=/Users/beau/dev"
    networks:
      default: {}
      dev-internal:
        aliases:
          - frontend-db

networks:
  dev-internal:
    external: true
```

---

### `compose.discovery.yaml`

Injects an `environment:` block of service-discovery variables onto every
service of the current app, so applications can read their own export
hostnames, ports, and URLs at runtime without hardcoding them. The same block
is attached to every service (own-app scope). Generated last so its values win
on key collision.

```yaml
services:

  web:
    environment:
      - "XCIND_MYAPP_WEB_HOST=myapp-web.localhost.scind.io"
      - "XCIND_MYAPP_WEB_PORT=443"
      - "XCIND_MYAPP_WEB_SCHEME=https"
      - "XCIND_MYAPP_WEB_URL=https://myapp-web.localhost.scind.io"
      - "XCIND_MYAPP_APEX_HOST=myapp.localhost.scind.io"
      - "XCIND_MYAPP_APEX_URL=https://myapp.localhost.scind.io"
      - "XCIND_MYAPP_DB_HOST=myapp-db"
      - "XCIND_MYAPP_DB_PORT=5432"
      - "XCIND_MYAPP_DB_HOST_PORT=54320"

  db:
    environment:
      # …same block…
```

See [Environment Variables](./environment-variables.md) for the full schema and
[ADR-0018](../decisions/0018-service-discovery-env-injection.md) for the design.

---

## Merge Order

Docker Compose files are merged by `docker compose` in this order:

```
docker compose \
  -f compose.yaml \
  [-f compose.override.yaml] \
  -f .xcind/generated/{sha}/compose.naming.yaml \
  -f .xcind/generated/{sha}/compose.app.yaml \
  -f .xcind/generated/{sha}/compose.app-env.yaml \
  -f .xcind/generated/{sha}/compose.host-gateway.yaml \
  -f .xcind/generated/{sha}/compose.proxy.yaml \
  -f .xcind/generated/{sha}/compose.assigned.yaml \
  -f .xcind/generated/{sha}/compose.workspace.yaml \
  -f .xcind/generated/{sha}/compose.discovery.yaml
```

Application compose files come first (resolved by xcind from `XCIND_COMPOSE_FILES`), followed by hook-generated files in registration order.

---

## Related Documents

- [Hook Lifecycle](./hook-lifecycle.md) — Full hook phase specification (GENERATE, EXECUTE, and future phases)
- [ADR-0003: Pure Overlay Design](../decisions/0003-pure-overlay-design.md) — Design rationale
- [Docker Labels](./docker-labels.md) — Label conventions in generated files
- [Naming Conventions](./naming-conventions.md) — Naming patterns used in generation
- [Architecture Overview](../architecture/overview.md) — Caching and hook pipeline
