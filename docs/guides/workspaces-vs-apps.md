# Workspaces vs single apps

Xcind has two modes:

- **App mode** (default) — one project, one `.xcind.sh`, no parent context.
- **Workspace mode** — multiple apps grouped under a parent directory, sharing a domain, hooks, and an internal network.

If you only have one project, you don't need workspaces. Skip this guide.

## When to use a workspace

Use a workspace when:

- You have several related apps (frontend / backend / worker) under one parent directory.
- You want them to reach each other by name on a shared internal network.
- You want consistent naming and a shared proxy domain across the group.

Symptoms that you want a workspace:

- You keep copy-pasting the same `XCIND_PROXY_DOMAIN` across each app.
- Containers from different apps collide on names (`app`, `db`, `redis`).
- You want the frontend to call `http://backend-app:3000` directly without leaving Docker.

## Set up a workspace

```
dev/                          # workspace root
├── .xcind.sh                 # XCIND_IS_WORKSPACE=1, hooks, proxy domain
├── frontend/
│   ├── .xcind.sh             # app-level config
│   └── compose.yaml
└── backend/
    ├── .xcind.sh
    └── compose.yaml
```

In `dev/.xcind.sh`:

```bash
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
```

That's it. Each app's `.xcind.sh` works as before — when Xcind discovers an app inside a workspace, it sources the workspace's `.xcind.sh` first to set group-level defaults, then the app's `.xcind.sh` for app-specific overrides.

## What changes in workspace mode

| Variable | Value |
|----------|-------|
| `XCIND_WORKSPACE` | basename of the workspace directory |
| `XCIND_WORKSPACE_ROOT` | absolute path to the workspace |
| `XCIND_WORKSPACELESS` | `0` |

Hostnames switch templates:

| Mode | Template | Example |
|------|----------|---------|
| App | `{app}-{export}.{domain}` | `myapp-api.localhost.scind.io` |
| Workspace | `{workspace}-{app}-{export}.{domain}` | `dev-backend-api.xcind.localhost` |

A `{workspace}-internal` Docker network is created automatically, with network aliases so services can reach each other by `{app}-{service}` (default template — see [Configuration reference](../reference/configuration.md) for `XCIND_WORKSPACE_SERVICE_TEMPLATE`).

## Self-declaration without a parent

An app can declare itself part of a workspace without a parent `.xcind.sh`:

```bash
# app/.xcind.sh
XCIND_WORKSPACE="myworkspace"
```

Useful when the workspace is conceptual rather than a physical directory.

## Git worktrees

A linked git worktree is a second checkout of the same repository. Run the same
app from a worktree and — without isolation — it would resolve to the same Xcind
identity as the main checkout: colliding compose project names and, in a
workspace, a shared internal network. You'd be unable to run both at once.

Xcind isolates each worktree automatically with an **instance** token
(`XCIND_INSTANCE`). On the main checkout the token is empty and every generated
name is byte-identical to before. Inside a linked worktree the token is derived
from the worktree's directory name (sanitized to lowercase `[a-z0-9-]`) and
folded into the project name and workspace network — never the app name and
never the in-network aliases, so intra-workspace service discovery
(`{app}-{service}`) stays stable across worktrees.

| Mode | Project name | Workspace network |
|------|--------------|-------------------|
| App / workspaceless | `{app}-{instance}` | (none) |
| Workspace | `{workspace}-{instance}-{app}` | `{workspace}-{instance}-internal` |

For example, `git worktree add ../myapp-perf` gives an app named
`myapp-perf` (or `dev-perf-myapp` in the `dev` workspace, on a
`dev-perf-internal` network), running alongside the main checkout without
collisions.

Two knobs override the default:

- `XCIND_INSTANCE=perf` — set the token explicitly (an explicit value always
  wins over auto-detection). Useful to pin a stable name regardless of the
  directory, or to isolate outside a worktree.
- `XCIND_INSTANCE_AUTO=0` — disable worktree auto-detection entirely; the token
  stays empty unless you set `XCIND_INSTANCE` yourself.

The token also joins the config cache key, so each instance caches its generated
compose files separately.

## Where to go next

- [Set up the Traefik proxy](./proxy-setup.md) — proxy domain interacts with workspace naming.
- [`engineering/specs/workspace-lifecycle.md`](../../engineering/specs/workspace-lifecycle.md) — full behavior spec.
