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

See [Shell Completions](#shell-completions) below.

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
| *(none)* | Show usage help |
| `--json` | JSON output (`metadata`, `appRoot`, `configFiles`, `composeFiles`, `composeEnvFiles`, `appEnvFiles`, `bakeFiles`, `tools`) |
| `--preview [-- ARGS...]` | The `docker compose` command line that would run |
| `--check` | Check whether required and optional dependencies are available |
| `--generate-docker-wrapper[=FILE]` | Generate a POSIX `docker` wrapper script |
| `--generate-docker-compose-wrapper[=FILE]` | Generate a POSIX `docker-compose` wrapper script |
| `--generate-docker-compose-configuration[=FILE]` | Generate resolved compose config |
| `completion {bash\|zsh}` | Output shell completion script for all xcind commands |
| `--version`, `-V` | Show version |
| `--help`, `-h` | Show usage help |

Multiple `--generate-*` flags may be combined in a single invocation when each specifies a file. Combine with `--json` to also output JSON to stdout.

### Usage

```bash
xcind-config                                       # Show help
xcind-config --json                                # JSON output
xcind-config --preview                             # Show the docker compose command line
xcind-config --check                               # Check dependencies
xcind-config --generate-docker-wrapper             # Generate docker wrapper to stdout
xcind-config --generate-docker-wrapper=bin/docker   # Generate docker wrapper to file
xcind-config --generate-docker-compose-wrapper     # Generate docker-compose wrapper to stdout
xcind-config --generate-docker-compose-configuration        # Generate resolved compose config to stdout
xcind-config --generate-docker-compose-configuration=FILE   # Generate resolved compose config to file
xcind-config --version                             # Show version
xcind-config completion bash                       # Output bash completions
xcind-config completion zsh                        # Output zsh completions
```

### JSON Output Contract

The `--json` output follows the contract expected by the xcind JetBrains plugin:

```json
{
  "metadata": {
    "workspace": "my-workspace",
    "app": "my-app",
    "workspaceless": false
  },
  "appRoot": "/path/to/app",
  "configFiles": ["/path/to/workspace/.xcind.sh", "/path/to/app/.xcind.sh"],
  "composeFiles": ["/path/to/app/compose.yaml", "/path/to/app/compose.override.yaml"],
  "composeEnvFiles": ["/path/to/app/.env"],
  "appEnvFiles": ["/path/to/app/.env.app"],
  "bakeFiles": [],
  "tools": {
    "php": { "service": "app", "use": "exec" },
    "npm": { "service": "app", "use": "exec" }
  }
}
```

The `tools` object is keyed by tool name. Each entry includes `service`, `use` (default `"exec"`), and optionally `path`. See [`XCIND_TOOLS`](./configuration.md#xcind_tools) for the declaration format.

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
| `init [OPTIONS]` | Create proxy infrastructure files (with optional configuration) |
| `up [--force]` | Start the shared Traefik proxy (`--force` recreates the network) |
| `down` | Stop the shared Traefik proxy |
| `status [--json]` | Show proxy state (running/stopped, image, port, network) |
| `logs [OPTS]` | Show Traefik proxy logs (supports `docker compose logs` flags) |

### Init Options

| Option | Config Variable | Default |
|--------|----------------|---------|
| `--proxy-domain DOMAIN` | `XCIND_PROXY_DOMAIN` | `localhost` |
| `--http-port PORT` | `XCIND_PROXY_HTTP_PORT` | `80` |
| `--image IMAGE` | `XCIND_PROXY_IMAGE` | `traefik:v3` |
| `--dashboard BOOL` | `XCIND_PROXY_DASHBOARD` | `false` |
| `--dashboard-port PORT` | `XCIND_PROXY_DASHBOARD_PORT` | `8080` |

Flags set-and-persist: values are merged with any existing `config.sh` and written back.

### Options

| Option | Description |
|--------|-------------|
| `--version`, `-V` | Show version |
| `--help`, `-h` | Show usage help |

### Usage

```bash
xcind-proxy init          # Create proxy config with defaults
xcind-proxy init --proxy-domain xcind.localhost  # Set domain
xcind-proxy init --http-port 8081 --dashboard true  # Multiple flags
xcind-proxy up            # Start the proxy
xcind-proxy up --force    # Recreate network and restart
xcind-proxy down          # Stop the proxy
xcind-proxy status        # Show proxy state
xcind-proxy status --json # Show proxy state as JSON
xcind-proxy logs          # Show logs
xcind-proxy logs -f       # Follow logs
xcind-proxy --version     # Show version
```

### Auto-Start Behavior

When `XCIND_PROXY_EXPORTS` is configured for an application, the proxy hook automatically starts the proxy if it is not already running. This happens transparently during `xcind-compose` execution.

To disable auto-start, set `XCIND_PROXY_AUTO_START=0`.

### Generated Files

`xcind-proxy init` creates files in two locations:

**Config** (`~/.config/xcind/proxy/`):

| File | Purpose | Overwritten on re-init? |
|------|---------|------------------------|
| `config.sh` | Proxy configuration | Yes, when flags are passed (existing values preserved) |

**State** (`~/.local/state/xcind/proxy/`):

| File | Purpose | Overwritten on re-init? |
|------|---------|------------------------|
| `docker-compose.yaml` | Traefik service definition | Yes (always regenerated) |
| `traefik.yaml` | Traefik static configuration | Yes (always regenerated) |

---

## `xcind-workspace`

Manages xcind workspaces.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init [DIR] [OPTIONS]` | Initialize a workspace directory |
| `status [DIR] [OPTIONS]` | Show workspace-wide status |

### Init Options

| Option | Description |
|--------|-------------|
| `--name NAME` | Set `XCIND_WORKSPACE` explicitly (default: directory name) |
| `--proxy-domain DOMAIN` | Set `XCIND_PROXY_DOMAIN` in workspace config |

### Status Options

| Option | Description |
|--------|-------------|
| `--json` | Output structured JSON |

### Usage

```bash
xcind-workspace init                         # Initialize current directory
xcind-workspace init ~/Workspaces/dev        # Initialize specific directory
xcind-workspace init --proxy-domain xcind.localhost  # With proxy domain
xcind-workspace init --name myws             # With explicit workspace name
xcind-workspace status                       # Show workspace status
xcind-workspace status --json                # JSON output
```

### Behavior

- `DIR` defaults to `.` (current directory).
- If `.xcind.sh` already exists with `XCIND_IS_WORKSPACE=1`, re-running with flags updates the config; without flags reports "already initialized".
- If `.xcind.sh` exists without `XCIND_IS_WORKSPACE=1` (an app config), the command prints a helpful error suggesting the correct workspace directory.

---

## Shell Completions

Xcind provides tab completions for all commands. Add one line to your shell
config:

```bash
# Bash (~/.bashrc)
. <(xcind-config completion bash)

# Zsh (~/.zshrc)
. <(xcind-config completion zsh)
```

This registers completions for `xcind-compose`, `xcind-config`,
`xcind-proxy`, and `xcind-workspace`. For `xcind-compose`, completions invoke Docker's
`docker compose __complete` mechanism directly so you get the same experience
as `docker compose` without requiring Docker's shell completion to be loaded.
If that subprocess is unavailable or returns no suggestions, a hardcoded fallback list of common subcommands is used.

---

## Related Documents

- [Configuration Reference](./configuration.md) — All `XCIND_*` variables
- [Proxy Infrastructure Spec](../specs/proxy-infrastructure.md) — Proxy architecture details
- [Architecture Overview](../architecture/overview.md) — System design
