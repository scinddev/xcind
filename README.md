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
   #           XCIND_ENV_FILES looks for .env
   #
   # Override only if your application needs something different:
   XCIND_ENV_FILES=(".env" ".env.local")
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

### `XCIND_ENV_FILES`

Array of environment file patterns, relative to the app root. Each file that
exists on disk is passed via `--env-file`. For each file, an `.override` variant
is also checked (e.g., `.env` → `.env.override`).

**Default:** `(".env")`

```bash
XCIND_ENV_FILES=(".env" ".env.local" '.env.${APP_ENV}')
```

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
xcind-config              # JSON output
xcind-config --preview    # Show the docker compose command line
xcind-config --files      # List resolved files
```

## Environment Variable Override

Set `XCIND_APP_ROOT` to bypass automatic root detection:

```bash
XCIND_APP_ROOT=/path/to/app xcind-compose up
```

## Tab Completion

Since `xcind-compose` passes everything through to `docker compose`, you can
reuse Docker Compose's completion. Add to your shell config:

```bash
# If using the Docker CLI's built-in completion:
complete -F _docker_compose xcind-compose 2>/dev/null
```

## Direnv Integration

Xcind works independently of direnv. If you use direnv, you can optionally
source `.xcind.sh` from your `.envrc` to get the config variables in your shell:

```bash
# .envrc
source_env .xcind.sh
```

## JetBrains Plugin

The `xcind-config` command outputs JSON compatible with the xcind JetBrains
plugin. Point the plugin at the `xcind-config` script path, and it will
resolve compose files and env files for your IDE's Docker integration.

## Installation

### npm (recommended)

```bash
# Global install
npm install -g @scinddev/xcind

# Or run directly with npx
npx -p @scinddev/xcind xcind-compose up -d
npx -p @scinddev/xcind xcind-config --preview
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

## License

MIT — see [LICENSE](LICENSE) for details.

## File Structure

```
xcind/
├── bin/
│   ├── xcind-compose          # Main executable — wraps docker compose
│   └── xcind-config           # Config dump — JSON, preview, file listing
├── lib/xcind/
│   └── xcind-lib.bash         # Shared library (sourced by other scripts)
├── test/
│   └── test-xcind.sh          # Test suite
├── examples/
│   ├── workspaceless/
│   │   ├── acmeapps/          # Simple example (nginx, env files)
│   │   └── advanced/          # Variable expansion, multi-compose, traefik
│   └── workspaces/
│       └── dev/               # Workspace with frontend + backend apps
├── contrib/
│   ├── release                # Release helper script
│   └── test-all               # Full test runner (Docker + unit)
├── docs/
│   └── releasing.md           # Release process documentation
├── compose.yaml               # Default Docker Compose configuration
├── compose.override.dist      # Compose override template
├── Dockerfile                 # Container image build
├── flake.nix                  # Nix flake (package + overlay)
├── flake.lock                 # Nix flake lock file
├── install.sh                 # Install to a PREFIX
├── uninstall.sh               # Remove from a PREFIX
├── package.json               # npm package manifest
├── LICENSE                    # MIT license
└── README.md
```
