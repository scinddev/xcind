# Configuration reference

`.xcind.sh` is a sourceable bash script. Most projects only need a few of these. For the exhaustive list — every variable, every URL template placeholder, every override-resolution rule — see [`engineering/reference/configuration.md`](../../engineering/reference/configuration.md).

## File discovery

| Variable | Default | Purpose |
|----------|---------|---------|
| `XCIND_COMPOSE_DIR` | _(app root)_ | Subdirectory where compose files live |
| `XCIND_COMPOSE_FILES` | `("compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml")` | Compose file patterns; only those that exist on disk are used |
| `XCIND_COMPOSE_ENV_FILES` | `(".env")` | `--env-file` patterns for `${VAR}` substitution in compose files |
| `XCIND_APP_ENV_FILES` | `()` | Env files injected into running containers via `env_file:` |
| `XCIND_ADDITIONAL_CONFIG_FILES` | `()` | Extra shell scripts to source after `.xcind.sh` |

For each file pattern, Xcind also checks for an `.override` variant — see [Override files](../guides/override-files.md).

File patterns support shell variable expansion (use single quotes to defer expansion until runtime):

```bash
XCIND_COMPOSE_FILES=("compose.common.yaml" 'compose.${APP_ENV}.yaml')
```

Walkthrough: [Environment files](../guides/env-files.md), [Override files](../guides/override-files.md).

## Application identity

| Variable | Default | Purpose |
|----------|---------|---------|
| `XCIND_APP` | _(directory name)_ | App name, used in container/network/volume naming and proxy hostnames |
| `XCIND_WORKSPACE` | _(unset)_ | Self-declare a workspace name without a parent `.xcind.sh` |
| `XCIND_IS_WORKSPACE` | _(unset)_ | Set to `1` in a workspace root's `.xcind.sh` |

Walkthrough: [Workspaces vs single apps](../guides/workspaces-vs-apps.md).

## Proxy

| Variable | Default | Purpose |
|----------|---------|---------|
| `XCIND_PROXY_EXPORTS` | `()` | Service exports (proxied or assigned ports) |
| `XCIND_PROXY_DOMAIN` | `localhost` | Domain suffix for generated hostnames |

`XCIND_PROXY_EXPORTS` entry format: `export[=service][:port][;type=proxied\|assigned[;…]]`

```bash
XCIND_PROXY_EXPORTS=(
    "api=app:3000"                    # proxied (default)
    "web:8080"
    "app"                             # port inferred from compose
    "worker:9000;type=assigned"       # stable host port
)
```

Walkthrough: [Set up the Traefik proxy](../guides/proxy-setup.md).

## Hooks

| Variable | Default | Purpose |
|----------|---------|---------|
| `XCIND_HOOKS_GENERATE` | (built-ins: naming, app-env, host-gateway, proxy, workspace) | Hooks that emit compose overlay files |
| `XCIND_HOOKS_EXECUTE` | (built-ins: proxy-execute, workspace-execute) | Hooks that run preconditions every invocation |
| `XCIND_HOST_GATEWAY_ENABLED` | `1` | Disable the host-gateway hook for this app |
| `XCIND_HOST_GATEWAY` | _(auto-detected)_ | Override the detected host-gateway value |

Walkthrough: [Author custom hooks](../guides/custom-hooks.md), [host-gateway](../guides/host-gateway.md).

## IDE / tooling

| Variable | Default | Purpose |
|----------|---------|---------|
| `XCIND_TOOLS` | `()` | Per-service runtimes for IDE integration |

Walkthrough: [IDE and tool integration](../guides/tools-ide-integration.md).

## Less commonly used

| Variable | Purpose |
|----------|---------|
| `XCIND_BAKE_FILES` | Docker Bake file patterns; tracked in `xcind-config --json`, not yet passed to `docker compose` |
| URL / router templates (`XCIND_*_TEMPLATE`) | Customize generated hostnames and Traefik router names |

For the full list of templates and their placeholders, see [`engineering/reference/configuration.md`](../../engineering/reference/configuration.md).

---

**Full detail**: [`engineering/reference/configuration.md`](../../engineering/reference/configuration.md) — every `XCIND_*` variable, including templates, internal flags, and the exact override-resolution algorithm.
