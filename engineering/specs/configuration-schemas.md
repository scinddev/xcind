# Configuration Schemas

> Rewritten from the [Scind specification](https://github.com/scinddev/scind). Xcind uses three `.xcind.sh` levels plus a proxy `config.sh` instead of YAML schemas.

---

## Design Rationale: Declarative Configuration

Xcind configuration is declarative: `.xcind.sh` files and proxy
`config.sh` describe desired workspace, application, and proxy behavior. They do
not describe whether an app is currently running, which generated override
files are current, or which sticky host ports have been assigned.

Xcind also maintains narrowly-scoped runtime state and generated artifacts under
`${XDG_STATE_HOME:-$HOME/.local/state}/xcind/` and per-app `.xcind/generated/`
directories. That state is not user-authored configuration; it supports
workspace discovery, assigned-port stability, generated proxy files, and
Docker-backed runtime lifecycle operations.

| Aspect | Source |
|--------|--------|
| Proxy settings | `~/.config/xcind/proxy/config.sh` |
| Workspace definition | `{workspace}/.xcind.sh` with `XCIND_IS_WORKSPACE=1` |
| App configuration | `{app}/.xcind.sh` |
| Workspace registry | `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/workspaces.tsv` |
| Assigned-port state | `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy/assigned-ports.tsv` |
| Running containers and networks | Docker daemon |
| Generated files | `.xcind/generated/{sha}/` (per-app) and `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy/` (global) |

This separation ensures configuration files are simple Bash scripts that can be
version-controlled, while runtime state remains operational data owned by Xcind
and Docker. For the workspace lifecycle state files, see
[Workspace Lifecycle: State](./workspace-lifecycle.md#state).

For schema definitions and field references, see [Configuration Reference](../reference/configuration.md).

---

## Configuration Levels

### Level 1: Global Proxy (`~/.config/xcind/proxy/config.sh`)

Machine-wide proxy settings. Created by `xcind-proxy init`. Existing config values are preserved as defaults on re-init; the file is always regenerated.

Variables: `XCIND_PROXY_DOMAIN`, `XCIND_PROXY_IMAGE`, `XCIND_PROXY_HTTP_PORT`, `XCIND_PROXY_DASHBOARD`, `XCIND_PROXY_DASHBOARD_PORT`.

### Level 2: Workspace (`.xcind.sh` with `XCIND_IS_WORKSPACE=1`)

Per-workspace settings. Sourced first when an app is inside the workspace.

Typical contents:

```bash
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
```

### Level 3: Application (`.xcind.sh`)

Per-application settings. Sourced after the workspace config (if any), so it can override workspace defaults.

Typical contents:

```bash
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_COMPOSE_ENV_FILES=(".env")
XCIND_PROXY_EXPORTS=("web:3000")
```

### Source Order

1. Global proxy `config.sh` (sourced by proxy hook when needed)
2. Workspace `.xcind.sh` (if in workspace mode)
3. Application `.xcind.sh` (overrides workspace settings)

---

## Proxy Behavior

### Lifecycle

- `xcind-proxy init`: Creates directory structure, config file, and Docker Compose/Traefik files
- `xcind-proxy up`: Starts Traefik (calls `__xcind-proxy-ensure-running`)
- `xcind-proxy down`: Stops Traefik
- Auto-start: the `__xcind-proxy-execute-hook` (EXECUTE phase) starts the proxy automatically when `XCIND_PROXY_EXPORTS` is configured

### Recovery

If a user edits the proxy configuration, running `xcind-proxy init` regenerates `compose.yaml` and `traefik.yaml` from `config.sh` (the config file itself is preserved).

`xcind-proxy up --force` tears down everything and rebuilds from scratch.

---

## Hook Pipeline

Hooks run after file resolution as the final step before executing `docker compose`. Each hook:

1. Receives the app root as its argument
2. Writes a generated compose file to `$XCIND_GENERATED_DIR`
3. Prints `-f /path/to/generated.yaml` to stdout
4. Xcind appends those flags to the `docker compose` invocation

### Default Hooks

| Hook | Source | Purpose |
|------|--------|---------|
| `xcind-naming-hook` | `xcind-naming-lib.bash` | Sets Docker Compose project `name:` |
| `xcind-app-hook` | `xcind-app-lib.bash` | App identity labels on all services |
| `xcind-app-env-hook` | `xcind-app-env-lib.bash` | Injects `XCIND_APP_ENV_FILES` |
| `xcind-host-gateway-hook` | `xcind-host-gateway-lib.bash` | Maps `host.docker.internal` via `extra_hosts` |
| `xcind-proxy-hook` | `xcind-proxy-lib.bash` | Generates Traefik labels and proxy network |
| `xcind-assigned-hook` | `xcind-assigned-lib.bash` | Stable host port bindings |
| `xcind-workspace-hook` | `xcind-workspace-lib.bash` | Generates workspace network aliases |

### Template Resolution

URL template variables are resolved at hook execution time. The resolved values are written into the generated override files. Templates use `{key}` placeholder syntax.

---

## Related Documents

- [Configuration Reference](../reference/configuration.md) — Variable definitions and field reference
- [Port Types](./port-types.md) — How exports map to proxy configuration
- [Generated Override Files](./generated-override-files.md) — Override file generation rules
- [ADR-0005: Structure vs State Separation](../decisions/0005-structure-vs-state-separation.md) — Design rationale
- [ADR-0006: Three Configuration Schemas](../decisions/0006-three-configuration-schemas.md) — Design rationale
