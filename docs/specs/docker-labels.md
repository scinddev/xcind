# Docker Labels

Xcind uses Docker labels for service discovery, workspace identification, and Traefik routing. All Xcind-specific labels use the `xcind.` namespace prefix.

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Label names use `xcind.` prefix instead of `scind.`.

---

## Context Labels

Applied to all containers for app and workspace discovery. App labels are applied by the `xcind-app-hook` to every service; workspace labels are applied by the `xcind-workspace-hook` when in workspace mode:

| Label | Description | Example |
|-------|-------------|---------|
| `xcind.app.name` | Application identifier | `frontend` |
| `xcind.app.path` | Absolute path to application directory | `/Users/beau/dev/frontend` |
| `xcind.workspace.name` | Workspace identifier (workspace mode only) | `dev` |
| `xcind.workspace.path` | Absolute path to workspace directory (workspace mode only) | `/Users/beau/dev` |

Workspace labels are only present when the application is running in workspace mode.

---

## Export Labels

Applied to containers with proxy exports, keyed by export name. The `.url` label carries the **preferred scheme** (HTTPS whenever the export has an HTTPS router, HTTP otherwise). `.http.url` is always emitted for proxied exports — every effective TLS mode produces an HTTP router (a normal one for `auto`/`disable`, a redirect-only one for `require`), so the HTTP URL is always reachable. `.https.url` is emitted only when an HTTPS router actually exists.

```
xcind.export.{name}.host={hostname}
xcind.export.{name}.http.url=http://{hostname}    # always (HTTP router always exists)
xcind.export.{name}.https.url=https://{hostname}  # only when HTTPS router exists
xcind.export.{name}.url={preferred-scheme}://{hostname}
```

**Example** — app with two exports, proxy TLS enabled (HTTPS preferred):

```yaml
labels:
  - "xcind.export.api.host=myapp-api.localhost"
  - "xcind.export.api.http.url=http://myapp-api.localhost"
  - "xcind.export.api.https.url=https://myapp-api.localhost"
  - "xcind.export.api.url=https://myapp-api.localhost"
  - "xcind.export.web.host=myapp-web.localhost"
  - "xcind.export.web.http.url=http://myapp-web.localhost"
  - "xcind.export.web.https.url=https://myapp-web.localhost"
  - "xcind.export.web.url=https://myapp-web.localhost"
```

When the proxy runs with `XCIND_PROXY_TLS_MODE=disabled` (or an export sets `tls=disable`), only `.http.url` and an http `.url` label are emitted.

---

## Apex Labels

Applied to the container running the primary (first) export when apex URL generation is enabled. Emits the same shape as the per-export labels — `.http.url` is always emitted (apex always has an HTTP router, redirect-only when the primary export uses `tls=require`), `.https.url` only when an HTTPS apex router exists:

```
xcind.apex.host={apex_hostname}
xcind.apex.http.url=http://{apex_hostname}    # always (HTTP apex router always exists)
xcind.apex.https.url=https://{apex_hostname}  # only when HTTPS apex router exists
xcind.apex.url={preferred-scheme}://{apex_hostname}
```

**Example** — frontend with `web` as primary export, proxy TLS enabled:

```yaml
labels:
  - "xcind.apex.host=dev-frontend.localhost"
  - "xcind.apex.http.url=http://dev-frontend.localhost"
  - "xcind.apex.https.url=https://dev-frontend.localhost"
  - "xcind.apex.url=https://dev-frontend.localhost"
```

---

## Proxy Container Labels

Applied to the Xcind-managed Traefik proxy container:

| Label | Description | Value |
|-------|-------------|-------|
| `xcind.managed` | Indicates Xcind manages this container | `true` |
| `xcind.component` | Component type | `proxy` |

---

## Traefik Routing Labels

Generated automatically by `xcind-proxy-hook` based on `XCIND_PROXY_EXPORTS`. These configure Traefik's dynamic routing.

| Label | Description | Example |
|-------|-------------|---------|
| `traefik.enable` | Exposes container to Traefik | `true` |
| `traefik.docker.network` | Network for Traefik to reach this container | `xcind-proxy` |
| `traefik.http.routers.{name}.rule` | Routing rule (Host matcher) | ``Host(`myapp-api.localhost`)`` |
| `traefik.http.routers.{name}.entrypoints` | Entry points to use | `web` / `websecure` |
| `traefik.http.routers.{name}.tls` | Enable TLS termination (HTTPS routers) | `true` |
| `traefik.http.routers.{name}.service` | Service name for load balancer | `myapp-api-http` |
| `traefik.http.routers.{name}.middlewares` | Attached middlewares (redirect) | `xcind-redirect-to-https@docker` |
| `traefik.http.services.{name}.loadbalancer.server.port` | Container port | `3000` |

### Router Naming

An export can produce up to two routers — `-http` (entrypoint `web`) and `-https` (entrypoint `websecure`, `tls=true`). The suffix is part of the router **name**, not the entrypoint, so existing `-http` routers keep their names when HTTPS is added alongside.

| Mode | Pattern | Example (HTTP / HTTPS) |
|------|---------|------------------------|
| Workspaceless | `{app}-{export}-{protocol}` | `myapp-api-http` / `myapp-api-https` |
| Workspace | `{workspace}-{app}-{export}-{protocol}` | `dev-frontend-web-http` / `dev-frontend-web-https` |

**Apex router names** omit the export segment:

| Mode | Pattern | Example (HTTP / HTTPS) |
|------|---------|------------------------|
| Workspaceless | `{app}-{protocol}` | `myapp-http` / `myapp-https` |
| Workspace | `{workspace}-{app}-{protocol}` | `dev-frontend-http` / `dev-frontend-https` |

### TLS Modes

Which routers are emitted per export is controlled by the `tls` metadata key on the export (and globally constrained by `XCIND_PROXY_TLS_MODE`):

| Effective mode | HTTP router | HTTPS router |
|---|---|---|
| `auto` (default, proxy TLS on) | Yes | Yes |
| `require` (proxy TLS on) | Yes — redirect-only, attaches `xcind-redirect-to-https@docker` middleware | Yes |
| `disable` / proxy TLS disabled | Yes | No |

When any export on the app uses `tls=require`, a shared `xcind-redirect-to-https` `redirectscheme` middleware is emitted on **every** rendered service block of the compose overlay. Traefik's Docker provider only loads labels from running containers, so emitting the middleware on a single "first" service would leave it unresolved whenever that service wasn't running. Repeated middleware definitions with the same name/value are idempotent in Traefik.

### Complete Label Example (proxy TLS enabled, default `tls=auto`)

Workspaceless app with a single proxy export `web` on port 3000:

```yaml
labels:
  # Context labels (from xcind-app-hook)
  - "xcind.app.name=myapp"
  - "xcind.app.path=/Users/beau/myapp"
  # Traefik shared labels
  - "traefik.enable=true"
  - "traefik.docker.network=xcind-proxy"
  # Per-export HTTP router
  - "traefik.http.routers.myapp-web-http.rule=Host(`myapp-web.localhost`)"
  - "traefik.http.routers.myapp-web-http.entrypoints=web"
  - "traefik.http.routers.myapp-web-http.service=myapp-web-http"
  - "traefik.http.services.myapp-web-http.loadbalancer.server.port=3000"
  # Per-export HTTPS router
  - "traefik.http.routers.myapp-web-https.rule=Host(`myapp-web.localhost`)"
  - "traefik.http.routers.myapp-web-https.entrypoints=websecure"
  - "traefik.http.routers.myapp-web-https.tls=true"
  - "traefik.http.routers.myapp-web-https.service=myapp-web-https"
  - "traefik.http.services.myapp-web-https.loadbalancer.server.port=3000"
  # Apex routers (primary export)
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.localhost`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.service=myapp-http"
  - "traefik.http.services.myapp-http.loadbalancer.server.port=3000"
  - "traefik.http.routers.myapp-https.rule=Host(`myapp.localhost`)"
  - "traefik.http.routers.myapp-https.entrypoints=websecure"
  - "traefik.http.routers.myapp-https.tls=true"
  - "traefik.http.routers.myapp-https.service=myapp-https"
  - "traefik.http.services.myapp-https.loadbalancer.server.port=3000"
  # Export labels
  - "xcind.export.web.host=myapp-web.localhost"
  - "xcind.export.web.http.url=http://myapp-web.localhost"
  - "xcind.export.web.https.url=https://myapp-web.localhost"
  - "xcind.export.web.url=https://myapp-web.localhost"
  # Apex labels
  - "xcind.apex.host=myapp.localhost"
  - "xcind.apex.http.url=http://myapp.localhost"
  - "xcind.apex.https.url=https://myapp.localhost"
  - "xcind.apex.url=https://myapp.localhost"
```

---

## External Tool Integration

External tools can discover Xcind-managed services by querying Docker labels:

```bash
# Find all Xcind-managed containers
docker ps --filter "label=xcind.app.name" --format "{{.Names}}"

# Find all containers for a specific workspace
docker ps --filter "label=xcind.workspace.name=dev" --format "{{.Names}}"

# Find the proxy container
docker ps --filter "label=xcind.component=proxy" --format "{{.Names}}"
```

---

## Related Documents

- [Proxy Infrastructure](./proxy-infrastructure.md) — Traefik configuration and routing
- [Generated Override Files](./generated-override-files.md) — How labels are generated
- [Naming Conventions](./naming-conventions.md) — Naming patterns for labels
