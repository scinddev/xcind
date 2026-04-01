# Workspace Lifecycle

> Rewritten from the [Scind specification](https://github.com/scinddev/scind). Xcind has no `workspace init/destroy` commands; the lifecycle is: create `.xcind.sh` → run `xcind-compose`.

---

## Overview

Xcind workspaces are lightweight — there is no explicit initialization, state management, or destruction. A workspace exists when a directory contains a `.xcind.sh` file with `XCIND_IS_WORKSPACE=1`.

## Lifecycle

### Creating a Workspace

1. Create a directory for the workspace
2. Add a `.xcind.sh` file with `XCIND_IS_WORKSPACE=1`
3. Optionally set `XCIND_PROXY_DOMAIN` and other workspace-level settings
4. Add application subdirectories, each with their own `.xcind.sh`

```bash
mkdir dev
cat > dev/.xcind.sh <<'EOF'
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
EOF
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

### Removing a Workspace

Simply remove the directory. There is no state to clean up beyond Docker containers and networks:

```bash
# Stop all containers first
cd dev/frontend && xcind-compose down
cd dev/backend && xcind-compose down

# Remove workspace network (created by workspace hook)
docker network rm dev-internal 2>/dev/null || true

# Remove the workspace directory
rm -rf dev/
```

---

## State

Xcind is stateless. There are no state files, registries, or manifests. Runtime state is determined by:

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
