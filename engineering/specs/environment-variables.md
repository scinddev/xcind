# Environment Variables

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind generates `XCIND_*` variables, not `SCIND_*`.

---

## Overview

Xcind exposes export hostnames, ports, and URLs to applications two ways:

1. **Injected discovery variables** (`xcind-discovery-hook` → `compose.discovery.yaml`) — an `environment:` block of `XCIND_{APP}_{EXPORT}_*` variables added to every container of the current app, so application code can read its own service hostnames at runtime without hardcoding them.
2. **Docker labels** (`xcind-proxy-hook` → `compose.proxy.yaml`) — the same hostname/URL information as labels, for external tooling that inspects containers.

This document covers both. See [ADR-0018](../decisions/0018-service-discovery-env-injection.md) for the injection design and [ADR-0024](../decisions/0024-internal-external-discovery-and-unpublished-exports.md) for the internal/external pairs and unpublished exports.

---

## Injected Discovery Variables

For each export the `xcind-discovery-hook` generates `environment:` variables and attaches the full set to every service of the current app.

**Scope (v1)**: own-app only — a container receives the discovery variables for its *own* app's exports, not other apps' exports. (Workspace-wide cross-app discovery is a possible future extension.)

**Name transformation**: the application and export name segments are independently converted — hyphens to underscores, then uppercased (e.g. `shared-db` → `SHARED_DB`). Pattern: `XCIND_{APP}_{EXPORT}_{SUFFIX}`.

**Prefix collisions are errors.** When two different `XCIND_PROXY_EXPORTS` entries produce the same `XCIND_{APP}_{EXPORT}` prefix — one name declared with two definitions, `a-b` next to `a_b`, or an export named `apex` while apex variables are active — generation fails and names both entries. Byte-identical repeated entries are allowed (the port is normalized, so `80` equals `80/tcp`). Give each port of a multi-port service its own export name. Generation also fails when one variable name is produced twice with different values — for example by an export named `api-internal` next to an export named `api`, whose `_INTERNAL_HOST` has the same name.

**Internal and external pairs.** Every export also carries explicit address pairs, so a consumer never has to know which view the base `_HOST`/`_PORT` follow:

| Pair | Meaning | Views |
|------|---------|-------|
| `_INTERNAL_HOST` / `_INTERNAL_PORT` | Address inside Docker: the in-network host (the `{app}-{service}` alias in workspace mode, else the compose service name) and the container port | Container view only |
| `_EXTERNAL_HOST` / `_EXTERNAL_PORT` | Address outside Docker: what a host or LAN client uses | Both views, same value (view-invariant) |

Inside a container, `_EXTERNAL_*` answers "what do I tell an outside client?", not "what do I dial from here?".

### Proxied exports

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_{E}_HOST` | Proxied hostname (e.g. `myapp-web.localhost.scind.io`) |
| `XCIND_{APP}_{E}_PORT` | Proxy entrypoint port — `XCIND_PROXY_HTTPS_PORT` (default 443) for https, `XCIND_PROXY_HTTP_PORT` (default 80) for http |
| `XCIND_{APP}_{E}_SCHEME` | `http` or `https` |
| `XCIND_{APP}_{E}_URL` | `{scheme}://{hostname}` with `:port` appended when the proxy entrypoint uses a non-default port |

| `XCIND_{APP}_{E}_INTERNAL_HOST` | In-network host (container view only) |
| `XCIND_{APP}_{E}_INTERNAL_PORT` | Container port: the entry's explicit port, else the single port mapping inferred from the resolved compose config (container view only) |
| `XCIND_{APP}_{E}_EXTERNAL_HOST` | Same as `_HOST` |
| `XCIND_{APP}_{E}_EXTERNAL_PORT` | Same as `_PORT` |

When an export serves **both** schemes, base variables default to HTTPS, and protocol-specific variables are also emitted: `XCIND_{APP}_{E}_HTTPS_HOST/_PORT/_URL` and `XCIND_{APP}_{E}_HTTP_HOST/_PORT/_URL`. Prefer HTTPS for traffic that goes through the proxy; use the `_HTTP_*` variants only when HTTP is explicitly required. For direct container-to-container traffic, use `_INTERNAL_HOST`/`_INTERNAL_PORT`.

### Apex variables

For the apex export — the **first `proxied` export** (Xcind's positional rule; see [ADR-0017](../decisions/0017-apex-url-reporting.md)) — and only when an apex URL template is configured:

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_APEX_HOST` | Apex hostname (e.g. `myapp.localhost.scind.io`) |
| `XCIND_{APP}_APEX_PORT` | Apex entrypoint port |
| `XCIND_{APP}_APEX_SCHEME` | `http` or `https` |
| `XCIND_{APP}_APEX_URL` | `{scheme}://{apex_hostname}` with `:port` appended when the proxy entrypoint uses a non-default port |

No apex variables are emitted when there is no proxied export (an assigned-type export never anchors the apex).

### Assigned exports

Assigned exports have no proxy URL; they expose an in-network host plus ports:

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_{E}_HOST` | In-network host — the `{app}-{service}` network alias in workspace mode, otherwise the compose service name |
| `XCIND_{APP}_{E}_PORT` | Container port (use with `_HOST` for in-network, container-to-container access) |
| `XCIND_{APP}_{E}_HOST_PORT` | Allocated host-published port (use from the host machine) |
| `XCIND_{APP}_{E}_INTERNAL_HOST` / `_INTERNAL_PORT` | Same as `_HOST` / `_PORT` (container view only) |
| `XCIND_{APP}_{E}_EXTERNAL_HOST` | Host-reachable host: `127.0.0.1`, or the export's URL-template hostname when `XCIND_HOST_ENV_ASSIGNED_HOST=hostname` |
| `XCIND_{APP}_{E}_EXTERNAL_PORT` | Allocated host-published port |

> Xcind divergence from Scind: assigned exports additionally expose `_HOST_PORT` so applications can reach the service from the host, while `_HOST`/`_PORT` describe the in-network pair.

### Unpublished exports

A `type=unpublished` export declares a port for discovery only: no Traefik router, no host port, and no assigned-port state. Use it for a port that only other containers need, such as the SMTP side of a mail catcher. Its variables exist in the **container view only**; the host-view env file never contains them.

| Variable | Value |
|----------|-------|
| `XCIND_{APP}_{E}_HOST` | In-network host — the `{app}-{service}` network alias in workspace mode, otherwise the compose service name |
| `XCIND_{APP}_{E}_PORT` | Container port: explicit, else inferred from a single port mapping |
| `XCIND_{APP}_{E}_INTERNAL_HOST` / `_INTERNAL_PORT` | Same as `_HOST` / `_PORT` |

The port must resolve and the compose service must exist; otherwise generation fails with an export-named error.

### Workspace variable

| Variable | Value |
|----------|-------|
| `XCIND_WORKSPACE_NAME` | The workspace name (workspace mode only) |

### Generation rules

Container view:

| Type | `_HOST` | `_PORT` | `_HOST_PORT` | `_SCHEME` / `_URL` | Protocol vars | `_INTERNAL_*` | `_EXTERNAL_*` |
|------|---------|---------|--------------|--------------------|---------------|---------------|---------------|
| `proxied` (https) | Proxied hostname | 443 | — | ✓ | — | ✓ | ✓ |
| `proxied` (http) | Proxied hostname | 80 | — | ✓ | — | ✓ | ✓ |
| `proxied` (both) | Proxied hostname | 443 (HTTPS default) | — | ✓ | `_HTTPS_*` + `_HTTP_*` | ✓ | ✓ |
| `assigned` | In-network host | Container port | Allocated host port | — | — | ✓ | ✓ |
| `unpublished` | In-network host | Container port | — | — | — | ✓ | — |
| `proxied` (apex) | Apex hostname | apex entrypoint port | — | ✓ | — | — | — |

Host view (`XCIND_HOST_ENV_FILE`): proxied and apex rows are unchanged; `assigned` `_HOST`/`_PORT` become the external host and the host port; no row has `_INTERNAL_*`; `unpublished` exports are absent.

### Usage in applications

```bash
# Proxied service — use the URL directly
API_URL="${XCIND_MYAPP_API_URL:-https://myapp-api.localhost.scind.io}"

# Assigned service — build a connection from the in-network host + container port
psql "host=${XCIND_MYAPP_DB_HOST} port=${XCIND_MYAPP_DB_PORT} dbname=app"

# Same assigned service from the host machine
psql "host=localhost port=${XCIND_MYAPP_DB_HOST_PORT} dbname=app"

# Unpublished SMTP port of a mail catcher (containers only)
MAILER_DSN="smtp://${XCIND_MYAPP_SMTP_HOST}:${XCIND_MYAPP_SMTP_PORT}"

# A proxied web service reached directly on the Docker network
curl "http://${XCIND_MYAPP_WEB_INTERNAL_HOST}:${XCIND_MYAPP_WEB_INTERNAL_PORT}/health"
```

> **Precedence**: `compose.discovery.yaml` is merged last, so these variables win over an `environment:` value of the same key declared in your base compose file.

When `XCIND_PROXY_HTTP_PORT` or `XCIND_PROXY_HTTPS_PORT` is customized away
from `80` or `443`, the matching URL variables include the explicit port.

---

## Labels Generated Per Export

For each entry in `XCIND_PROXY_EXPORTS`, the proxy hook generates:

| Label | Value |
|-------|-------|
| `xcind.export.{name}.host` | Generated hostname (e.g., `myapp-api.localhost.scind.io`) |
| `xcind.export.{name}.url` | Full URL (e.g., `http://myapp-api.localhost.scind.io`) |

For the primary (first) export, apex labels are also generated:

| Label | Value |
|-------|-------|
| `xcind.apex.host` | Apex hostname (e.g., `myapp.localhost.scind.io`) |
| `xcind.apex.url` | Apex URL (e.g., `http://myapp.localhost.scind.io`) |

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
| `XCIND_INSTANCE` | Per-worktree isolation token folded into the compose project name and workspace network name so multiple git worktrees of one repo don't collide. Empty (the default on a main checkout) leaves naming byte-identical to the un-instanced form. Explicit value wins; otherwise auto-detected from a linked worktree. See [Configuration Reference](../reference/configuration.md#xcind_instance) and [Naming Conventions](./naming-conventions.md). |
| `XCIND_INSTANCE_AUTO` | Set `0` to disable git-worktree auto-detection of `XCIND_INSTANCE` (default `1`). |

## Host-View Env File (`XCIND_HOST_ENV_FILE`)

The injected discovery variables above are added to *container* `environment:`. To
mirror the same information for processes running on the **host**, set
`XCIND_HOST_ENV_FILE` to a path (relative paths resolve against the app root). On
each `xcind-compose` run an EXECUTE-phase hook (`__xcind-hostenv-execute-hook`)
writes a host-view dotenv there, reusing the same discovery seam — assigned
exports use their published `_HOST_PORT`, and `_HOST` reflects the host-reachable
value. `_INTERNAL_*` variables and `type=unpublished` exports are never written.
`jq` is required when the app declares any `type=assigned` exports.

`XCIND_HOST_ENV_ASSIGNED_HOST` selects the host-reachable value for assigned
exports. It also sets `_EXTERNAL_HOST` in the container view, so both views agree:

| Value | Assigned `_HOST` (host view) and `_EXTERNAL_HOST` |
|-------|----------------------------------------------------|
| `loopback` (default) | `127.0.0.1` |
| `hostname` | The export's URL-template hostname (e.g. `dev-shop-db.example.test`). Use it when the proxy domain resolves to the Docker host, for example through wildcard DNS. |

Any other value fails the hook.

`XCIND_HOST_ENV_MODE` selects how the file is written:

| Mode | Behavior |
|------|----------|
| `own` (default) | xcind fully owns the file and overwrites it each run. |
| `block` | xcind rewrites only its managed region, between `# >>> xcind >>>` and `# <<< xcind <<<`, preserving the rest of the file. |

---

## Related Documents

- [Docker Labels](./docker-labels.md) — Complete label reference
- [Generated Override Files](./generated-override-files.md) — How labels are injected
- [Configuration Reference](../reference/configuration.md) — `XCIND_PROXY_EXPORTS` and `XCIND_APP_ENV_FILES` syntax
- [Naming Conventions](./naming-conventions.md) — Hostname and alias patterns
