# Application Lifecycle

> Xcind provides `xcind-application init`, `status`, and `list`
> subcommands (aliased as `xcind-app`). An application exists when a
> directory contains a `.xcind.sh` file that does **not** set
> `XCIND_IS_WORKSPACE=1`.

---

## Overview

Xcind applications are lightweight — initialization creates a `.xcind.sh`
file, and there is no separate state store, no manifest, and no removal
command. An application exists when a directory contains a `.xcind.sh`
file without the workspace marker. The runtime pipeline
(`xcind-compose`, `xcind-config`) discovers applications by walking
upward from `$PWD`, so moving, copying, or deleting an application is as
simple as moving, copying, or deleting its directory.

## Lifecycle

### Creating an Application

Use `xcind-application init` or create the configuration manually:

```bash
# Using the init command
xcind-application init ~/dev/webapp
xcind-application init ./api --name my-api

# Or manually
mkdir webapp
cat > webapp/.xcind.sh <<'EOF'
XCIND_COMPOSE_FILES=("compose.yaml")
EOF
```

See the [CLI Reference](../reference/cli.md#xcind-application) for full
`init`, `status`, and `list` options.

### Running the Application

From any directory inside the application:

```bash
cd webapp
xcind-compose up -d
```

Xcind automatically:
1. Detects the app root (`webapp/.xcind.sh`)
2. Discovers the enclosing workspace, if any (`webapp/../.xcind.sh` with `XCIND_IS_WORKSPACE=1`)
3. Sources workspace config first, then app config
4. Runs hooks (naming, app labels, proxy, workspace networking)
5. Executes `docker compose` with all resolved flags

### Inspecting the Application

```bash
xcind-application status             # Text report for the app at $PWD
xcind-application status --json      # Structured JSON
xcind-application list               # Sibling apps in the enclosing workspace
```

### Stopping the Application

```bash
xcind-compose down
```

### Removing an Application

Remove the directory. There is no state to clean up beyond Docker
containers, networks, and assigned-port entries:

```bash
cd webapp && xcind-compose down
cd .. && rm -rf webapp
```

Assigned-port entries referencing the deleted application are cleaned
up by `xcind-proxy prune`.

---

## State

Applications themselves have no persistent state outside the
application directory. The two state files under
`${XDG_STATE_HOME:-$HOME/.local/state}/xcind/` —
`proxy/assigned-ports.tsv` and `workspaces.tsv` — are workspace and
proxy concerns; see [Workspace Lifecycle](./workspace-lifecycle.md) for
details.

Unlike workspaces, xcind intentionally does **not** maintain an
application registry. This matches the Scind spec: applications are
derived from their enclosing workspace's directory contents, not
tracked in a separate persistent list. `xcind-application list`
therefore iterates over the workspace filesystem at call time rather
than reading from a registry file.

---

## Relationship to Workspaces

An application can run in three arrangements:

### Standalone (workspaceless)

The application's `.xcind.sh` does not set `XCIND_WORKSPACE` and its
parent directory is not a workspace root. `XCIND_WORKSPACELESS=1` at
runtime. This is the default shape for `xcind-application init`
invoked outside any workspace.

```
webapp/
└── .xcind.sh        ← app config (no XCIND_WORKSPACE)
```

### Inside a workspace (automatic detection)

The application's parent directory contains a `.xcind.sh` with
`XCIND_IS_WORKSPACE=1`. Workspace config is sourced before the app's,
and the workspace's network and proxy settings apply automatically.

```
dev/                    ← workspace root (.xcind.sh with XCIND_IS_WORKSPACE=1)
├── webapp/             ← app root (.xcind.sh)
└── api/                ← app root (.xcind.sh)
```

### Self-declared workspace membership

The application's `.xcind.sh` sets `XCIND_WORKSPACE="name"` even though
its parent is not a workspace root. `__xcind-late-bind-workspace` flips
the runtime to workspace mode so the app participates in that
workspace's network and proxy routing.

---

## Application Variables

Set automatically during `xcind-compose` / `xcind-config` resolution:

| Variable | Value | Example |
|----------|-------|---------|
| `XCIND_APP` | Basename of app directory, or the value set in `.xcind.sh` | `webapp` |
| `XCIND_APP_ROOT` | Absolute path to the app directory | `/Users/beau/dev/webapp` |

Subcommand-set variables (when running inside a workspace):

| Variable | Value | Example |
|----------|-------|---------|
| `XCIND_WORKSPACE` | Basename of workspace directory | `dev` |
| `XCIND_WORKSPACE_ROOT` | Absolute path to workspace directory | `/Users/beau/dev` |
| `XCIND_WORKSPACELESS` | `0` (in workspace), `1` (standalone) | `0` |

---

## Related Documents

- [Workspace Lifecycle](./workspace-lifecycle.md) — Workspace-scope lifecycle and state
- [Context Detection](./context-detection.md) — How xcind finds workspaces and applications
- [Directory Structure](./directory-structure.md) — Expected filesystem layout
- [Configuration Reference](../reference/configuration.md) — All `XCIND_*` variables
