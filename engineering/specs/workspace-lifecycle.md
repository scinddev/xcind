# Workspace Lifecycle

> Rewritten from the [Scind specification](https://github.com/scinddev/scind). Xcind provides `xcind-workspace init`, `up`, `down`, `restart`, `status`, `list`, `register`, `forget`, and `dispose` commands for workspace management. A workspace exists when a directory contains a `.xcind.sh` file with `XCIND_IS_WORKSPACE=1`.

---

## Overview

Xcind workspaces are lightweight — initialization creates a `.xcind.sh` file, and there is no separate state management or destruction. A workspace exists when a directory contains a `.xcind.sh` file with `XCIND_IS_WORKSPACE=1`.

## Lifecycle

### Creating a Workspace

Use `xcind-workspace init` or create the configuration manually:

```bash
# Using the init command
xcind-workspace init ~/dev
xcind-workspace init --name myworkspace --proxy-domain xcind.localhost

# Or manually
mkdir dev
cat > dev/.xcind.sh <<'EOF'
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
EOF
```

See the [CLI Reference](../reference/cli.md#xcind-workspace) for the full options of every subcommand.

### Managing the Workspace Registry

Workspaces are tracked in a registry (`workspaces.tsv`, see [State](#state)) so
they can be listed without scanning the filesystem. The registry is populated
automatically on `init` and on every runtime discovery, and can be managed
directly:

```bash
xcind-workspace list                 # List all registered workspaces
xcind-workspace list --json          # Structured JSON
xcind-workspace list --prune         # Drop stale entries (paths no longer workspaces) before listing
xcind-workspace register ~/code/acme # Add an existing workspace to the registry
xcind-workspace forget ~/code/old    # Remove a registry entry (directory need not exist)
```

### Running Applications

From any directory inside an application:

```bash
cd dev/frontend
xcind-compose up -d
```

Xcind automatically:
1. Detects the app root (`dev/frontend/.xcind.sh`)
2. Discovers the workspace (`dev/.xcind.sh` with `XCIND_IS_WORKSPACE=1`)
3. Sources workspace config first, then app config
4. Runs hooks (naming, proxy, workspace networking)
5. Executes `docker compose` with all resolved flags

### Stopping Applications

```bash
xcind-compose down
```

### Running the Whole Workspace

`xcind-workspace up` and `xcind-workspace down` run the per-app commands above
across every application directory in the workspace — enumerate the app dirs,
invoke `xcind-compose up -d` (or `down`) in each, continue past failures, and
report the failed applications at the end:

```bash
xcind-workspace up            # xcind-compose up -d in each app dir
xcind-workspace down --yes    # xcind-compose down in each; --yes skips the prompt
```

`down` confirms before acting because it is workspace-wide.

`xcind-workspace restart` composes the same loop twice: a full `down` pass
across every application directory, then a full `up` pass across every
application directory — matching the canon definition of `restart` as `down`
followed by `up`, with volumes always preserved (`restart` never passes
`-v`/`--volumes`):

```bash
xcind-workspace restart --yes    # down every app, then up every app; --yes skips the prompt
```

`restart` confirms before acting too, since it starts with a workspace-wide
down. Each pass continues past a failing application on its own, and the up
pass still runs even if one or more applications failed to come down — the
second pass is not made conditional on the first, matching the existing
continue-past-failure behavior within a pass. Failures from both passes are
reported together, and the command exits non-zero if either pass had one.

All three verbs accept `-a NAME`/`--app NAME` (repeatable) to limit the pass
loop to specific application directories instead of enumerating every one.
`NAME` matches an application directory's basename within the workspace root
that was already located (via walk-up or an explicit `[DIR]`). An
unrecognized name errors out before anything runs, naming the unknown app and
listing the available ones; the confirmation prompt lists only the selected
applications:

```bash
xcind-workspace down -a api -a worker --yes    # down only "api" and "worker"
```

This is strictly a filter on the per-app loop already inside the located
workspace — it does not add name-based workspace discovery. Xcind targets a
workspace by location only (cwd walk-up or a positional `[DIR]`); see ADR
[0023](../decisions/0023-location-based-targeting.md) and divergence
[0021](../sync/divergence/0021-options-based-targeting-by-name.md) for why
`-w`/`--workspace` name resolution "from anywhere" is deliberately out of
scope.

`down` also accepts `--volumes`, which forwards `-v` to each application's
`xcind-compose down` call, removing that application's Docker volumes. The
confirmation prompt states plainly that volumes will also be removed when
`--volumes` is given (`--yes` still skips the prompt). `up` and `restart`
reject `--volumes` — `restart`'s internal down pass always preserves volumes,
so accepting the flag there would be misleading:

```bash
xcind-workspace down --volumes    # down every app, also remove each app's volumes
```

### Removing a Workspace

`xcind-workspace dispose` tears down every application (compose down, release
assigned ports, remove generated `.xcind/` state), removes the workspace
network and registry entry, and with `--rm` removes the directory itself:

```bash
xcind-workspace dispose dev/ --rm --volumes --yes
```

Manual removal also works — beyond Docker containers, the workspace network,
and the registry entry, there is no state to clean up:

```bash
# Stop all containers first
cd dev/frontend && xcind-compose down
cd dev/backend && xcind-compose down

# Remove workspace network (created by workspace hook).
# In a git worktree with a non-empty XCIND_INSTANCE the network is named
# dev-{instance}-internal; see Naming Conventions.
docker network rm dev-internal 2>/dev/null || true

# Remove the workspace directory (drop its registry entry with
# `xcind-workspace forget dev/`)
rm -rf dev/
```

---

## State

Xcind maintains two narrowly-scoped state files under
`${XDG_STATE_HOME:-$HOME/.local/state}/xcind/`:

| File | Purpose |
|------|---------|
| `proxy/assigned-ports.tsv` | Sticky host-port assignments for `type=assigned` exports. |
| `workspaces.tsv` | Discovery registry populated by `xcind-workspace init` and on every runtime workspace discovery. Consumed by `xcind-workspace list / register / forget`. |

Everything else is runtime state, read from Docker or the filesystem on demand rather than tracked:

| Aspect | Source |
|--------|--------|
| Is the app running? | Docker container status |
| Which compose files? | `.xcind.sh` configuration, resolved at runtime |
| Which hooks ran? | SHA-based cache in `.xcind/generated/` |
| Is the workspace network present? | Docker network inspection |

---

## Workspace Mode Detection

Workspace mode activates through two mechanisms:

### Automatic Detection

When the app root's parent directory contains `.xcind.sh` with `XCIND_IS_WORKSPACE=1`:

```
dev/                    ← workspace root (.xcind.sh with XCIND_IS_WORKSPACE=1)
├── frontend/           ← app root (.xcind.sh)
└── backend/            ← app root (.xcind.sh)
```

### Self-Declaration

An app can declare itself part of a workspace by setting `XCIND_WORKSPACE` in its own `.xcind.sh`:

```bash
# frontend/.xcind.sh
XCIND_WORKSPACE="myworkspace"
XCIND_PROXY_EXPORTS=("web:3000")
```

---

## Workspace Variables

Set automatically when workspace mode is active:

| Variable | Value | Example |
|----------|-------|---------|
| `XCIND_WORKSPACE` | Basename of workspace directory | `dev` |
| `XCIND_WORKSPACE_ROOT` | Absolute path to workspace directory | `/Users/beau/dev` |
| `XCIND_WORKSPACELESS` | `0` (in workspace), `1` (standalone) | `0` |

---

## Related Documents

- [Context Detection](./context-detection.md) — How xcind finds workspaces
- [Directory Structure](./directory-structure.md) — Workspace file layout
- [Architecture Overview](../architecture/overview.md) — Network topology
- [Configuration Reference](../reference/configuration.md) — `XCIND_IS_WORKSPACE` and workspace variables
