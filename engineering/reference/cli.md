# CLI Reference

Xcind provides six commands. All are standalone Bash scripts.

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
xcind-compose --version
xcind-compose -V
```

`--xcind-version` is retained as a hidden compatibility alias.

### Version Output Format

All `xcind-*` binaries report their version using SemVer-compatible syntax:

```
<XCIND_VERSION>[+<SOURCE>[.<SHORT_REV>][.dirty][.<DATE>]]
```

- Tagged releases (npm, `:<version>` Docker tags) print the bare version:
  `xcind-compose 0.5.0`.
- Installs from channels that know their provenance (Nix flake, install.sh on
  a git clone, Docker image outside the release workflow) append a `+SOURCE…`
  suffix: `xcind-compose 0.5.0+nix.1a2b3c4.20260420`.

See [build-provenance.md](build-provenance.md) for the full schema.

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
| `doctor [--json]` | Diagnose `XCIND_PROXY_EXPORTS` and assigned-port hook state |
| `--generate-docker-wrapper[=FILE]` | Generate a POSIX `docker` wrapper script |
| `--generate-docker-compose-wrapper[=FILE]` | Generate a POSIX `docker-compose` wrapper script |
| `--generate-docker-compose-configuration[=FILE]` | Generate resolved compose config |
| `--generate-starship[=FILE] [--format toml\|nix]` | Generate a Starship `[custom.xcind]` block (TOML default, or Nix Home Manager attrset) |
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
xcind-config doctor                                # Diagnose proxy export and assigned-port state
xcind-config doctor --json                         # Diagnose with JSON output
xcind-config --generate-docker-wrapper             # Generate docker wrapper to stdout
xcind-config --generate-docker-wrapper=bin/docker   # Generate docker wrapper to file
xcind-config --generate-docker-compose-wrapper     # Generate docker-compose wrapper to stdout
xcind-config --generate-docker-compose-configuration        # Generate resolved compose config to stdout
xcind-config --generate-docker-compose-configuration=FILE   # Generate resolved compose config to file
xcind-config --generate-starship                   # Print a Starship [custom.xcind] block (TOML)
xcind-config --generate-starship --format nix      # Emit a Nix Home Manager attrset instead
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
  },
  "assignedExports": {
    "worker": {
      "compose_service": "worker",
      "container_port": 9000,
      "host_port": 49213,
      "declared_port": 9000
    }
  },
  "proxiedExports": {
    "web": {
      "compose_service": "web",
      "container_port": 8080,
      "url": "https://my-workspace-my-app-web.example.test",
      "tls": "auto",
      "apex_url": "https://my-workspace-my-app.example.test",
      "apex_host": "my-workspace-my-app.example.test"
    }
  },
  "apex": {
    "enabled": true,
    "hostname": "my-workspace-my-app.example.test",
    "url": "https://my-workspace-my-app.example.test",
    "scheme": "https"
  }
}
```

The `tools` object is keyed by tool name. Each entry includes `service`, `use` (default `"exec"`), and optionally `path`. See [`XCIND_TOOLS`](./configuration.md#xcind_tools) for the declaration format.

The `assignedExports` object is keyed by export name. Each entry includes `compose_service`, `container_port`, `host_port`, and `declared_port`. It is `{}` when the app declares no `type=assigned` exports (or none have been assigned a host port yet).

The `proxiedExports` object is keyed by export name. Each entry includes `compose_service`, `container_port` (`null` when it cannot be inferred), `url` (the per-export hostname URL, computed from `XCIND_APP_URL_TEMPLATE`), and `tls` (the declared per-export mode). It is `{}` when the app declares no `type=proxied` exports. The **first** proxied export — the apex anchor — additionally carries `apex_url` and `apex_host`: the shorter canonical URL/host that actually serves the app's traffic (present only when an apex template is configured). Other proxied exports omit these keys. Consumers should prefer `apex_url` over `url` for the headlining export; `xcind-application urls`/`exports` do exactly this.

The `apex` object describes the app's apex host derived from the shared proxy backend. It is **always present**: when an apex is available (`XCIND_APP_APEX_URL_TEMPLATE` is set and the app has at least one `type=proxied` export), `enabled` is `true` and `hostname`/`url`/`scheme` are populated; otherwise `enabled` is `false` and `hostname`/`url`/`scheme` are `null` (present-but-null, never omitted, so consumers can read `.apex.enabled` and `.apex.hostname` without existence checks). `url` is `scheme://hostname`; `scheme` is `http` or `https`.

### `--check` Mode

Runs independently of app-root detection. Reports the availability of:

- Required dependencies (e.g., `docker`, `docker compose`, `yq`)
- Optional dependencies (e.g., `jq` for JSON output)

### `doctor` Mode

Diagnoses the current application's `XCIND_PROXY_EXPORTS` declarations and
assigned-port hook state. With `--json`, outputs structured diagnostics for
scripts and tools.

---

## `xcind-proxy`

Manages the shared Traefik reverse proxy infrastructure.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init [OPTIONS]` | Create proxy infrastructure files (with optional configuration) |
| `up [--force]` | Start the shared Traefik proxy (`--force` recreates the network) |
| `down` | Stop the shared Traefik proxy |
| `status [--json]` | Show proxy state (running/stopped, image, port, network, assigned ports) |
| `logs [OPTS]` | Show Traefik proxy logs (supports `docker compose logs` flags) |
| `release PORT` | Release an assigned port from the state file |
| `prune` | Remove assigned-port entries whose app path no longer exists |

### Init Options

| Option | Config Variable | Default |
|--------|----------------|---------|
| `--proxy-domain DOMAIN` | `XCIND_PROXY_DOMAIN` | `localhost.scind.io` |
| `--http-port PORT` | `XCIND_PROXY_HTTP_PORT` | `80` |
| `--image IMAGE` | `XCIND_PROXY_IMAGE` | `traefik:v3` |
| `--dashboard BOOL` | `XCIND_PROXY_DASHBOARD` | `false` |
| `--dashboard-port PORT` | `XCIND_PROXY_DASHBOARD_PORT` | `8080` |
| `--tls-mode MODE` | `XCIND_PROXY_TLS_MODE` | `auto` |
| `--https-port PORT` | `XCIND_PROXY_HTTPS_PORT` | `443` |
| `--tls-cert-file PATH` | `XCIND_PROXY_TLS_CERT_FILE` | Empty |
| `--tls-key-file PATH` | `XCIND_PROXY_TLS_KEY_FILE` | Empty |

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
xcind-proxy init --tls-mode custom --tls-cert-file cert.pem --tls-key-file key.pem
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
| `config.sh` | Proxy configuration | Yes (always regenerated; existing values preserved) |

**State** (`~/.local/state/xcind/proxy/`):

| File | Purpose | Overwritten on re-init? |
|------|---------|------------------------|
| `compose.yaml` | Traefik service definition | Yes (always regenerated) |
| `traefik.yaml` | Traefik static configuration | Yes (always regenerated) |

---

## `xcind-workspace`

Manages xcind workspaces.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init [DIR] [OPTIONS]` | Initialize a workspace directory |
| `status [DIR] [OPTIONS]` | Show workspace-wide status |
| `list [OPTIONS]` | List all workspaces the registry knows about |
| `register PATH` | Add an existing workspace directory to the registry |
| `forget PATH` | Remove a workspace from the registry |

### Init Options

| Option | Description |
|--------|-------------|
| `--name NAME` | Set `XCIND_WORKSPACE` explicitly (default: directory name) |
| `--proxy-domain DOMAIN` | Set `XCIND_PROXY_DOMAIN` in workspace config |

### Status Options

| Option | Description |
|--------|-------------|
| `--json` | Output structured JSON |

### List Options

| Option | Description |
|--------|-------------|
| `--json` | Output structured JSON |
| `--prune` | Remove stale registry entries (paths that are no longer workspaces) before listing |

### Usage

```bash
xcind-workspace init                         # Initialize current directory
xcind-workspace init ~/Workspaces/dev        # Initialize specific directory
xcind-workspace init --proxy-domain xcind.localhost  # With proxy domain
xcind-workspace init --name myws             # With explicit workspace name
xcind-workspace status                       # Show workspace status
xcind-workspace status --json                # JSON output
xcind-workspace list                         # List all known workspaces
xcind-workspace list --json                  # JSON list
xcind-workspace list --prune                 # Drop stale registry entries
xcind-workspace register ~/code/acme         # Register an existing workspace
xcind-workspace forget ~/code/old-project    # Drop a registry entry
```

### Behavior

**Init:**

- `DIR` defaults to `.` (current directory).
- If `.xcind.sh` already exists with `XCIND_IS_WORKSPACE=1`, re-running with flags updates the config; without flags reports "already initialized".
- If `.xcind.sh` exists without `XCIND_IS_WORKSPACE=1` (an app config), the command prints a helpful error suggesting the correct workspace directory.
- On success, the workspace is added to the global registry at `$XDG_STATE_HOME/xcind/workspaces.tsv`.

**Status:**

- Discovers the workspace root from the given `DIR` or current directory by walking up to find `.xcind.sh` with `XCIND_IS_WORKSPACE=1`.
- Lists all apps (subdirectories with `.xcind.sh`) with running/stopped container counts.
- Shows workspace network and proxy status.
- With `--json`, outputs structured JSON with per-app service details.

**List / register / forget:**

- `list` reads the registry and prints one row per workspace: name, proxy domain, app count, absolute path. Entries whose directory no longer exists (or is no longer a workspace) are hidden; a footer line reports the stale count.
- `--prune` rewrites the registry to drop stale entries before listing.
- `register PATH` adds an existing workspace to the registry. The path must be a directory whose `.xcind.sh` sets `XCIND_IS_WORKSPACE=1`; otherwise the command errors.
- `forget PATH` removes the entry whose absolute path matches. The directory does not need to exist — use this to drop entries for moved or deleted workspaces.
- Workspaces are also auto-registered on every runtime discovery (any `xcind-compose` or `xcind-config` invocation inside a workspace). Registry write failures are silent so state-home issues never break compose runs.

> **Trust boundary:** unlike `xcind-compose` and `xcind-config`, which walk
> *upward* from `$PWD` (so the user has already chosen to `cd` into the
> directory whose `.xcind.sh` is sourced), `xcind-workspace status` walks
> *downward* through the workspace root's immediate non-hidden
> subdirectories and invokes `xcind-config` on each one whose `.xcind.sh`
> is an app (nested workspaces and hidden dirs like `.git` are skipped).
> `xcind-workspace list` similarly sources each registered workspace's
> `.xcind.sh` in a subshell to resolve its name and proxy domain. Each
> discovered `.xcind.sh` is therefore executed, and any `$(cmd)`
> substitutions in it will run. Do not run `xcind-workspace status` or
> `list` against workspaces you do not trust; if a hostile workspace ends
> up in your registry (e.g. via auto-registration after a stray
> `xcind-compose` invocation), drop it with `xcind-workspace forget PATH`.

---

## `xcind-application`

Manages individual xcind applications. Also available as `xcind-app`.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init [DIR] [OPTIONS]` | Initialize an application directory (scaffold `.xcind.sh`) |
| `status [DIR] [OPTIONS]` | Show resolved configuration and container status for a single application |
| `list [DIR] [OPTIONS]` | List applications inside the enclosing workspace |
| `ports [SERVICE] [DIR] [--json]` | Show the host port assigned to each `type=assigned` export |
| `urls [SERVICE] [DIR] [--json]` | Show the URL for each `type=proxied` export (apex URL for the headlining export when an apex template is set) |
| `exports [SERVICE] [DIR] [--json]` | Unified per-export view; proxied entries include `apexUrl`/`apexHost` for the headlining export |

### Init Options

| Option | Description |
|--------|-------------|
| `--name NAME` | Set `XCIND_APP` explicitly (default: directory name) |

### Status Options

| Option | Description |
|--------|-------------|
| `--json` | Output structured JSON |

### List Options

| Option | Description |
|--------|-------------|
| `--json` | Output structured JSON |

### Usage

```bash
xcind-application init                         # Initialize current directory
xcind-application init ./webapp                # Initialize a subdirectory
xcind-application init ./webapp --name api     # With explicit app name
xcind-application status                       # Show status for the current app
xcind-application status ./webapp              # Show status for a specific app
xcind-application status --json                # JSON output
xcind-application list                         # List apps in the enclosing workspace
xcind-application list ~/code/dev --json       # JSON list for a given workspace
xcind-app list                                 # Short alias
```

### Behavior

**Init:**

- `DIR` defaults to `.` (current directory).
- Scaffolds a minimal `.xcind.sh` with `XCIND_COMPOSE_FILES=("compose.yaml")` and, when `--name` is given, an explicit `XCIND_APP` line.
- Refuses to run against a workspace directory (a `.xcind.sh` that sets `XCIND_IS_WORKSPACE=1`); use `xcind-workspace init` to update workspace settings, or scaffold the application in a subdirectory.
- If an app `.xcind.sh` already exists, reports "already initialized" unless `--name` is passed, in which case the file is rewritten with the new `XCIND_APP` value. Other fields you may have hand-edited are not preserved — edit the file directly to avoid losing customizations.
- When the parent directory is a workspace, the success message names the workspace.

**Status:**

- Walks upward from `DIR` (or current directory) to find the nearest app `.xcind.sh` that is not a workspace marker.
- Invokes `xcind-config --json` against the resolved app to discover compose files, env files, workspace membership, and defined services (requires `jq` and `yq`).
- Queries Docker for containers labeled with `xcind.app.name` (and, in workspace mode, `xcind.workspace.name`) to report per-service status.
- With `--json`, outputs a structured object with `app`, `path`, `workspace`, `composeFiles`, `composeEnvFiles`, `definedServices`, `services`, `urls`, `total`, and `running`. The `urls` array is scraped from the running containers' `xcind.export.*.host` labels; when an apex template is set, the headlining (first proxied) export's per-export host is swapped for the apex host, matching `urls`/`exports`.

**List:**

- When `DIR` resolves inside a workspace (either directly or by walking up), enumerates its immediate non-hidden subdirectories whose `.xcind.sh` is an app config. Hidden directories (`.git`, `.cache`, ...) and nested workspaces are skipped.
- When `DIR` is not inside any workspace, falls back to a single-row list if `DIR` itself is a standalone application; otherwise reports "No applications found." This mirrors Scind's single-app workspace pattern and avoids special-casing.

> **Trust boundary:** `xcind-application status` and `list` source
> `.xcind.sh` files from the application and its enclosing workspace, and
> `status` additionally invokes `xcind-config` which resolves variable
> substitutions (including `$(cmd)` patterns) in those files. Do not run
> against applications or workspaces you do not control. See
> [`xcind-workspace`](#xcind-workspace) for a more detailed discussion of
> the same trust model.

---

## `xcind-prompt`

Emits a compact Xcind context segment for a shell prompt (e.g. Starship). Fast
enough to run on every prompt render: bare `--detect` is a stat-walk, and even
the config-sourcing paths avoid `jq`/Docker/hooks and stay within Starship's
500ms budget. Output has no trailing newline, and is empty when run outside any
app.

Default output is `<workspace>/<app>` (or `<app>` when workspaceless).

### Options

| Option | Description |
|--------|-------------|
| `--print FIELD` | Print one field: `both` (default, byte-identical to no `--print`), `workspace` (empty when workspaceless), `app`, `apex` (the OSC 8-linked apex hostname, or empty when no apex), or `apex-url` (the apex URL as plain text `<scheme>://<hostname>`) |
| `--apex` | Append the apex hostname as an OSC 8 clickable hyperlink to the name selectors (`both`/`app`/`workspace`); redundant and ignored for `--print apex` / `--print apex-url` |
| `--no-hyperlink` | Emit plain text (apex hostname, no escape sequences) |
| `--detect` | Exit `0` inside an app, non-zero outside; no output. With `--print` it probes that field's availability (e.g. `--detect --print workspace` exits `0` only in workspace mode; `--detect --print apex` exits `0` only when an apex resolves) |
| `--help`, `-h` | Show usage help |

### Environment

| Variable | Effect |
|----------|--------|
| `XCIND_PROMPT_HYPERLINKS=0` | Disable OSC 8 hyperlinks (same as `--no-hyperlink`) |

`--print apex-url` emits plain text with no OSC 8 sequence, so `--no-hyperlink`
and `XCIND_PROMPT_HYPERLINKS=0` have no effect on it.

### Usage

```bash
xcind-prompt                          # "<workspace>/<app>" (or "<app>")
xcind-prompt --print app              # Just the app name
xcind-prompt --print apex-url         # e.g. "https://my-app.localhost.scind.io"
xcind-prompt --apex                   # Name plus OSC 8-linked apex hostname
xcind-prompt --detect && echo inside  # Branch on being inside an app
```

The `xcind-config --generate-starship` flag emits a ready-to-use Starship
`[custom.xcind]` block (TOML or Nix) that wraps this command.

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
`xcind-proxy`, `xcind-workspace`, and `xcind-application` (plus the
`xcind-app` alias). For `xcind-compose`, completions invoke Docker's
`docker compose __complete` mechanism directly so you get the same experience
as `docker compose` without requiring Docker's shell completion to be loaded.
If that subprocess is unavailable or returns no suggestions, a hardcoded fallback list of common subcommands is used.

---

## Related Documents

- [Configuration Reference](./configuration.md) — All `XCIND_*` variables
- [Proxy Infrastructure Spec](../specs/proxy-infrastructure.md) — Proxy architecture details
- [Architecture Overview](../architecture/overview.md) — System design
