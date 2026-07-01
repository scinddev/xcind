# Project Layout

Directory structure and file responsibilities for Xcind.

## Top-Level Areas

| Path | Responsibility |
|------|----------------|
| `bin/` | User-facing Bash entrypoints installed on `PATH`. Each script resolves `XCIND_ROOT`, sources `lib/xcind/xcind-bootstrap.bash`, and then handles CLI parsing or Docker Compose dispatch. |
| `lib/xcind/` | Shared Bash runtime, hook implementations, shell completions, registry/state helpers, and lifecycle helpers sourced by the entrypoints. |
| `test/` | Shell test suites and shared assertion/setup helpers. |
| `contrib/` | Development and release helpers, including manifest validation, release automation, and the full Docker-aware test runner. |
| `examples/` | Working workspaceless and workspace examples used for manual verification and documentation alignment. |
| `engineering/` | Product, architecture, specification, implementation, reference, and maintenance documentation. |

## Entrypoints

| File | Responsibility |
|------|----------------|
| `bin/xcind-compose` | Main Docker Compose wrapper. Resolves app config, runs generate/execute hooks, then delegates to `docker compose`. |
| `bin/xcind-config` | Resolved configuration interface. Provides help, version, dependency checks, doctor output, JSON, previews, generated wrappers/configuration, and shell completion output. |
| `bin/xcind-proxy` | Shared Traefik proxy management. Handles proxy init, up/down/status/logs, config display, port release, and pruning. |
| `bin/xcind-workspace` | Workspace management. Handles workspace init/status/list/register/forget and maintains the workspace registry. |
| `bin/xcind-application` | Application management. Handles application init/status/list within workspaces. |

## Shared Libraries

| File | Responsibility |
|------|----------------|
| `lib/xcind/xcind-bootstrap.bash` | Common startup shim sourced by every bin entrypoint after `XCIND_ROOT` is resolved. It validates `XCIND_ROOT` is set and then sources `xcind-lib.bash`, giving the caller the full Xcind shell environment in one step. Centralized so future shared setup (hook discovery, env defaults) can be added without touching each bin stub. |
| `lib/xcind/xcind-lib.bash` | Core runtime: version/build metadata, app root detection, workspace/app/additional config loading, dependency checks, compose/env file resolution, generation SHA computation, generated-cache population (with `.complete` marker + per-hook completeness gate), `XCIND_HOOKS_GENERATE` / `XCIND_HOOKS_ALWAYS` / `XCIND_HOOKS_EXECUTE` registration and execution, and app preparation (`__xcind-prepare-app`). Sources every other `xcind-*-lib.bash` file in this directory so the registered hook set is available to all entrypoints. |
| `lib/xcind/xcind-app-lib.bash` | `xcind-app-hook` (GENERATE) — adds app identity labels so xcind-managed containers remain discoverable. |
| `lib/xcind/xcind-app-env-lib.bash` | `xcind-app-env-hook` (GENERATE) — injects app-level env files (`XCIND_APP_ENV_FILES`) into Compose services. |
| `lib/xcind/xcind-assigned-lib.bash` | `xcind-assigned-hook` (GENERATE + `XCIND_HOOKS_ALWAYS`) and helpers for stable assigned host ports, `compose.assigned.yaml`, and the `proxy/assigned-ports.tsv` registry under `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/`. Re-runs on every cache hit to keep allocations consistent with live state. |
| `lib/xcind/xcind-host-gateway-lib.bash` | `xcind-host-gateway-hook` (GENERATE) — normalizes `host.docker.internal` access across Docker Desktop, Linux, and WSL modes; the runtime-detected gateway value is also folded into the cache SHA when host-gateway support is enabled. |
| `lib/xcind/xcind-hostenv-lib.bash` | `__xcind-hostenv-execute-hook` (EXECUTE) — writes the opt-in host-view env file (`XCIND_HOST_ENV_FILE`) with discovery variables resolved for host-run processes. |
| `lib/xcind/xcind-naming-lib.bash` | `xcind-naming-hook` (GENERATE) — sets the Docker Compose project name and handles workspace/workspaceless collision avoidance. |
| `lib/xcind/xcind-proxy-lib.bash` | `xcind-proxy-hook` (GENERATE) and `__xcind-proxy-execute-hook` (EXECUTE) plus the shared proxy lifecycle, configuration, and state helpers used by `bin/xcind-proxy`. |
| `lib/xcind/xcind-registry-lib.bash` | Workspace registry persistence and locking helpers backing the `workspaces.tsv` state file under `${XDG_STATE_HOME:-$HOME/.local/state}/xcind/`. Used by `bin/xcind-workspace` and the workspace lookup paths in `xcind-lib.bash`. |
| `lib/xcind/xcind-workspace-lib.bash` | `xcind-workspace-hook` (GENERATE) and `__xcind-workspace-execute-hook` (EXECUTE) plus shared helpers that create and join the per-workspace Docker network and emit network aliases. |
| `lib/xcind/xcind-completion-bash.bash` | Bash completion implementation emitted by `xcind-config completion bash`. |
| `lib/xcind/xcind-completion-zsh.bash` | Zsh completion implementation emitted by `xcind-config completion zsh`. |

## Tests, Helpers, and Examples

| Path | Responsibility |
|------|----------------|
| `test/lib/assert.sh` | Shared shell assertions. |
| `test/lib/setup.sh` | Shared test setup, temp directory helpers, state reset, and cleanup traps. |
| `test/test-xcind.sh` | Core, config, workspace, application, hook, and resolution coverage. |
| `test/test-xcind-proxy.sh` | Proxy CLI, state, config, and lifecycle coverage. |
| `contrib/check-file-manifest` | Validates file registrations across install and packaging manifests. |
| `contrib/release` | Release/version bumping helper. |
| `contrib/test-all` | Full test runner for Docker-backed and unit validation. |
| `examples/workspaceless/` | Non-workspace examples covering simple and advanced Compose layouts. |
| `examples/workspaces/dev/` | Workspace example with frontend and backend applications. |

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
- `xcind-app-hook` (GENERATE, from `xcind-app-lib.bash`) --- adds app identity labels
- `xcind-app-env-hook` (GENERATE, from `xcind-app-env-lib.bash`) --- injects app-level env files
- `xcind-host-gateway-hook` (GENERATE, from `xcind-host-gateway-lib.bash`) --- normalizes `host.docker.internal`
- `xcind-proxy-hook` (GENERATE, from `xcind-proxy-lib.bash`) --- generates Traefik routing labels
- `xcind-assigned-hook` (GENERATE, from `xcind-assigned-lib.bash`) --- reserves and emits assigned host ports
- `xcind-workspace-hook` (GENERATE, from `xcind-workspace-lib.bash`) --- generates network aliases
- `__xcind-proxy-execute-hook` (EXECUTE, from `xcind-proxy-lib.bash`) --- ensures proxy is running
- `__xcind-workspace-execute-hook` (EXECUTE, from `xcind-workspace-lib.bash`) --- ensures workspace network exists
- `__xcind-hostenv-execute-hook` (EXECUTE, from `xcind-hostenv-lib.bash`) --- writes the opt-in host-view env file

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
