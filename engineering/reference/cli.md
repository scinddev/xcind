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
| `--json` | JSON output (`metadata`, `appRoot`, `configFiles`, `composeFiles`, `composeEnvFiles`, `appEnvFiles`, `bakeFiles`, `bins`, `scripts`) |
| `resolve <path> [--cached] [--hooks-ttl=N]` | One value from the resolved xcind or Compose configuration |
| `resolve --help` | The resolvable top-level keys, the path syntax, and the exit codes |
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
xcind-config resolve metadata.app                  # Raw xcind scalar
xcind-config resolve compose.volumes.data.name     # Resolved Compose volume name
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

### Single-value resolution

`xcind-config resolve` uses one root. A path that starts with `compose.`
reads `.xcind/cache/{sha}/resolved-config.json`. All other paths read the
xcind `config.json` contract. The contract reserves `compose` as a
top-level key.

The exact `compose` path and the trailing-dot `compose.` path are malformed;
callers must select a value below `compose.*`.

#### Path grammar

A path is one or more segments, separated by dots. A segment is a bare key or
a quoted key, and can carry numeric array indexes:

```
path    := segment ( "." segment )*
segment := ( bare | quoted ) index*
bare    := [A-Za-z_][A-Za-z0-9_-]*
quoted  := '"' ( any character, with \" and \\ escaped ) '"'
index   := "[" [0-9]+ "]"
```

Quote a key to read one that contains a dot, such as a Compose label:

```bash
xcind-config resolve 'compose.services.web.labels."traefik.http.routers.web.rule"'
```

One leading dot is accepted and removed. Arbitrary jq programs are not
accepted. Scalars print as raw values. Objects and arrays print as compact
JSON.

#### Exit status

| Status | Meaning |
|--------|---------|
| `0` | The path holds a non-null value |
| `1` | The path holds no value: absent, `null`, or blocked by a scalar |
| `2` | Resolved state or jq is unavailable |
| `64` | Usage error, including a malformed path |

Status `1` is silent when the path is simply absent. When the path runs
through a scalar — `metadata.app.nested`, where `metadata.app` is a string —
the command writes a `path is not traversable` line to stderr and still exits
`1`. Callers that must tell the two apart can read stderr.

#### Cache and hooks

The default hook TTL is five seconds. During that window, repeated resolution
skips the complete cache-refresh leg. Set `XCIND_HOOKS_TTL=0` or pass
`--hooks-ttl=0` to disable TTL reuse. An explicit `--hooks-ttl=N` value takes
precedence over `XCIND_HOOKS_TTL` sourced from the app configuration.

`--cached` does not run Docker or hooks and exits with status `2` when
current-SHA artifacts are unavailable.
`--cached` also reuses the host-gateway value that the last full run stored
in `.xcind/cache/.host-gateway-detected`, so its SHA reflects the gateway as
of that run, not the current one.

Only `compose.*` paths need the cache. An app that sets
`XCIND_HOOKS_GENERATE=()` builds no cache directory; xcind paths still
resolve, because the command builds the same `config.json` contract in
memory. A `compose.*` path in that app exits `2` and names the cause.

With `--cached`, xcind paths also require current-SHA artifacts and exit `2`
instead of using the in-memory contract.

`resolve` keeps the resolution pipeline quiet on stderr, so that scripts read
clean output. Set `XCIND_DEBUG=1` to let the pipeline's diagnostics through.

#### Compose name lookups

`compose.project.name` is the one derived path: it aliases the top-level
`name` of the Compose document. Every other `compose.*` path is a direct
lookup.

`compose.volumes.<key>.name` and `compose.networks.<key>.name` need no
special handling. `docker compose config` resolves both itself, and has done
so since 2.6 — the floor this command already requires. Verified against
2.6.0, 2.20.3 and 2.29.7: each emits a resolved `name` for every volume and
network. Project-scoped entries read as `{project}_{key}`; entries marked
`external: true` keep their own un-prefixed name.

Do not reintroduce a `{project}_{key}` fallback here. It would be
unreachable for supported Compose versions, and wrong for external entries,
which Compose deliberately leaves un-prefixed.

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
  "bins": {
    "php": { "service": "app", "use": "exec", "cmd": "php" },
    "npm": { "service": "app", "use": "exec", "cmd": "npm" }
  },
  "scripts": {
    "fresh": {
      "steps": ["-rm -rf node_modules", "@npm install"],
      "desc": "Reinstall node modules from scratch"
    }
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

The `bins` object is keyed by bin name. Each entry includes `service`, `use` (default `"exec"`), `cmd` (always present; default: the bin's name), and optionally `desc`. See [`XCIND_BINS`](./configuration.md#xcind_bins) for the declaration format.

The `scripts` object is keyed by script name. Each entry includes `steps` (the raw steps, comments removed, a step's leading `-` kept) and optionally `desc`. See [`XCIND_SCRIPTS`](./configuration.md#xcind_scripts) for the declaration format.

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
| `dispose [--purge] [--yes]` | Stop the proxy, remove its network and generated state |
| `status [--json]` | Show proxy state (running/stopped, image, port, network, assigned ports). In external mode: `Status: external`, the detected proxy container, and `mode`/`status: "external"` in the JSON |
| `logs [OPTS]` | Show Traefik proxy logs (supports `docker compose logs` flags) |
| `release PORT` | Release an assigned port from the state file |
| `prune` | Remove assigned-port entries whose app path no longer exists |

### Init Options

| Option | Config Variable | Default |
|--------|----------------|---------|
| `--mode MODE` | `XCIND_PROXY_MODE` | `managed` (`managed` \| `external`) |
| `--network NAME` | `XCIND_PROXY_NETWORK` | `xcind-proxy` |
| `--http-entrypoint NAME` | `XCIND_PROXY_HTTP_ENTRYPOINT` | `web` |
| `--https-entrypoint NAME` | `XCIND_PROXY_HTTPS_ENTRYPOINT` | `websecure` |
| `--certresolver NAME` | `XCIND_PROXY_CERTRESOLVER` | Empty |
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

In external mode (`--mode external`, see [ADR-0022](../decisions/0022-external-proxy-mode.md)):
`--tls-mode custom` is a hard error, managed-only flags (`--image`,
`--dashboard*`, `--http-port`, `--https-port`, `--tls-cert-file`,
`--tls-key-file`) warn but are still persisted, `up` only verifies the shared
network (`--force` refuses), and `down`/`logs` refuse since the proxy is not
xcind-managed. `dispose` never removes the shared external network; during a
migration, it can stop a retained xcind-managed proxy before it removes its
generated state. If that teardown fails, `dispose` leaves generated state
intact for a retry, because `compose.yaml` is the only remaining handle for
stopping that proxy. When the teardown can never succeed — a corrupt
`compose.yaml`, for example — stop the container by hand and then remove
`${XDG_STATE_HOME:-$HOME/.local/state}/xcind/proxy` yourself; no CLI path removes state that
`dispose` still needs.

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
xcind-proxy init --mode external --network coolify \
  --http-entrypoint http --https-entrypoint https --certresolver letsencrypt
xcind-proxy up            # Start the proxy
xcind-proxy up --force    # Recreate network and restart
xcind-proxy down          # Stop the proxy
xcind-proxy dispose        # Remove generated state but preserve config.sh
xcind-proxy dispose --purge --yes  # Also remove config.sh
xcind-proxy status        # Show proxy state
xcind-proxy status --json # Show proxy state as JSON
xcind-proxy logs          # Show logs
xcind-proxy logs -f       # Follow logs
xcind-proxy --version     # Show version
```

### Dispose Behavior

- `dispose` removes the whole generated state directory, which holds `assigned-ports.tsv`. Every application therefore loses its port assignments and receives new host ports on the next `up`. The confirmation prompt counts the bindings it is about to forget; `--yes` skips that prompt, so scripted disposal drops them silently.
- `--purge` also removes the config directory (`config.sh`). Without it, configuration survives so a later `init` keeps the user's settings.
- When the proxy is already disposed, `dispose` exits 0 without prompting. With `--purge` and a surviving config directory, it prompts for the purge alone.

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

## `xcind-run`

Runs bins and scripts declared in `XCIND_BINS` / `XCIND_SCRIPTS` inside the app's Compose services.

```
xcind-run [-T|--no-tty] <name> [args…]
xcind-run [-T] @exec <svc> [cmd…] | @run <svc> <cmd…> | @compose <args…>
xcind-run --list [--names]
xcind-run --init-shell [--prefix PREFIX]
xcind-run --help | --version
```

Runner flags go before the name; everything after the name belongs to it.

- **Bins** run as `docker compose … exec <svc> <cmd…> <args…>` (`use=run` → `run --rm`). Args always append. The bin's `cmd` is tokenized at run time without expansion.
- **Scripts** run their steps in order and stop at the first failure with its exit status; a step's leading `-` ignores its failure. The first word picks the step kind (`@exec`/`@run`/`@compose`, `@<bin>`/`@<script>`, else a host step via `bash -c` — the only place shell expansion happens). Script-to-script cycles fail with the call path (`script cycle: a -> b -> a`).
- **Arguments**: spliced at bare `$@`/`"$@"` tokens; a one-step script with no `$@` appends them; args to a multi-step script with no `$@` exit 64.
- **TTY**: `-T` is passed to `exec`/`run` when stdin or stdout is not a terminal, or when forced with `-T`/`--no-tty`.
- **Namespace**: bins and scripts share one namespace; a name in both is a load-time error. A leading `_` hides a name from `--list` and `--init-shell` but it stays runnable.
- **Pipeline**: runs `__xcind-prepare-app` (with the GENERATE-hook TTL) and the EXECUTE hooks, like `xcind-compose`.

`--init-shell` emits `<prefix><name>() { xcind-run <name> "$@"; }` per visible name (default prefix `x-`), for `eval` in a shell rc.

---

## `xcind-workspace`

Manages xcind workspaces.

### Subcommands

| Subcommand | Description |
|------------|-------------|
| `init [DIR] [OPTIONS]` | Initialize a workspace directory |
| `up [DIR] [-a NAME...]` | Run `xcind-compose up -d` in every (or selected) application directory |
| `down [DIR] [-a NAME...] [--volumes] [--yes]` | Run `xcind-compose down` in every (or selected) application directory (confirms first) |
| `restart [DIR] [-a NAME...] [--yes]` | Run `down` then `up` across every (or selected) application directory (confirms first); volumes are never removed |
| `status [DIR] [OPTIONS]` | Show workspace-wide status |
| `list [OPTIONS]` | List all workspaces the registry knows about |
| `register PATH` | Add an existing workspace directory to the registry |
| `forget PATH` | Remove a workspace from the registry |
| `dispose [DIR] [--volumes] [--rm] [--yes]` | Dispose applications, network, registry entry, and optionally the directory |

### Init Options

| Option | Description |
|--------|-------------|
| `--name NAME` | Set `XCIND_WORKSPACE` explicitly (default: directory name) |
| `--proxy-domain DOMAIN` | Set `XCIND_PROXY_DOMAIN` in workspace config |

### Up, Down, and Restart Options

| Option | Description |
|--------|-------------|
| `-a NAME`, `--app NAME` | Limit the pass loop to the named application (repeatable); NAME is an application directory basename within the workspace |
| `--volumes` | `down` only: forward `-v` to each application's `xcind-compose down` call |
| `--yes`, `-y` | `down`/`restart` only: skip the confirmation prompt |

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
xcind-workspace up                           # Bring up every app in the workspace
xcind-workspace up -a api -a worker          # Bring up only "api" and "worker"
xcind-workspace down --yes                   # Bring down every app, no prompt
xcind-workspace down --volumes               # Bring down every app, also remove volumes
xcind-workspace down -a api --yes            # Bring down only "api", no prompt
xcind-workspace restart --yes                # Down then up every app, no prompt
xcind-workspace status                       # Show workspace status
xcind-workspace status --json                # JSON output
xcind-workspace list                         # List all known workspaces
xcind-workspace list --json                  # JSON list
xcind-workspace list --prune                 # Drop stale registry entries
xcind-workspace register ~/code/acme         # Register an existing workspace
xcind-workspace forget ~/code/old-project    # Drop a registry entry
xcind-workspace dispose ~/code/acme --rm --volumes --yes
```

### Behavior

**Init:**

- `DIR` defaults to `.` (current directory).
- If `.xcind.sh` already exists with `XCIND_IS_WORKSPACE=1`, re-running with flags updates the config; without flags reports "already initialized".
- If `.xcind.sh` exists without `XCIND_IS_WORKSPACE=1` (an app config), the command prints a helpful error suggesting the correct workspace directory.
- On success, the workspace is added to the global registry at `$XDG_STATE_HOME/xcind/workspaces.tsv`.

**Up / down / restart:**

- Discovers the workspace root by walking up from `DIR` (default: current directory), then runs `xcind-compose up -d` (`up`) or `xcind-compose down` (`down`) in every immediate application directory. `restart` is `down` followed by `up`, composed from the same per-app loop: a full down pass across every application, then a full up pass across every application. Volumes are never touched during `restart` (its internal `down` never passes `-v`).
- `-a NAME`/`--app NAME` (repeatable, all three verbs) limits the pass loop to the named application directories instead of every enumerated application. `NAME` matches an application directory's basename within the already-discovered workspace root — this is a filter on the per-app loop only, not a name-based workspace lookup (workspace discovery stays purely location-based; see ADR [0023](../decisions/0023-location-based-targeting.md)). An unrecognized name errors out before any application is touched, naming the unknown app and listing the available ones.
- `down --volumes` forwards `-v` to each application's `xcind-compose down` call, removing that application's Docker volumes. `up` and `restart` reject `--volumes` — `restart`'s down pass always preserves volumes, matching canon.
- Each pass continues past a failing application and reports the failed directories at the end; any failure in either pass makes the command exit non-zero. For `restart`, the up pass still runs even if applications failed to come down in the down pass — this matches the continue-past-failure behavior within a single pass, rather than making the second pass conditional on the first. Failures from both passes are reported together.
- `down` and `restart` confirm before acting, listing only the applications that will be affected (all of them, or the `-a`-selected subset); `--yes`/`-y` skips the prompt. The `down` prompt also states when `--volumes` will remove data. `up` takes no confirmation option (no prompt).

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

**Dispose:**

- Disposes each immediate application by calling `xcind-application dispose`; `--volumes` and `--yes` are forwarded, while workspace `--rm` removes the root only after every application succeeds.
- If any application fails, the workspace network, registry entry, and directory remain intact. A missing explicit workspace path is an idempotent cleanup that only forgets the registry entry.
- Every form of `dispose` confirms first. Supply `--yes` to skip the prompt; a non-interactive session without `--yes` refuses instead of blocking.
- `--rm` refuses paths that are unsafe to remove recursively: the filesystem root, `$HOME`, and single-component paths such as `/srv`.

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
| `dispose [DIR] [--volumes] [--rm] [--yes]` | Tear down runtime state and release assigned ports |
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
xcind-application dispose ./webapp --volumes --yes
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

**Dispose:**

- Runs `xcind-compose down --remove-orphans`, adding `-v` only with `--volumes`; only after successful runtime teardown does it release assigned ports and remove `.xcind/` generated state.
- Every form of `dispose` confirms first, including the default one that keeps the directory. Supply `--yes` to skip the prompt; a non-interactive session without `--yes` refuses instead of blocking. The prompt names the resolved application root, which matters because `DIR` walks upward the way `xcind-compose` does.
- `--rm` requires a recognized application directory and refuses paths that are unsafe to remove recursively: the filesystem root, `$HOME`, and single-component paths such as `/srv`. Missing or already-disposed paths succeed without changes.

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
`xcind-proxy`, `xcind-run`, `xcind-workspace`, and `xcind-application` (plus
the `xcind-app` alias). For `xcind-compose`, completions invoke Docker's
`docker compose __complete` mechanism directly so you get the same experience
as `docker compose` without requiring Docker's shell completion to be loaded.
If that subprocess is unavailable or returns no suggestions, a hardcoded fallback list of common subcommands is used.

### `xcind-shell-aliases [PREFIX]`

Defined by both completion scripts. Defines one shell function per xcind
command and registers that command's completion function against the new
name, so a short name completes exactly like the command it wraps.

**Default prefix:** `x-`

**Wrapper name:** `<PREFIX><command minus its `xcind-` prefix>`, giving
`x-application`, `x-app`, `x-compose`, `x-config`, `x-proxy`, `x-run`, and
`x-workspace`. `xcind-prompt` is excluded: it draws prompt segments, has no
completion, and is not typed interactively.

**Validation:** `PREFIX` must match `[a-zA-Z0-9_-]*`; anything else returns
64 with the same wording as [`xcind-run --prefix`](#xcind-run). An empty
`PREFIX` falls back to `x-`.

**Scope:** install-scoped. The command list lives in the completion script,
not in an app's `.xcind.sh`, so one call per shell applies in every
directory and no app resolution runs. It declares nothing for `XCIND_BINS` or
`XCIND_SCRIPTS`; those stay reachable through `xcind-run`, whose own
completion re-reads the current app on every request.

Re-registration is sound because no completion function reads the invoked
command name — `_xcind-compose` forwards `"${words[@]:1}"` to
`docker __complete compose` and drops word 1. `test-xcind-completion.sh`
asserts that the wrapper map and the `complete -F` / `compdef` registrations
agree, so the two cannot drift.

```bash
. <(xcind-config completion bash)
xcind-shell-aliases
x-compose up -d
x-config --json
```

---

## Related Documents

- [Configuration Reference](./configuration.md) — All `XCIND_*` variables
- [Proxy Infrastructure Spec](../specs/proxy-infrastructure.md) — Proxy architecture details
- [Architecture Overview](../architecture/overview.md) — System design
