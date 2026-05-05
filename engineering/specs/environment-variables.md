# Environment Variables

> Adapted from the [Scind specification](https://github.com/scinddev/scind). Xcind generates `XCIND_*` variables via the proxy hook, not `SCIND_*`.

---

## Overview

Xcind's proxy hook generates Docker labels that include hostname and URL information for each export. These labels enable external tools to discover services. The labels are applied to containers via the generated `compose.proxy.yaml`.

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

---

## Related Documents

- [Docker Labels](./docker-labels.md) — Complete label reference
- [Generated Override Files](./generated-override-files.md) — How labels are injected
- [Configuration Reference](../reference/configuration.md) — `XCIND_PROXY_EXPORTS` and `XCIND_APP_ENV_FILES` syntax
- [Naming Conventions](./naming-conventions.md) — Hostname and alias patterns
