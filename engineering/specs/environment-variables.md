# Environment Variables

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind generates `XCIND_*` variables, not `SCIND_*`.

---

## Overview

Xcind exposes export hostnames, ports, and URLs to applications two ways:

1. **Injected discovery variables** (`xcind-discovery-hook` → `compose.discovery.yaml`) — an `environment:` block of `XCIND_{APP}_{EXPORT}_*` variables added to every container of the current app, so application code can read its own service hostnames at runtime without hardcoding them.
2. **Docker labels** (`xcind-proxy-hook` → `compose.proxy.yaml`) — the same hostname/URL information as labels, for external tooling that inspects containers.

This document covers both. See [ADR-0018](../decisions/0018-service-discovery-env-injection.md) for the injection design.

---

## Injected Discovery Variables

For each export the `xcind-discovery-hook` generates `environment:` variables and attaches the full set to every service of the current app.

**Scope (v1)**: own-app only — a container receives the discovery variables for its *own* app's exports, not other apps' exports. (Workspace-wide cross-app discovery is a possible future extension.)

**Name transformation**: the application and export name segments are independently converted — hyphens to underscores, then uppercased (e.g. `shared-db` → `SHARED_DB`). Pattern: `XCIND_{APP}_{EXPORT}_{SUFFIX}`.

### Proxied exports

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_{E}_HOST` | Proxied hostname (e.g. `myapp-web.localhost.scind.io`) |
| `XCIND_{APP}_{E}_PORT` | Proxy entrypoint port — `XCIND_PROXY_HTTPS_PORT` (default 443) for https, `XCIND_PROXY_HTTP_PORT` (default 80) for http |
| `XCIND_{APP}_{E}_SCHEME` | `http` or `https` |
| `XCIND_{APP}_{E}_URL` | `{scheme}://{hostname}` |

When an export serves **both** schemes, base variables default to HTTPS, and protocol-specific variables are also emitted: `XCIND_{APP}_{E}_HTTPS_HOST/_PORT/_URL` and `XCIND_{APP}_{E}_HTTP_HOST/_PORT/_URL`. Prefer HTTPS for service-to-service traffic; use the `_HTTP_*` variants only when HTTP is explicitly required.

### Apex variables

For the apex export — the **first `proxied` export** (Xcind's positional rule; see [ADR-0017](../decisions/0017-apex-url-reporting.md)) — and only when an apex URL template is configured:

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_APEX_HOST` | Apex hostname (e.g. `myapp.localhost.scind.io`) |
| `XCIND_{APP}_APEX_PORT` | Apex entrypoint port |
| `XCIND_{APP}_APEX_SCHEME` | `http` or `https` |
| `XCIND_{APP}_APEX_URL` | `{scheme}://{apex_hostname}` |

No apex variables are emitted when there is no proxied export (an assigned-type export never anchors the apex).

### Assigned exports

Assigned exports have no proxy URL; they expose an in-network host plus ports:

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_{E}_HOST` | In-network host — the `{app}-{service}` network alias in workspace mode, otherwise the compose service name |
| `XCIND_{APP}_{E}_PORT` | Container port (use with `_HOST` for in-network, container-to-container access) |
| `XCIND_{APP}_{E}_HOST_PORT` | Allocated host-published port (use from the host machine) |

> Xcind divergence from Scind: assigned exports additionally expose `_HOST_PORT` so applications can reach the service from the host, while `_HOST`/`_PORT` describe the in-network pair.

### Workspace variable

| Variable | Value |
|----------|-------|
| `XCIND_WORKSPACE_NAME` | The workspace name (workspace mode only) |

### Generation rules

| Type | `_HOST` | `_PORT` | `_HOST_PORT` | `_SCHEME` / `_URL` | Protocol vars |
|------|---------|---------|--------------|--------------------|---------------|
| `proxied` (https) | Proxied hostname | 443 | — | ✓ | — |
| `proxied` (http) | Proxied hostname | 80 | — | ✓ | — |
| `proxied` (both) | Proxied hostname | 443 (HTTPS default) | — | ✓ | `_HTTPS_*` + `_HTTP_*` |
| `assigned` | In-network host | Container port | Allocated host port | — | — |
| `proxied` (apex) | Apex hostname | apex entrypoint port | — | ✓ | — |

### Usage in applications

```bash
# Proxied service — use the URL directly
API_URL="${XCIND_MYAPP_API_URL:-https://myapp-api.localhost.scind.io}"

# Assigned service — build a connection from the in-network host + container port
psql "host=${XCIND_MYAPP_DB_HOST} port=${XCIND_MYAPP_DB_PORT} dbname=app"

# Same assigned service from the host machine
psql "host=localhost port=${XCIND_MYAPP_DB_HOST_PORT} dbname=app"
```

> **Precedence**: `compose.discovery.yaml` is merged last, so these variables win over an `environment:` value of the same key declared in your base compose file.

---

## Labels Generated Per Export

For each entry in `XCIND_PROXY_EXPORTS`, the proxy hook generates:

| Label | Value |
|-------|-------|
| `xcind.export.{name}.host` | Generated hostname (e.g., `myapp-api.localhost`) |
| `xcind.export.{name}.url` | Full URL (e.g., `http://myapp-api.localhost`) |

For the primary (first) export, apex labels are also generated:

| Label | Value |
|-------|-------|
| `xcind.apex.host` | Apex hostname (e.g., `myapp.localhost`) |
| `xcind.apex.url` | Apex URL (e.g., `http://myapp.localhost`) |

## Context Labels

All containers with proxy exports also receive context labels:

| Label | Value |
|-------|-------|
| `xcind.app.name` | Application name |
| `xcind.app.path` | Absolute path to application directory |
| `xcind.workspace.name` | Workspace name (workspace mode only) |
| `xcind.workspace.path` | Absolute path to workspace directory (workspace mode only) |

## Workspace Network Aliases

In workspace mode, `xcind-workspace-hook` generates network aliases for all compose services on the `{workspace}-internal` network. These aliases enable inter-app communication using the `XCIND_WORKSPACE_SERVICE_TEMPLATE` pattern (default: `{app}-{service}`).

| Alias Pattern | Example |
|---------------|---------|
| `{app}-{service}` | `frontend-web`, `backend-api`, `shared-db-postgres` |

Applications can reference other services using these predictable aliases.

## App Environment File Injection

When `XCIND_APP_ENV_FILES` is configured, the `xcind-app-env-hook` generates a compose overlay that adds `env_file:` directives to all services, making those environment files available inside running containers.

This is separate from `XCIND_COMPOSE_ENV_FILES`, which provides variables for YAML interpolation only.

## Read-only / behavioral flags

Unlike the generated labels above, these are **input** variables you set in the
environment to change Xcind's behavior.

| Variable | Effect |
|----------|--------|
| `XCIND_NO_REGISTRY` | When set (non-empty), skip the automatic workspace-registry write during discovery. Discovery, config sourcing, and all `XCIND_*` variable resolution still run unchanged — only the registry write is suppressed. Intended for read-only callers (e.g. the prompt helper) that must not mutate shared state. Unset or empty = register as usual. |

---

## Related Documents

- [Docker Labels](./docker-labels.md) — Complete label reference
- [Generated Override Files](./generated-override-files.md) — How labels are injected
- [Configuration Reference](../reference/configuration.md) — `XCIND_PROXY_EXPORTS` and `XCIND_APP_ENV_FILES` syntax
- [Naming Conventions](./naming-conventions.md) — Hostname and alias patterns
