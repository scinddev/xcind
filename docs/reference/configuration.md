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

### `XCIND_IS_WORKSPACE`

Set to `1` in a workspace root's `.xcind.sh` to mark the directory as a workspace. When xcind discovers an app inside this directory, it sources the workspace `.xcind.sh` first.

```bash
XCIND_IS_WORKSPACE=1
```

### `XCIND_HOOKS_POST_RESOLVE_GENERATE`

Array of hook function names to execute after file resolution. Hooks generate additional compose files dynamically.

**Default:** `("xcind-naming-hook" "xcind-app-env-hook" "xcind-proxy-hook" "xcind-workspace-hook")`

All built-in hooks are registered automatically. Override to `()` to disable all hook processing.

```bash
XCIND_HOOKS_POST_RESOLVE_GENERATE=()  # disable all hooks
```

### `XCIND_PROXY_EXPORTS`

Array of service export declarations for the proxy hook. Each entry maps an export name to a compose service and port.

**Default:** `()` (empty)

**Format:** `export_name[=compose_service][:port]`

| Entry | Export Name | Compose Service | Port |
|-------|-----------|-----------------|------|
| `"api=app:3000"` | `api` | `app` | `3000` |
| `"web:8080"` | `web` | `web` | `8080` |
| `"app"` | `app` | `app` | *(inferred from compose config)* |

```bash
XCIND_PROXY_EXPORTS=(
    "api=app:3000"
    "web:8080"
    "app"
)
```

When the port is omitted, it is inferred from the service's port mapping (requires exactly one port mapping). `yq` is required by `xcind-proxy-hook` whenever `XCIND_PROXY_EXPORTS` is configured, not only for port inference.

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

**Extension-aware insertion** — for files with a recognized extension (`.yaml`, `.yml`, `.json`, `.hcl`, `.toml`), `.override` is inserted before the extension:

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

`xcind-proxy init` creates `~/.config/xcind/proxy/config.sh` with these defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `XCIND_PROXY_DOMAIN` | `"localhost"` | Domain suffix for hostnames |
| `XCIND_PROXY_IMAGE` | `"traefik:v3"` | Traefik Docker image |
| `XCIND_PROXY_HTTP_PORT` | `"80"` | Host port for HTTP traffic |
| `XCIND_PROXY_DASHBOARD` | `"false"` | Enable Traefik dashboard |
| `XCIND_PROXY_DASHBOARD_PORT` | `"8080"` | Dashboard port (if enabled) |

Edit this file to customize the proxy. Run `xcind-proxy init` again to regenerate the Docker Compose and Traefik files (the config file is never overwritten).

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
