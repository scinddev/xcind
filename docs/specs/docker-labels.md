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

Applied to containers with proxy exports, keyed by export name:

```
xcind.export.{name}.host={hostname}
xcind.export.{name}.url=http://{hostname}
```

**Example** — app with two exports (`api` and `web`):

```yaml
labels:
  - "xcind.export.api.host=myapp-api.localhost"
  - "xcind.export.api.url=http://myapp-api.localhost"
  - "xcind.export.web.host=myapp-web.localhost"
  - "xcind.export.web.url=http://myapp-web.localhost"
```

---

## Apex Labels

Applied to the container running the primary (first) export when apex URL generation is enabled:

```
xcind.apex.host={apex_hostname}
xcind.apex.url=http://{apex_hostname}
```

**Example** — frontend with `web` as primary export:

```yaml
labels:
  - "xcind.apex.host=dev-frontend.localhost"
  - "xcind.apex.url=http://dev-frontend.localhost"
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
| `traefik.http.routers.{name}.entrypoints` | Entry points to use | `web` |
| `traefik.http.routers.{name}.service` | Service name for load balancer | `myapp-api-http` |
| `traefik.http.services.{name}.loadbalancer.server.port` | Container port | `3000` |

### Router Naming

Router names follow the configured template patterns:

| Mode | Pattern | Example |
|------|---------|---------|
| Workspaceless | `{app}-{export}-{protocol}` | `myapp-api-http` |
| Workspace | `{workspace}-{app}-{export}-{protocol}` | `dev-frontend-web-http` |

**Apex router names** omit the export segment:

| Mode | Pattern | Example |
|------|---------|---------|
| Workspaceless | `{app}-{protocol}` | `myapp-http` |
| Workspace | `{workspace}-{app}-{protocol}` | `dev-frontend-http` |

### Complete Label Example

Workspaceless app with a single proxy export `web` on port 3000:

```yaml
labels:
  # Traefik routing
  - "traefik.enable=true"
  - "traefik.docker.network=xcind-proxy"
  - "traefik.http.routers.myapp-web-http.rule=Host(`myapp-web.localhost`)"
  - "traefik.http.routers.myapp-web-http.entrypoints=web"
  - "traefik.http.routers.myapp-web-http.service=myapp-web-http"
  - "traefik.http.services.myapp-web-http.loadbalancer.server.port=3000"
  # Apex routing (primary export)
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.localhost`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.service=myapp-http"
  - "traefik.http.services.myapp-http.loadbalancer.server.port=3000"
  # Context labels
  - "xcind.app.name=myapp"
  - "xcind.app.path=/Users/beau/myapp"
  # Export labels
  - "xcind.export.web.host=myapp-web.localhost"
  - "xcind.export.web.url=http://myapp-web.localhost"
  # Apex labels
  - "xcind.apex.host=myapp.localhost"
  - "xcind.apex.url=http://myapp.localhost"
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
