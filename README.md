# Xcind — Docker Compose Application Wrapper

Xcind is a slim shell wrapper around `docker compose` that automatically resolves
compose files, environment files, and override variants based on a per-application
configuration file (`.xcind.sh`).

## Quick Start

1. **Install** — use npm or the install script:

   ```bash
   # npm (recommended)
   npm install -g @scinddev/xcind

   # Or use the install script
   ./install.sh /usr/local
   ```

2. **Configure your application** — create a `.xcind.sh` file in your application root:

   ```bash
   # .xcind.sh
   # For applications using standard compose.yaml / .env, an empty file is enough!
   # Defaults: XCIND_COMPOSE_FILES looks for compose.yaml, compose.yml,
   #           docker-compose.yaml, docker-compose.yml
   #           XCIND_COMPOSE_ENV_FILES looks for .env
   #
   # Override only if your application needs something different:
   XCIND_COMPOSE_ENV_FILES=(".env" ".env.local")
   XCIND_COMPOSE_DIR="docker"
   XCIND_COMPOSE_FILES=("compose.yaml" "compose.dev.yaml")
   ```

3. **Use it** — from anywhere inside your application:

   ```bash
   xcind-compose up -d
   xcind-compose build
   xcind-compose exec php bash
   xcind-compose ps
   ```

## How It Works

When you run `xcind-compose`, it:

1. Walks upward from `$PWD` to find the nearest `.xcind.sh` (the "app root")
2. Sources `.xcind.sh` to load application-specific configuration
3. For each file pattern in the config, expands shell variables and checks if
   the file exists on disk
4. For each existing file, also checks for an `.override` variant
5. Assembles `--env-file` and `-f` flags and passes them to `docker compose`
6. Forwards all your arguments to `docker compose`

## Configuration Reference

The `.xcind.sh` file is a sourceable bash script. It may set the following variables:

### `XCIND_COMPOSE_ENV_FILES`

Array of environment file patterns for Docker Compose YAML interpolation. Each
file that exists on disk is passed via `--env-file` to `docker compose`. These
variables are available for `${VAR}` substitution in compose files but are
**not** injected into running containers. For each file, an `.override` variant
is also checked (e.g., `.env` → `.env.override`).

**Default:** `(".env")`

```bash
XCIND_COMPOSE_ENV_FILES=(".env" ".env.local" '.env.${APP_ENV}')
```

### `XCIND_APP_ENV_FILES`

Array of environment file patterns to inject into all container services via
Docker Compose's `env_file:` directive. Unlike `XCIND_COMPOSE_ENV_FILES`, these
files are available inside the running containers. For each file, an `.override`
variant is also checked.

**Default:** `()` (empty — no app-level injection unless configured)

```bash
XCIND_APP_ENV_FILES=(".env" ".env.local")
```

> **Note:** It is valid and common to list the same file (e.g., `.env`) in both
> `XCIND_COMPOSE_ENV_FILES` and `XCIND_APP_ENV_FILES`. This makes `.env` available
> for both YAML interpolation and inside containers — the behavior most people expect.

### `XCIND_COMPOSE_DIR`

Optional subdirectory where compose files live, relative to the app root.
If set, compose file patterns are resolved relative to this directory.

```bash
XCIND_COMPOSE_DIR="docker"
```

### `XCIND_COMPOSE_FILES`

Array of compose file patterns, relative to `XCIND_COMPOSE_DIR` (or the app root
if `XCIND_COMPOSE_DIR` is unset). Each file that exists on disk is passed via `-f`.
For each file, an `.override` variant is also checked.

**Default:** `("compose.yaml" "compose.yml" "docker-compose.yaml" "docker-compose.yml")`

This mirrors Docker Compose's own file discovery. Only files that actually exist
on disk are used, so listing all four names is safe.

```bash
XCIND_COMPOSE_FILES=(
    "compose.common.yaml"
    'compose.${APP_ENV}.yaml'
    "compose.traefik.yaml"
)
```

### `XCIND_BAKE_FILES`

Array of Docker Bake file patterns, relative to the app root. Reserved for future
use. Currently tracked in `xcind-config` JSON output but not passed to `docker compose`.

```bash
XCIND_BAKE_FILES=("docker-bake.hcl")
```

### `XCIND_TOOLS`

Array of tool declarations for IDE and plugin integration. Each entry maps a
tool name to a Docker Compose service, with optional metadata. The resolved
tools appear in `xcind-config --json` output under the `tools` key.

**Default:** `()` (empty)

Format: `name:service[;key=value[;key=value…]]`

Supported metadata keys:

| Key | Default | Description |
| --- | --- | --- |
| `use` | `exec` | `exec` attaches to a running container; `run` starts a one-shot container |
| `path` | *(none)* | Path to the tool binary inside the container |

When the same tool name appears more than once, the first entry wins.

```bash
XCIND_TOOLS=(
    "node:app"
    "npm:app"
    "composer:app;path=/usr/bin/composer"
    "phpunit:app;use=run;path=vendor/bin/phpunit"
)
```

### `XCIND_ADDITIONAL_CONFIG_FILES`

Array of additional shell scripts to source after `.xcind.sh`. This allows
splitting configuration across multiple files. Paths are resolved relative to
the app root (and the workspace root, if in workspace mode). For each file,
an `.override` variant is also checked.

**Default:** `()` (empty)

```bash
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind-tools.sh" ".xcind-proxy.sh")
```

### `XCIND_IS_WORKSPACE`

Set to `1` in a workspace root's `.xcind.sh` to mark the directory as a workspace.
When xcind discovers an app inside this directory, it sources the workspace
`.xcind.sh` first to set up workspace-level settings. See [Workspace Mode](#workspace-mode).

```bash
XCIND_IS_WORKSPACE=1
```

### `XCIND_HOOKS_GENERATE`

Array of hook function names that generate compose overlay files. Output is cached
by SHA. See [Hooks](#hooks).

**Default:** `("xcind-naming-hook" "xcind-app-env-hook" "xcind-host-gateway-hook" "xcind-proxy-hook" "xcind-workspace-hook")`

### `XCIND_HOOKS_EXECUTE`

Array of hook function names that ensure runtime preconditions before `docker compose`
runs. These run on every invocation (not cached). Only applies to `xcind-compose`.

**Default:** `("__xcind-proxy-execute-hook" "__xcind-workspace-execute-hook")`

Override either array to `()` in your `.xcind.sh` to disable the corresponding hooks.

### `XCIND_PROXY_EXPORTS`

Array of service export declarations. Each entry names an exported service
and picks between the two port-exposure mechanisms via an optional `type`
attribute: `proxied` (default) routes traffic through Traefik, `assigned`
reserves a stable host port. See [Proxy](#proxy).

**Default:** `()` (empty)

Format: `export_name[=compose_service][:port][;key=value[;key=value…]]`

```bash
XCIND_PROXY_EXPORTS=(
    "api=app:3000"                   # proxied (default), service "app", port 3000
    "web:8080"                       # proxied, service "web", port 8080
    "app"                            # proxied, port inferred from compose config
    "worker:9000;type=assigned"      # assigned host port 9000 (sticky across runs)
    "database=db:3306;type=assigned" # assigned host port 3306, compose service "db"
)
```

`type=proxied` entries flow through `xcind-proxy-hook` (Traefik labels).
`type=assigned` entries flow through `xcind-assigned-hook`, which publishes
the container port on a stable host port and persists the binding under
`${XDG_STATE_HOME:-~/.local/state}/xcind/proxy/assigned-ports.tsv`.

### `XCIND_PROXY_DOMAIN`

Domain suffix for generated proxy hostnames. Can be set in the workspace
`.xcind.sh` or in the global proxy config.

**Default:** `"localhost"` (RFC 6761 — `.localhost` requires zero DNS configuration)

```bash
XCIND_PROXY_DOMAIN="xcind.localhost"
```

### URL Template Variables

These control how hostnames, router names, and network aliases are generated.
Defaults are provided for both workspaceless and workspace modes.

| Variable | Default | Used when |
| --- | --- | --- |
| `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` | `{app}-{export}.{domain}` | No workspace |
| `XCIND_WORKSPACE_APP_URL_TEMPLATE` | `{workspace}-{app}-{export}.{domain}` | In workspace |
| `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` | `{app}-{export}-{protocol}` | No workspace |
| `XCIND_WORKSPACE_ROUTER_TEMPLATE` | `{workspace}-{app}-{export}-{protocol}` | In workspace |
| `XCIND_WORKSPACE_SERVICE_TEMPLATE` | `{app}-{service}` | Workspace networking |
| `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` | `{app}.{domain}` | No workspace (apex) |
| `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` | `{workspace}-{app}.{domain}` | In workspace (apex) |
| `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` | `{app}-{protocol}` | No workspace (apex) |
| `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` | `{workspace}-{app}-{protocol}` | In workspace (apex) |

Placeholders (`{app}`, `{workspace}`, `{export}`, `{domain}`, `{protocol}`, `{service}`)
are replaced at runtime.

Apex templates generate shorter hostnames without the `{export}` segment (e.g.,
`myapp.localhost` instead of `myapp-web.localhost`). Set an apex template to an
empty string to disable apex hostname generation.

## Override Resolution

For files with a recognized extension (`.yaml`, `.yml`, `.json`, `.hcl`, `.toml`),
the override variant inserts `.override` before the extension:

| Base file                | Override variant                |
| ------------------------ | ------------------------------- |
| `compose.yaml`           | `compose.override.yaml`         |
| `compose.common.yaml`    | `compose.common.override.yaml`  |
| `docker-bake.hcl`        | `docker-bake.override.hcl`      |

For all other files (like env files), `.override` is appended:

| Base file     | Override variant      |
| ------------- | --------------------- |
| `.env`        | `.env.override`       |
| `.env.local`  | `.env.local.override` |

Files that don't exist on disk are silently skipped — both the base file and
its override variant.

## Variable Expansion

File patterns support shell variable expansion. Variables are expanded at
runtime, so environment-specific files work naturally:

```bash
XCIND_COMPOSE_FILES=(
    "compose.common.yaml"
    'compose.${APP_ENV}.yaml'    # Note: single quotes to prevent premature expansion
)
```

With `APP_ENV=dev`, xcind checks for `compose.dev.yaml` and `compose.dev.override.yaml`.
With `APP_ENV=prod`, it checks for `compose.prod.yaml` and `compose.prod.override.yaml`.

## Workspace Mode

Xcind supports grouping multiple applications into a **workspace**. A workspace
is a parent directory containing its own `.xcind.sh` with `XCIND_IS_WORKSPACE=1`.

### How it works

When xcind finds an app's `.xcind.sh`, it checks whether the **parent directory**
also has a `.xcind.sh`. If that file sets `XCIND_IS_WORKSPACE=1`, xcind enters
workspace mode:

1. Sources the workspace `.xcind.sh` first (sets workspace-level hooks, domain, etc.)
2. Then sources the app's `.xcind.sh` (overrides app-specific settings)

### Workspace variables

These are set automatically when workspace mode is active:

| Variable | Value |
| --- | --- |
| `XCIND_WORKSPACE` | Basename of the workspace directory |
| `XCIND_WORKSPACE_ROOT` | Absolute path to the workspace directory |
| `XCIND_WORKSPACELESS` | `0` in workspace mode, `1` otherwise |

### Self-declaration

An app can also declare itself part of a workspace without a parent `.xcind.sh`
by setting `XCIND_WORKSPACE` directly in its own `.xcind.sh`:

```bash
XCIND_WORKSPACE="myworkspace"
```

### Example layout

```
dev/                          # workspace root
├── .xcind.sh                 # XCIND_IS_WORKSPACE=1, hooks, proxy domain
├── frontend/                 # app
│   ├── .xcind.sh             # app config + XCIND_PROXY_EXPORTS
│   └── compose.yaml
└── backend/                  # app
    ├── .xcind.sh
    └── compose.yaml
```

The workspace `.xcind.sh` marks the directory and sets workspace-level config:

```bash
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
```

The proxy and workspace hooks are built-in and registered by default — no manual
sourcing or hook registration is needed.

## Hooks

Hooks let xcind generate additional compose files dynamically after file
resolution. The built-in proxy and workspace hooks are registered by default.
Custom hooks can be added via `XCIND_HOOKS_GENERATE` and `XCIND_HOOKS_EXECUTE`.

### How hooks work

1. Each hook is a bash function that receives the app root as its argument
2. The hook writes a generated compose file to `$XCIND_GENERATED_DIR`
3. The hook prints compose flags (e.g., `-f /path/to/generated.yaml`) to stdout
4. Xcind appends those flags to the `docker compose` invocation

### Caching

Hook output is cached using a SHA-256 hash computed from:
- Compose file paths and content
- App `.xcind.sh` content
- Workspace `.xcind.sh` content (if in workspace mode)
- Global proxy config (if present)

On subsequent runs with the same hash, xcind replays the cached output instead
of re-running hooks. The cache lives at `$XCIND_APP_ROOT/.xcind/generated/`.

### Built-in hooks

**`xcind-naming-hook`** (from `lib/xcind/xcind-naming-lib.bash`)

Generates `compose.naming.yaml` with a top-level `name:` field to prevent
container/volume/network name collisions across workspaces with
identically-named app directories. In workspace mode the name is
`{workspace}-{app}`; otherwise it is `{app}`.

**`xcind-app-env-hook`** (from `lib/xcind/xcind-app-env-lib.bash`)

Generates a compose override that adds `env_file:` entries to every service,
making `XCIND_APP_ENV_FILES` available inside running containers. Requires
`yq`. Only active when `XCIND_APP_ENV_FILES` is non-empty.

**`xcind-host-gateway-hook`** (from `lib/xcind/xcind-host-gateway-lib.bash`)

Generates `compose.host-gateway.yaml` with `extra_hosts` entries mapping
`host.docker.internal` to the developer's workstation for every service that
doesn't already define the mapping. Handles platform detection automatically
(Docker Desktop, native Linux, WSL2 NAT/mirrored modes). Requires `yq`;
if `yq` is unavailable, the hook is skipped with a warning. Disable with
`XCIND_HOST_GATEWAY_ENABLED=0` in `.xcind.sh`. Override the detected value
with `XCIND_HOST_GATEWAY=<value>`.

**`xcind-proxy-hook`** (from `lib/xcind/xcind-proxy-lib.bash`)

Generates `compose.proxy.yaml` with Traefik labels and network configuration
based on `XCIND_PROXY_EXPORTS`. Requires `yq` and an initialized proxy
(`xcind-proxy init`).

**`xcind-workspace-hook`** (from `lib/xcind/xcind-workspace-lib.bash`)

Generates `compose.workspace.yaml` with network aliases so services across
apps in the same workspace can reach each other. Creates a
`{workspace}-internal` Docker network. Requires `yq`. Only active in
workspace mode.

## Proxy

Xcind includes a shared Traefik reverse proxy for routing traffic to
application services by hostname.

### Setup

```bash
xcind-proxy init    # Create proxy infrastructure
xcind-proxy up      # Start the shared Traefik proxy
```

### How it works

1. `xcind-proxy init` creates a Traefik configuration and Docker network (`xcind-proxy`)
2. Apps declare exports via `XCIND_PROXY_EXPORTS` in their `.xcind.sh`
3. The `xcind-proxy-hook` generates Traefik labels so each export gets a hostname
4. Traffic to `{app}-{export}.{domain}` is routed to the correct container and port

### Proxy exports

Each entry in `XCIND_PROXY_EXPORTS` maps an export name to a compose service:

```bash
XCIND_PROXY_EXPORTS=(
    "api=app:3000"    # export "api" → service "app", port 3000
    "web:8080"        # export "web" → service "web", port 8080
    "app"             # export "app" → service "app", port from compose config
)
```

When the export name is omitted (`web:8080`), it defaults to the service name.
When the port is omitted (`app`), it is inferred from the service's port mapping
(requires exactly one port mapping).

### Generated hostnames

| Mode | Template | Example |
| --- | --- | --- |
| Workspaceless | `{app}-{export}.{domain}` | `myapp-api.localhost` |
| Workspace | `{workspace}-{app}-{export}.{domain}` | `dev-backend-api.xcind.localhost` |

### Global proxy configuration

`xcind-proxy init` creates `~/.config/xcind/proxy/config.sh` (user-editable) and
generated files in `~/.local/state/xcind/proxy/`. Config defaults:

```bash
XCIND_PROXY_DOMAIN="localhost"         # Domain suffix for hostnames
XCIND_PROXY_IMAGE="traefik:v3"         # Traefik Docker image
XCIND_PROXY_HTTP_PORT="80"             # Host port for HTTP traffic
XCIND_PROXY_DASHBOARD="false"          # Enable Traefik dashboard
XCIND_PROXY_DASHBOARD_PORT="8080"      # Dashboard port (if enabled)
XCIND_PROXY_AUTO_START="1"             # Auto-start Traefik on compose up (0 to disable)
```

Edit this file to customize the proxy. Run `xcind-proxy up` to regenerate
and apply changes (the config file is never overwritten).

## Commands

### `xcind-compose`

The main workhorse. Resolves config and passes everything through to `docker compose`.

```bash
xcind-compose up -d
xcind-compose build --no-cache
xcind-compose exec php bash
xcind-compose down --remove-orphans
```

### `xcind-config`

Dumps the resolved configuration. Useful for debugging and for the JetBrains plugin.

```bash
xcind-config                                           # Show help
xcind-config --json                                    # JSON output
xcind-config --preview                                 # Show the docker compose command line
xcind-config --check                                   # Check system dependencies
xcind-config --generate-docker-wrapper                 # Generate a POSIX docker wrapper script
xcind-config --generate-docker-compose-wrapper         # Generate a POSIX docker-compose wrapper script
xcind-config --generate-docker-compose-configuration[=FILE]  # Generate resolved compose config
xcind-config --version                                 # Show version
xcind-config completion bash                           # Output bash completions
xcind-config completion zsh                            # Output zsh completions
```

### `xcind-proxy`

Manages the shared Traefik reverse proxy infrastructure.

```bash
xcind-proxy init        # Create proxy config and generated files
xcind-proxy up          # Start the proxy
xcind-proxy up --force  # Recreate proxy containers and Docker network
xcind-proxy down        # Stop the proxy
xcind-proxy status [--json]  # Show proxy state (running/stopped, port, network)
xcind-proxy logs [OPTS] # Show Traefik proxy logs (supports docker compose logs flags)
xcind-proxy --version   # Show version
```

## Environment Variable Override

Set `XCIND_APP_ROOT` to bypass automatic root detection:

```bash
XCIND_APP_ROOT=/path/to/app xcind-compose up
```

## Tab Completion

Xcind provides shell completions for all commands (`xcind-compose`,
`xcind-config`, `xcind-proxy`). Add one line to your shell config:

```bash
# Bash (~/.bashrc)
. <(xcind-config completion bash)

# Zsh (~/.zshrc)
. <(xcind-config completion zsh)
```

For `xcind-compose`, completions are delegated to Docker's built-in completion
so you get the same experience as `docker compose`.

## Direnv Integration

Xcind works independently of direnv. If you use direnv, you can optionally
source `.xcind.sh` from your `.envrc` to get the config variables in your shell:

```bash
# .envrc
source_env .xcind.sh
```

## JetBrains Plugin

The `xcind-config --json` command outputs JSON compatible with the xcind JetBrains
plugin. Point the plugin at the `xcind-config` script path, and it will
resolve compose files and env files for your IDE's Docker integration.

## Installation

### npm (recommended)

```bash
# Global install
npm install -g @scinddev/xcind

# Or run directly with npx
npx -p @scinddev/xcind xcind-compose up -d
npx -p @scinddev/xcind xcind-config --json
```

### Install script

```bash
# Install to /usr/local (may need sudo)
sudo ./install.sh

# Install to a custom prefix
./install.sh ~/.local

# Uninstall
sudo ./uninstall.sh
./uninstall.sh ~/.local
```

### Nix

Xcind provides a Nix flake for installation and integration.

```bash
# Install imperatively
nix profile install github:scinddev/xcind

# Or run directly without installing
nix run github:scinddev/xcind -- up -d
nix run github:scinddev/xcind#xcind -- up -d
```

To use in another flake, reference the package output directly:

```nix
{
  inputs.xcind.url = "github:scinddev/xcind";

  outputs = { self, nixpkgs, xcind, ... }:
    let
      system = "x86_64-linux"; # or "aarch64-darwin", etc.
    in {
      devShells.${system}.default = nixpkgs.legacyPackages.${system}.mkShell {
        buildInputs = [ xcind.packages.${system}.default ];
      };
    };
}
```

Alternatively, use the overlay to access xcind as `pkgs.xcind`:

```nix
{
  inputs.xcind.url = "github:scinddev/xcind";

  # Add the overlay
  nixpkgs.overlays = [ xcind.overlays.default ];

  # Then use pkgs.xcind in your packages
  environment.systemPackages = [ pkgs.xcind ];
}
```

## Docker

The published Docker image is available on GHCR:

```bash
docker pull ghcr.io/scinddev/xcind:latest
```

To use it, bind-mount your project directory into the container's `/workspace`
and mount the Docker socket so `docker compose` can reach the daemon:

```bash
docker run --rm \
  -v "$PWD":/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/scinddev/xcind:latest up -d
```

The image's entrypoint is `xcind-compose`, so any arguments are forwarded
directly. To run `xcind-config` instead, override the entrypoint:

```bash
docker run --rm \
  -v "$PWD":/workspace \
  --entrypoint xcind-config \
  ghcr.io/scinddev/xcind:latest --preview
```

### Development and testing

Build and run the test suite in a container:

```bash
docker compose build
docker compose run xcind
```

Test against a specific bash version:

```bash
docker compose build --build-arg BASHVER=5.1
docker compose run xcind
```

For an interactive shell, copy the override template:

```bash
cp compose.override.dist compose.override.yaml
docker compose run xcind
```

## Upgrading

Xcind is stateless — there is no data to migrate between versions. To upgrade,
use the same method you used to install:

```bash
# npm
npm install -g @scinddev/xcind@latest

# Install script — download the new release and re-run
sudo ./install.sh            # or: ./install.sh ~/.local

# Nix
nix profile upgrade '.*xcind.*'

# Docker
docker pull ghcr.io/scinddev/xcind:latest
```

Check which version you're running at any time:

```bash
xcind-config --version
```

## License

MIT — see [LICENSE](LICENSE) for details.

## File Structure

```
xcind/
├── bin/
│   ├── xcind-compose              # Main executable — wraps docker compose
│   ├── xcind-config               # Config dump — JSON, preview, code generation
│   └── xcind-proxy                # Manages shared Traefik proxy infrastructure
├── lib/xcind/
│   ├── xcind-lib.bash             # Shared library (sourced by other scripts)
│   ├── xcind-app-env-lib.bash     # App env hook — generates env_file: overrides
│   ├── xcind-host-gateway-lib.bash # Host gateway hook — generates extra_hosts overrides
│   ├── xcind-naming-lib.bash      # Naming hook — generates compose.naming.yaml
│   ├── xcind-proxy-lib.bash       # Proxy hook — generates compose.proxy.yaml
│   ├── xcind-workspace-lib.bash   # Workspace hook — generates compose.workspace.yaml
│   ├── xcind-completion-bash.bash # Bash tab-completion script
│   └── xcind-completion-zsh.bash  # Zsh tab-completion script
├── test/
│   ├── test-xcind.sh              # Core test suite
│   └── test-xcind-proxy.sh        # Proxy test suite
├── examples/
│   ├── workspaceless/
│   │   ├── acmeapps/              # Simple example (nginx, env files)
│   │   └── advanced/              # Variable expansion, multi-compose, traefik
│   └── workspaces/
│       └── dev/                   # Workspace with frontend + backend apps
├── contrib/
│   ├── check-file-manifest        # Verify files are registered in all manifests
│   ├── release                    # Release helper script
│   └── test-all                   # Full test runner (Docker + unit)
├── docs/                          # Project documentation
│   ├── architecture/              # System design and structure
│   ├── behaviors/                 # Runtime behavior documentation
│   ├── decisions/                 # Architecture decision records
│   ├── implementation/            # Implementation details
│   ├── maintenance/               # Maintenance and operations
│   ├── product/                   # Product-level documentation
│   ├── reference/                 # Configuration and CLI reference
│   ├── specs/                     # Feature specifications
│   └── releasing.md               # Release process documentation
├── compose.yaml                   # Default Docker Compose configuration
├── compose.override.dist          # Compose override template
├── Dockerfile                     # Container image build
├── Makefile                       # Build targets (test, lint, format, check)
├── flake.nix                      # Nix flake (package + overlay)
├── flake.lock                     # Nix flake lock file
├── install.sh                     # Install to a PREFIX
├── uninstall.sh                   # Remove from a PREFIX
├── package.json                   # npm package manifest
├── cliff.toml                     # Changelog generation config (git-cliff)
├── CHANGELOG.md                   # Release changelog
├── LICENSE                        # MIT license
└── README.md
```
