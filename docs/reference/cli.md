# CLI Reference

Xcind provides three commands. All are standalone Bash scripts.

---

## `xcind-compose`

The main workhorse. Resolves application configuration and passes everything through to `docker compose`.

### How It Works

1. Walks upward from `$PWD` to find the nearest `.xcind.sh` (the "app root")
2. Sources `.xcind.sh` to load application-specific configuration
3. Discovers workspace mode (checks parent directory for a workspace `.xcind.sh`)
4. Resolves compose files, env files, and override variants
5. Runs registered hooks to generate additional compose files
6. Assembles `--env-file` and `-f` flags and executes `docker compose`

All arguments are forwarded transparently to `docker compose`.

### Usage

```bash
xcind-compose up -d
xcind-compose build --no-cache
xcind-compose exec php bash
xcind-compose down --remove-orphans
xcind-compose ps
```

### Environment Variable Override

Set `XCIND_APP_ROOT` to bypass automatic root detection:

```bash
XCIND_APP_ROOT=/path/to/app xcind-compose up -d
```

### Tab Completion

Reuse Docker Compose's built-in completion:

```bash
complete -F _docker_compose xcind-compose 2>/dev/null
```

### Version

```bash
xcind-compose --xcind-version
```

---

## `xcind-config`

Dumps the resolved configuration. Useful for debugging, scripting, and the JetBrains plugin.

### Modes

| Flag | Output |
|------|--------|
| *(none)* | JSON output (`metadata`, `appRoot`, `configFiles`, `composeFiles`, `composeEnvFiles`, `appEnvFiles`, `bakeFiles`) |
| `--preview` | The `docker compose` command line that would run |
| `--files` | Resolved file paths, one per line, grouped by type |
| `--check` | Check whether required and optional dependencies are available |
| `--dump-docker-wrapper` | Generate a POSIX `docker` wrapper script |
| `--dump-docker-compose-wrapper` | Generate a POSIX `docker-compose` wrapper script |
| `--version`, `-V` | Show version |
| `--help`, `-h` | Show usage help |

### Usage

```bash
xcind-config                            # JSON output
xcind-config --preview                  # Show the docker compose command line
xcind-config --files                    # List resolved files
xcind-config --check                    # Check dependencies
xcind-config --dump-docker-wrapper      # Generate a docker wrapper script
xcind-config --dump-docker-compose-wrapper  # Generate a docker-compose wrapper script
xcind-config --version                  # Show version
```

### JSON Output Contract

The default JSON output follows the contract expected by the xcind JetBrains plugin:

```json
{
  "metadata": {
    "workspace": "my-workspace",
    "app": "my-app",
    "workspaceless": false
  },
  "appRoot": "/path/to/app",
  "configFiles": ["/path/to/workspace/.xcind.sh", "/path/to/app/.xcind.sh"],
  "composeFiles": ["compose.yaml", "compose.override.yaml"],
  "composeEnvFiles": [".env"],
  "appEnvFiles": [".env.app"],
  "bakeFiles": []
}
```

### `--check` Mode

Runs independently of app-root detection. Reports the availability of:

- Required dependencies (e.g., `docker`, `docker compose`)
- Optional dependencies (e.g., `yq` for hooks)

---

## `xcind-proxy`

Manages the shared Traefik reverse proxy infrastructure.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init` | Create proxy infrastructure files at `~/.config/xcind/proxy/` |
| `up [--force]` | Start the shared Traefik proxy (`--force` recreates the network) |
| `down` | Stop the shared Traefik proxy |
| `status` | Show proxy state (running/stopped, image, port, network) |
| `logs [OPTS]` | Show Traefik proxy logs (supports `docker compose logs` flags) |

### Options

| Option | Description |
|--------|-------------|
| `--version`, `-V` | Show version |
| `--help`, `-h` | Show usage help |

### Usage

```bash
xcind-proxy init          # Create proxy files in ~/.config/xcind/proxy/
xcind-proxy up            # Start the proxy
xcind-proxy up --force    # Recreate network and restart
xcind-proxy down          # Stop the proxy
xcind-proxy status        # Show proxy state
xcind-proxy logs          # Show logs
xcind-proxy logs -f       # Follow logs
xcind-proxy --version     # Show version
```

### Auto-Start Behavior

When `XCIND_PROXY_EXPORTS` is configured for an application, the proxy hook automatically starts the proxy if it is not already running. This happens transparently during `xcind-compose` execution.

To disable auto-start, set `XCIND_PROXY_AUTO_START=0`.

### Generated Files

`xcind-proxy init` creates the following at `~/.config/xcind/proxy/`:

| File | Purpose | Overwritten on re-init? |
|------|---------|------------------------|
| `config.sh` | User-editable proxy configuration | No (never overwritten) |
| `docker-compose.yaml` | Traefik service definition | Yes |
| `traefik.yaml` | Traefik static configuration | Yes |

---

## Related Documents

- [Configuration Reference](./configuration.md) — All `XCIND_*` variables
- [Proxy Infrastructure Spec](../specs/proxy-infrastructure.md) — Proxy architecture details
- [Architecture Overview](../architecture/overview.md) — System design
