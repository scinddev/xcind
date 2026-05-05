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
├── lib/                       # Shared test infrastructure (sourced by suites)
│   ├── assert.sh              # assert_eq / assert_contains / assert_not_contains
│   └── setup.sh               # mktemp_d, reset_xcind_state, EXIT-trap cleanup
├── test-xcind.sh              # Core test suite
└── test-xcind-proxy.sh        # Proxy test suite

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

Xcind uses a hook lifecycle with two implemented phases. See [Hook Lifecycle](../specs/hook-lifecycle.md) for the full specification.

**GENERATE hooks** (`XCIND_HOOKS_GENERATE`) produce compose overlay files. They are cached by SHA and only re-run when inputs change:

1. Each hook function is called with the resolved configuration available as environment variables
2. The hook generates a compose overlay file (e.g., `compose.proxy.yaml`) in `$XCIND_GENERATED_DIR`
3. The hook prints `-f <path>` to stdout, which is appended to the Docker Compose command

**EXECUTE hooks** (`XCIND_HOOKS_EXECUTE`) ensure runtime preconditions before `docker compose` runs. They are never cached and run on every invocation.

Built-in hooks:
- `xcind-naming-hook` (GENERATE, from `xcind-naming-lib.bash`) --- sets Docker Compose project name
- `xcind-app-env-hook` (GENERATE, from `xcind-app-env-lib.bash`) --- injects app-level env files
- `xcind-proxy-hook` (GENERATE, from `xcind-proxy-lib.bash`) --- generates Traefik routing labels
- `xcind-workspace-hook` (GENERATE, from `xcind-workspace-lib.bash`) --- generates network aliases
- `__xcind-proxy-execute-hook` (EXECUTE, from `xcind-proxy-lib.bash`) --- ensures proxy is running
- `__xcind-workspace-execute-hook` (EXECUTE, from `xcind-workspace-lib.bash`) --- ensures workspace network exists

### How to add a new hook

1. Create a library file `lib/xcind/xcind-{name}-lib.bash`
2. Define the hook function (e.g., `xcind-{name}-hook` for GENERATE, `__xcind-{name}-execute-hook` for EXECUTE)
3. Register it in the appropriate array in `xcind-lib.bash` (`XCIND_HOOKS_GENERATE` or `XCIND_HOOKS_EXECUTE`)
4. Run the `add-installed-file` skill to register the new lib file in all manifests
5. Add tests in `test/test-xcind.sh` or `test/test-xcind-proxy.sh`

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
