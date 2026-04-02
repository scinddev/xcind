# Xcind: Product Vision

Xcind is a slim shell wrapper around `docker compose` that automatically resolves compose files, environment files, and override variants based on a per-application configuration file (`.xcind.sh`). It implements concepts from the [Scind specification](https://github.com/scinddev/scind) using pure Bash (3.2+).

---

## Problem Statement

### The Scenario

A developer works on a system composed of multiple applications (e.g., `frontend`, `backend`, `shared-db`) that communicate with each other. They need:

- Automatic compose file resolution without manual `-f` flag management
- Override variants for environment-specific configuration
- Optional workspace grouping to run multiple isolated copies of a stack simultaneously
- Hostname-based routing to services via a shared reverse proxy

### Why Existing Solutions Fall Short

| Solution | Limitation |
|----------|------------|
| Docker Compose alone | No automatic file resolution; manual project naming for multi-instance |
| Docker Compose `include` | Merges into single application model; doesn't handle parallel instances |
| DDEV / Lando / Docksal | Single-application focused; opinionated about project structure |
| Skaffold / Tilt / Garden | Kubernetes-focused, not Docker Compose |
| Manual scripts | Error-prone, hard to maintain, no conventions |

### The Gap

There is no existing tool that provides **automatic compose file resolution** with **override variants**, **workspace grouping**, and **hostname-based proxy routing** while keeping **applications workspace-agnostic** and requiring **zero changes to existing Docker Compose files**.

---

## Product Vision

Xcind provides a thin coordination layer over Docker Compose that:

1. **Preserves application independence**: Applications don't know they're managed by Xcind
2. **Uses pure overlay**: All integration happens via generated Docker Compose override files
3. **Follows conventions**: Predictable naming for hostnames, aliases, and networks
4. **Separates structure from state**: `.xcind.sh` describes what exists; runtime state is in Docker
5. **Enables direct Docker Compose access**: `xcind-compose` provides transparent passthrough to Docker Compose with full tab completion

---

## Target Audience

- **Developers with Docker Compose projects**: Teams already using Docker Compose who want automatic file resolution and override support
- **Teams with multi-application stacks**: Systems composed of multiple cooperating services that need workspace isolation
- **Projects needing local hostname routing**: Applications that benefit from hostname-based access via Traefik

---

## Core Concepts

### Application

A Docker Compose-based project with a `.xcind.sh` configuration file. The `.xcind.sh` declares compose files, environment files, and proxy exports. An empty `.xcind.sh` is valid — Xcind uses sensible defaults.

### Workspace

A parent directory containing its own `.xcind.sh` with `XCIND_IS_WORKSPACE=1`. Applications inside the workspace share an internal network for communication while remaining isolated from other workspaces.

```
workspace: dev
├── frontend (project: dev-frontend)
├── backend (project: dev-backend)
└── shared-db (project: dev-shared-db)
    └── all connected via: dev-internal network
```

*See [ADR-0001: Docker Compose Project Name Isolation](../decisions/0001-docker-compose-project-name-isolation.md).*

### Proxy Exports

Services declared in `XCIND_PROXY_EXPORTS` are routed through a shared Traefik reverse proxy by hostname. The first entry is implicitly primary and receives an apex hostname (e.g., `dev-frontend.xcind.localhost` in addition to `dev-frontend-web.xcind.localhost`).

```bash
XCIND_PROXY_EXPORTS=(
    "web=nginx:8080"    # export "web" from service "nginx" on port 8080
    "api=app:3000"      # export "api" from service "app" on port 3000
)
```

*See [ADR-0007: Port Type System](../decisions/0007-port-type-system.md).*

### Override Resolution

For each configured file, Xcind checks for an `.override` variant. This enables environment-specific or developer-specific overrides without modifying shared files.

*See [ADR-0003: Pure Overlay Design](../decisions/0003-pure-overlay-design.md).*

### Hooks

The pipeline exposes hook phases for extending behavior. GENERATE hooks produce compose overlay files (cached by SHA); EXECUTE hooks ensure runtime preconditions before `docker compose` runs. Built-in hooks handle naming, app env files, proxy labels, and workspace networking. Custom hooks can be added via `XCIND_HOOKS_GENERATE` and `XCIND_HOOKS_EXECUTE`. See [Hook Lifecycle](../specs/hook-lifecycle.md).

---

## Non-Goals

1. **Kubernetes support**: Xcind is specifically for Docker Compose environments
2. **Production deployment**: Focused on local development and testing
3. **Image building**: Uses existing images; doesn't manage builds
4. **Secret management**: Uses Docker Compose's existing mechanisms
5. **Windows native support**: Targets macOS and Linux; Windows users should use WSL2

---

## Success Criteria

1. **Zero application changes**: Existing Docker Compose applications work without modification
2. **Parallel environments**: Can run dev, review, and control simultaneously without conflicts
3. **Predictable naming**: Given workspace and app names, hostnames and aliases are deterministic
4. **Fast iteration**: File resolution and hook generation complete in milliseconds
5. **Debuggable**: Generated files are human-readable; `xcind-config --preview` shows exactly what runs
