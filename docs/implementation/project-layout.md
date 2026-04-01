# Project Layout

Directory structure and file responsibilities for Xcind.

## Directory Structure

```
bin/                           # Executable scripts
├── xcind-compose              # Main wrapper — resolves config, passes through to docker compose
├── xcind-config               # Config dump — JSON, preview, file listing
└── xcind-proxy                # Manages shared Traefik proxy infrastructure

lib/xcind/                     # Shared libraries (sourced by executables)
├── xcind-lib.bash             # Core: app root detection, config loading, file resolution, hooks
├── xcind-app-env-lib.bash     # App-level env injection hook
├── xcind-proxy-lib.bash       # Proxy hook: generates compose.proxy.yaml with Traefik labels
├── xcind-workspace-lib.bash   # Workspace hook: generates compose.workspace.yaml with network aliases
└── xcind-naming-lib.bash      # Naming hook: auto-sets Docker Compose project name

test/                          # Test suites
├── test-xcind.sh              # Core test suite (~1248 lines)
└── test-xcind-proxy.sh        # Proxy test suite (~666 lines)

contrib/                       # Development and release helpers
├── check-file-manifest        # Validates file registrations across manifests
├── release                    # Version bumping script
└── test-all                   # Full test runner (Docker + unit)

examples/                      # Working examples
├── workspaceless/             # Non-workspace examples
│   ├── acmeapps/              # Simple (nginx, env files)
│   └── advanced/              # Variable expansion, multi-compose, traefik
└── workspaces/
    └── dev/                   # Workspace with frontend + backend
```

## Key Patterns

### How hooks work

Xcind uses a hook system to generate compose overlay files. Hooks are Bash functions registered in the `XCIND_HOOKS_POST_RESOLVE_GENERATE` array. During config resolution:

1. Each hook function is called with the resolved configuration available as environment variables
2. The hook generates a compose overlay file (e.g., `compose.proxy.yaml`) in `$XCIND_GENERATED_DIR`
3. The hook prints `-f <path>` to stdout, which is appended to the Docker Compose command
4. Hook output is cached by SHA --- hooks only re-run when inputs change

Built-in hooks:
- `xcind-proxy-hook` (from `xcind-proxy-lib.bash`) --- generates Traefik routing labels
- `xcind-workspace-hook` (from `xcind-workspace-lib.bash`) --- generates network aliases
- `xcind-naming-hook` (from `xcind-naming-lib.bash`) --- sets Docker Compose project name
- `xcind-app-env-hook` (from `xcind-app-env-lib.bash`) --- injects app-level env files

### How to add a new hook

1. Create a library file `lib/xcind/xcind-{name}-lib.bash`
2. Define the hook function (e.g., `xcind-{name}-hook`)
3. Register it by appending to `XCIND_HOOKS_POST_RESOLVE_GENERATE` in `xcind-lib.bash`
4. Run the `add-installed-file` skill to register the new lib file in all manifests
5. Add tests in `test/test-xcind.sh`

### How to add a new xcind-config flag

1. Edit `bin/xcind-config` to handle the new flag in the argument parser
2. Implement the output logic (typically reading from resolved config variables)
3. Add tests in `test/test-xcind.sh`

### How to add a new bin/ or lib/xcind/ file

Creating a new file under `bin/` or `lib/xcind/` triggers the `add-installed-file` skill, which registers the file in all installation and packaging manifests (npm package.json, Nix flake, Makefile, Dockerfile, etc.).

## Related Documents

- [Technology Stack](./tech-stack.md) --- Tools and dependencies
- [Architecture Overview](../architecture/overview.md) --- High-level component relationships
- [Configuration Schemas](../specs/configuration-schemas.md) --- How .xcind.sh configuration works
