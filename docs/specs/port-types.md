# Port Types

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind uses the `XCIND_PROXY_EXPORTS` array syntax instead of YAML `exported_services`; port *type* is expressed as a metadata attribute rather than a structural choice.

---

## Overview

Xcind exposes application ports through two mechanisms, both declared in a single `XCIND_PROXY_EXPORTS` array and dispatched by `type`:

| Type | Behavior | Hook | Output |
|------|----------|------|--------|
| `proxied` *(default)* | Routed through the shared Traefik proxy on a generated hostname | `xcind-proxy-hook` | `compose.proxy.yaml` (Traefik labels) |
| `assigned` | Direct host-port binding, auto-assigned when the declared port is unavailable, sticky across restarts | `xcind-assigned-hook` | `compose.assigned.yaml` (`ports:` mapping) |

Services not listed in `XCIND_PROXY_EXPORTS` remain private — accessible only within the application's own Docker Compose network.

In workspace mode, all services (including private ones) receive aliases on the `{workspace}-internal` network via `xcind-workspace-hook`, enabling inter-app communication.

## Export Entry Format

```
export_name[=compose_service][:port][;key=value[;key=value…]]
```

| Entry | Export Name | Compose Service | Port | Type |
|-------|-------------|-----------------|------|------|
| `"web"` | `web` | `web` | *(inferred)* | `proxied` |
| `"api=uvicorn:8080"` | `api` | `uvicorn` | `8080` | `proxied` |
| `"worker:9000;type=assigned"` | `worker` | `worker` | `9000` | `assigned` |
| `"database=db:3306;type=assigned"` | `database` | `db` | `3306` | `assigned` |

Only `type` is accepted in the metadata section today; unknown keys and invalid `type` values cause the hooks to fail fast.

## Proxied Ports

Traffic is routed through Traefik on the HTTP entrypoint (port configurable via `XCIND_PROXY_HTTP_PORT`, default `80`).

| Aspect | Value |
|--------|-------|
| Routing | Through Traefik via `Host()` rule |
| Hostname | Generated from `XCIND_APP_URL_TEMPLATE` (e.g., `myapp-api.localhost`) |
| Protocol | HTTP (Traefik `web` entrypoint) |
| Container port | Specified in the entry or inferred from compose config |

## Assigned Ports

The declared port is tried first; if taken, `xcind-assigned-hook` scans upward for a free host port and records the assignment, so subsequent runs reuse the same external port.

| Aspect | Value |
|--------|-------|
| Routing | Direct host-port publish (`"hostPort:containerPort"`) |
| State file | `${XDG_STATE_HOME:-~/.local/state}/xcind/proxy/assigned-ports.tsv` |
| Concurrency | Serialized with `flock(1)` when available |
| Fallback when declared port is in use | Scan upward up to `XCIND_ASSIGNED_PORTS_MAX_ATTEMPTS` (default 100) |

### Port Inference

When the port is omitted from an entry, the owning hook infers it from the compose service's port mapping:

- If the service has **exactly one** port mapping, that port's target is used
- If the service has **zero** or **multiple** port mappings, an error is reported asking for explicit port specification

Note: `yq` is required whenever `XCIND_PROXY_EXPORTS` is configured — for service validation, config inspection, and port inference.

---

## Related Documents

- [Naming Conventions](./naming-conventions.md) — Hostname and router name patterns
- [Proxy Infrastructure](./proxy-infrastructure.md) — Traefik configuration for proxied ports
- [Generated Override Files](./generated-override-files.md) — How port types translate to Docker labels
- [Configuration Reference — XCIND_PROXY_EXPORTS](../reference/configuration.md#xcind_proxy_exports) — Export syntax reference
