# Configuration Reference

Xcind is configured through `.xcind.sh` files — sourceable Bash scripts that set `XCIND_*` variables.

---

## Configuration Levels

| Level | File | Purpose |
|-------|------|---------|
| Global proxy | `~/.config/xcind/proxy/config.sh` | Proxy domain, image, ports |
| Workspace | `{workspace}/.xcind.sh` | Workspace-level hooks, domain, settings |
| Application | `{app}/.xcind.sh` | App-specific compose files, env files, exports |

When in workspace mode, the workspace `.xcind.sh` is sourced first, then the application `.xcind.sh` (which can override workspace settings).

---

## Application Configuration Variables

### `XCIND_COMPOSE_ENV_FILES`

Array of environment file patterns for Docker Compose YAML interpolation. Each file that exists on disk is passed via `--env-file` to `docker compose`. These variables are available for `${VAR}` substitution in compose files but are **not** injected into running containers.

**Default:** `(".env")`

```bash
XCIND_COMPOSE_ENV_FILES=(".env" ".env.local" '.env.${APP_ENV}')
```

### `XCIND_APP_ENV_FILES`

Array of environment file patterns to inject into all container services via Docker Compose's `env_file:` directive. Unlike `XCIND_COMPOSE_ENV_FILES`, these files are available inside the running containers.

**Default:** `()` (empty)

```bash
XCIND_APP_ENV_FILES=(".env" ".env.local")
```

> **Note:** It is valid and common to list the same file (e.g., `.env`) in both `XCIND_COMPOSE_ENV_FILES` and `XCIND_APP_ENV_FILES`. This makes `.env` available for both YAML interpolation and inside containers.

### `XCIND_ADDITIONAL_CONFIG_FILES`

Array of additional `.xcind.sh`-style config file patterns to source after the main `.xcind.sh`. Paths are resolved relative to the app root. Each file that exists is sourced, along with its `.override` variant (if present). Supports variable expansion.

**Default:** `()` (empty)

```bash
XCIND_ADDITIONAL_CONFIG_FILES=('xcind.${APP_ENV}.sh')
```

### `XCIND_COMPOSE_DIR`

Optional subdirectory where compose files live, relative to the app root. If set, compose file patterns are resolved relative to this directory.

**Default:** *(unset — compose files resolve from the app root)*

```bash
XCIND_COMPOSE_DIR="docker"
```

### `XCIND_COMPOSE_FILES`

Array of compose file patterns, relative to `XCIND_COMPOSE_DIR` (or the app root if `XCIND_COMPOSE_DIR` is unset). Each file that exists on disk is passed via `-f`.

**Default:** `("compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml")`

```bash
XCIND_COMPOSE_FILES=(
    "compose.common.yaml"
    'compose.${APP_ENV}.yaml'
    "compose.traefik.yaml"
)
```

### `XCIND_BAKE_FILES`

Array of Docker Bake file patterns, relative to the app root. Reserved for future use. Currently tracked in `xcind-config` JSON output but not passed to `docker compose`.

**Default:** `()` (empty)

```bash
XCIND_BAKE_FILES=("docker-bake.hcl")
```

### `XCIND_TOOLS`

Array of tool declarations for IDE and plugin integration. Each entry maps a tool name to a compose service, with optional metadata. Declared tools appear in the `tools` object of the [`xcind-config --json`](./cli.md#json-output-contract) output.

**Default:** `()` (empty)

**Format:** `name:service[;key=value[;key=value…]]`

| Metadata Key | Default | Description |
|--------------|---------|-------------|
| `use` | `"exec"` | How the tool is invoked: `exec` (default) attaches to an existing service container; `run` starts a new one-shot container. |
| `path` | *(omitted)* | Path to the tool binary inside the container |

First entry for a given tool name wins; subsequent duplicates are skipped.

```bash
XCIND_TOOLS=(
    "php:app"
    "npm:app"
    "composer:app;path=/usr/bin/composer"
)
```

Changes to `XCIND_TOOLS` affect the configuration SHA, triggering cache invalidation.

### `XCIND_IS_WORKSPACE`

Set to `1` in a workspace root's `.xcind.sh` to mark the directory as a workspace. When xcind discovers an app inside this directory, it sources the workspace `.xcind.sh` first.

```bash
XCIND_IS_WORKSPACE=1
```

### `XCIND_HOST_GATEWAY_ENABLED`

Controls whether the host gateway hook runs. Set to `0` to disable automatic `host.docker.internal` normalization.

**Default:** `1` (enabled)

```bash
XCIND_HOST_GATEWAY_ENABLED=0  # disable host gateway hook
```

### `XCIND_HOST_GATEWAY`

Override the auto-detected host gateway value. When set, this value is used directly as the `extra_hosts` target for `host.docker.internal` without platform detection.

**Default:** *(unset — auto-detect)*

```bash
XCIND_HOST_GATEWAY="192.168.1.100"
```

> The host-gateway hook requires `yq`. If `yq` is not installed, the hook is
> skipped with a warning. The hook's generated output is cached by SHA; changes
> to `XCIND_HOST_GATEWAY` or `XCIND_HOST_GATEWAY_ENABLED` automatically
> invalidate the cache.
>
> For details on platform detection logic, see the [Scind specification for host.docker.internal normalization](https://github.com/scinddev/scind).

### `XCIND_HOOKS_GENERATE`

Array of hook function names that generate compose overlay files. Hooks run after file resolution and their output is cached by SHA.

**Default:** `("xcind-naming-hook" "xcind-app-hook" "xcind-app-env-hook" "xcind-host-gateway-hook" "xcind-proxy-hook" "xcind-assigned-hook" "xcind-workspace-hook")`

All built-in hooks are registered automatically. Override to `()` to disable all generation hooks.

```bash
XCIND_HOOKS_GENERATE=()  # disable all generation hooks
```

When `yq` is missing at runtime, default-registered hooks behave in one of
two ways: non-load-bearing hooks (`xcind-app-hook`,
`xcind-host-gateway-hook`, `xcind-workspace-hook`) soft-skip with a
consolidated warning at the end of the run; hooks with load-bearing output
(`xcind-app-env-hook`, `xcind-proxy-hook`, `xcind-assigned-hook`) hard-fail
the pipeline. See [Hook Lifecycle](../specs/hook-lifecycle.md#generate) for
the full policy.

### `XCIND_HOOKS_EXECUTE`

Array of hook function names that ensure runtime preconditions before `docker compose` runs. These hooks run on every invocation (not cached) and only apply in `xcind-compose`, not `xcind-config`.

**Default:** `("__xcind-proxy-execute-hook" "__xcind-workspace-execute-hook")`

```bash
XCIND_HOOKS_EXECUTE=()  # disable all execute hooks
```

See [Hook Lifecycle](../specs/hook-lifecycle.md) for details on all hook phases.

### `XCIND_PROXY_EXPORTS`

Array of service export declarations. Each entry names an exported service and — via an optional `type` attribute — chooses between the two port-exposure mechanisms: routing through the shared Traefik proxy (`type=proxied`, default) or reserving a stable host port (`type=assigned`).

**Default:** `()` (empty)

**Format:** `export_name[=compose_service][:port][;key=value[;key=value…]]`

| Metadata Key | Default | Description |
|--------------|---------|-------------|
| `type` | `"proxied"` | `proxied` routes traffic through Traefik on a generated hostname. `assigned` reserves a stable host port, persisted across restarts. |

Unknown metadata keys and invalid `type` values cause the generation hooks to fail fast — the surface is kept minimal until additional Scind attributes (`protocol`, `visibility`) are wired up.

```bash
XCIND_PROXY_EXPORTS=(
    "web"                            # proxied (default), service=web, port inferred
    "api=uvicorn:8080"               # proxied, name=api, service=uvicorn, port 8080
    "worker:9000;type=assigned"      # assigned, name=worker, service=worker, port 9000
    "database=db:3306;type=assigned" # assigned, name=database, service=db, port 3306
)
```

When the port is omitted, it is inferred from the compose service's port mapping (requires exactly one port mapping). `yq` is required whenever `XCIND_PROXY_EXPORTS` is configured, not only for port inference.

`xcind-proxy-hook` owns entries with `type=proxied` and emits `compose.proxy.yaml` with Traefik routing labels. `xcind-assigned-hook` owns entries with `type=assigned`, emits `compose.assigned.yaml` with host-port mappings, and persists assignments under `${XDG_STATE_HOME:-~/.local/state}/xcind/proxy/assigned-ports.tsv` via flock-serialized state.

### `XCIND_PROXY_AUTO_START`

Controls whether the proxy execute hook automatically starts Traefik when `XCIND_PROXY_EXPORTS` is configured.

**Default:** `1` (enabled)

```bash
XCIND_PROXY_AUTO_START=0  # disable proxy auto-start
```

### `XCIND_PROXY_DOMAIN`

Domain suffix for generated proxy hostnames. Can be set in the workspace `.xcind.sh` or in the global proxy config.

**Default:** `"localhost"` (RFC 6761 — `.localhost` requires zero DNS configuration)

```bash
XCIND_PROXY_DOMAIN="xcind.localhost"
```

---

## URL Template Variables

These control how hostnames, router names, and network aliases are generated. Defaults are provided for both workspaceless and workspace modes.

### Hostname Templates

| Variable | Default | Used When |
|----------|---------|-----------|
| `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` | `{app}-{export}.{domain}` | No workspace |
| `XCIND_WORKSPACE_APP_URL_TEMPLATE` | `{workspace}-{app}-{export}.{domain}` | In workspace |

### Apex Hostname Templates

| Variable | Default | Used When |
|----------|---------|-----------|
| `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` | `{app}.{domain}` | No workspace, primary export |
| `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` | `{workspace}-{app}.{domain}` | In workspace, primary export |

Set an apex template to an empty string to disable apex URL generation.

### Router Templates

| Variable | Default | Used When |
|----------|---------|-----------|
| `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` | `{app}-{export}-{protocol}` | No workspace |
| `XCIND_WORKSPACE_ROUTER_TEMPLATE` | `{workspace}-{app}-{export}-{protocol}` | In workspace |
| `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` | `{app}-{protocol}` | No workspace, primary export |
| `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` | `{workspace}-{app}-{protocol}` | In workspace, primary export |

### Service Template

| Variable | Default | Used When |
|----------|---------|-----------|
| `XCIND_WORKSPACE_SERVICE_TEMPLATE` | `{app}-{service}` | Workspace networking aliases |

### Template Placeholders

| Placeholder | Description |
|-------------|-------------|
| `{app}` | Application name (basename of app directory) |
| `{workspace}` | Workspace name (basename of workspace directory) |
| `{export}` | Export name from `XCIND_PROXY_EXPORTS` |
| `{domain}` | Domain suffix (`XCIND_PROXY_DOMAIN`) |
| `{protocol}` | Protocol (currently always `http`) |
| `{service}` | Compose service name |

---

## Override Resolution

For each file pattern, xcind also checks for an `.override` variant.

**Extension-aware insertion** — for files with a recognized extension (`.yaml`, `.yml`, `.json`, `.hcl`, `.toml`, `.sh`), `.override` is inserted before the extension:

| Base File | Override Variant |
|-----------|-----------------|
| `compose.yaml` | `compose.override.yaml` |
| `compose.common.yaml` | `compose.common.override.yaml` |
| `docker-bake.hcl` | `docker-bake.override.hcl` |

**Appended** — for all other files (like env files), `.override` is appended:

| Base File | Override Variant |
|-----------|-----------------|
| `.env` | `.env.override` |
| `.env.local` | `.env.local.override` |

Files that don't exist on disk are silently skipped — both the base file and its override variant.

---

## Variable Expansion

File patterns support shell variable expansion at runtime:

```bash
XCIND_COMPOSE_FILES=(
    "compose.common.yaml"
    'compose.${APP_ENV}.yaml'    # Single quotes prevent premature expansion
)
```

With `APP_ENV=dev`, xcind checks for `compose.dev.yaml` and `compose.dev.override.yaml`.

---

## Global Proxy Configuration

`xcind-proxy init` creates `~/.config/xcind/proxy/config.sh` (generated files in `~/.local/state/xcind/proxy/`) with these defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `XCIND_PROXY_DOMAIN` | `"localhost"` | Domain suffix for hostnames |
| `XCIND_PROXY_IMAGE` | `"traefik:v3"` | Traefik Docker image |
| `XCIND_PROXY_HTTP_PORT` | `"80"` | Host port for HTTP traffic |
| `XCIND_PROXY_DASHBOARD` | `"false"` | Enable Traefik dashboard |
| `XCIND_PROXY_DASHBOARD_PORT` | `"8080"` | Dashboard port (if enabled) |

Edit this file to customize the proxy. Run `xcind-proxy init` again to regenerate all files (existing config values are preserved as defaults).

---

## Workspace Variables (Automatic)

These are set automatically when workspace mode is active:

| Variable | Value |
|----------|-------|
| `XCIND_WORKSPACE` | Basename of the workspace directory |
| `XCIND_WORKSPACE_ROOT` | Absolute path to the workspace directory |
| `XCIND_WORKSPACELESS` | `0` in workspace mode, `1` otherwise |

An app can also self-declare workspace membership by setting `XCIND_WORKSPACE` directly in its `.xcind.sh`.

---

## Computed Template Variables (Automatic)

These variables are set automatically based on workspace mode and are used internally by hooks. They are **not user-configurable** — configure the workspace-mode-specific variants above instead.

| Variable | Derived From |
|----------|-------------|
| `XCIND_APP_URL_TEMPLATE` | `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` or `XCIND_WORKSPACE_APP_URL_TEMPLATE` |
| `XCIND_APP_APEX_URL_TEMPLATE` | `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` or `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` |
| `XCIND_ROUTER_TEMPLATE` | `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` or `XCIND_WORKSPACE_ROUTER_TEMPLATE` |
| `XCIND_APEX_ROUTER_TEMPLATE` | `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` or `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` |

The appropriate variant is selected based on whether `XCIND_WORKSPACELESS` is `1` (workspaceless mode) or `0` (workspace mode).

---

## Deprecated Variables

### `XCIND_ENV_FILES`

**Replaced by:** `XCIND_COMPOSE_ENV_FILES`

If `XCIND_ENV_FILES` is set, xcind migrates it to `XCIND_COMPOSE_ENV_FILES` automatically and prints a deprecation warning. If both are set, `XCIND_ENV_FILES` takes precedence (with an additional warning).

---

## Related Documents

- [CLI Reference](./cli.md) — Command usage
- [Configuration Schemas Spec](../specs/configuration-schemas.md) — Behavioral rules
- [Naming Conventions Spec](../specs/naming-conventions.md) — How names are generated
- [ADR-0006: Three Configuration Schemas](../decisions/0006-three-configuration-schemas.md) — Design rationale
