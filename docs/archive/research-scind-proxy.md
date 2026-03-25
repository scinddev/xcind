# Research: Scind Proxy Architecture

**Purpose:** Self-contained distillation of all proxy-related information from the Scind specification. Xcind proxy development should reference this document rather than re-reading the Scind source material directly.

**Source material:** `fictional-dollop-main/docs/` — architecture, specs, decisions, and appendices.

---

## 1. Architecture Overview

Scind manages **workspaces** — logical groupings of Docker Compose-based applications that run together on a single host. A shared Traefik reverse proxy routes external requests to the appropriate workspace and service based on hostname.

Key principles:
- **Application independence**: Applications remain unaware of the workspace system. No special labels or workspace-specific configuration in the application's own `docker-compose.yaml`.
- **Pure overlay**: All workspace integration is achieved through generated Docker Compose override files.
- **External access**: A shared Traefik instance routes requests based on hostname.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              HOST                                       │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        PROXY LAYER                                │  │
│  │  ┌──────────┐                                                     │  │
│  │  │ Traefik  │◄─────── scind-proxy (external network)              │  │
│  │  └──────────┘              │                                      │  │
│  └────────────────────────────┼──────────────────────────────────────┘  │
│                               │                                         │
│  ┌────────────────────────────┼──────────────────────────────────────┐  │
│  │                            │         WORKSPACE: dev               │  │
│  │                            ▼                                      │  │
│  │            ┌─── dev-internal (workspace network) ───┐             │  │
│  │            │                                        │             │  │
│  │    ┌───────┴───────┐  ┌───────┴───────┐  ┌──────────┴────┐        │  │
│  │    │   frontend    │  │   backend     │  │   shared-db   │        │  │
│  │    │(dev-frontend) │  │ (dev-backend) │  │(dev-shared-db)│        │  │
│  │    │               │  │               │  │               │        │  │
│  │    │ ┌───┐ ┌───┐   │  │ ┌───┐ ┌───┐   │  │ ┌───┐ ┌───┐   │        │  │
│  │    │ │web│ │ db│   │  │ │web│ │api│   │  │ │web│ │wrk│   │        │  │
│  │    │ └───┘ └───┘   │  │ └───┘ └───┘   │  │ └───┘ └───┘   │        │  │
│  │    └───────────────┘  └───────────────┘  └───────────────┘        │  │
│  │                                                                   │  │
│  │    Aliases on dev-internal:                                       │  │
│  │      frontend-web, backend-web, backend-api, shared-db-db, ...    │  │
│  │                                                                   │  │
│  │    External hostnames (via Traefik):                              │  │
│  │      dev-frontend-web.scind.test, dev-backend-api.scind.test      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        WORKSPACE: review                          │  │
│  │                            ...                                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

Traffic flow: `[External Request] → [Traefik:443/80] → [scind-proxy network] → [Service Container]`

---

## 2. Two-Layer Networking (ADR-0002)

Scind uses two overlay networks on top of Docker Compose's default per-application networks:

| Network | Name | Scope | Purpose | Created By |
|---------|------|-------|---------|------------|
| Proxy | `scind-proxy` | Host-level, shared across all workspaces | Connects Traefik to services that need external access | `scind proxy init` (once per host) |
| Workspace internal | `{workspace}-internal` | Per-workspace | Enables inter-application communication via stable aliases | `workspace up` (lazy, idempotent) |
| Application default | Managed by Docker Compose | Per-application | Internal communication between services within a single app | Docker Compose (automatic) |

**Rationale:** Separating proxy and internal networks allows public services to be routable via Traefik while protected services remain internal. The workspace-internal network provides isolation between workspaces.

---

## 3. Why Traefik (ADR-0008)

Traefik was chosen for its native Docker provider — it reads labels from containers and updates routing dynamically without config file changes. Labels on containers (added via generated overrides) define routing rules.

**Key capabilities used:**
- Docker provider with `exposedByDefault: false` — only explicitly labeled services are routed
- Network-scoped provider (`network: scind-proxy`) — Traefik only sees containers on the proxy network
- Label-based routing — no Traefik config changes needed when services come and go
- File provider — for dynamic TLS configuration

---

## 4. Port Type System (ADR-0007)

Services expose ports via two mechanisms:

| Type | Protocol | Behavior | Traefik? | Env Vars |
|------|----------|----------|----------|----------|
| `proxied` | `https` | HTTPS proxy via Traefik, TLS termination at proxy | Yes (HTTPS router on `:443`) | `*_HOST`, `*_PORT` (443), `*_SCHEME`, `*_URL` |
| `proxied` | `http` | HTTP proxy via Traefik | Yes (HTTP router on `:80`) | `*_HOST`, `*_PORT` (80), `*_SCHEME`, `*_URL` |
| `proxied` | `tcp`, etc. | SNI-based TCP proxy (future) | Yes (TCP router) | `*_HOST`, `*_PORT` |
| `assigned` | — | Direct host port binding, auto-assigned if unavailable | No | `*_HOST` (alias), `*_PORT` (host port) |

**Constraints per exported service:**
- At most one `http` proxied port
- At most one `https` proxied port
- Multiple `assigned` ports allowed

**Port inference:** If the Compose service has exactly one port in its `ports:` configuration, that port is used as the default container port. Multiple ports require explicit `port:` specification.

---

## 5. Docker Label System

All labels use the `scind.` namespace prefix.

### 5.1 Context Labels

Applied to all application containers for workspace discovery:

| Label | Description | Example |
|-------|-------------|---------|
| `scind.workspace.name` | Workspace identifier | `dev` |
| `scind.workspace.path` | Absolute path to workspace directory | `/Users/beau/workspaces/dev` |
| `scind.app.name` | Application identifier | `frontend` |
| `scind.app.path` | Absolute path to application directory | `/Users/beau/workspaces/dev/frontend` |

### 5.2 Export Labels

Applied to containers with exported services, keyed by export name:

**Proxied exports:**
```
scind.export.{name}.host={hostname}
scind.export.{name}.proxy.http.visibility={public|protected}
scind.export.{name}.proxy.http.url={url}
scind.export.{name}.proxy.https.visibility={public|protected}
scind.export.{name}.proxy.https.url={url}
```

**Assigned port exports:**
```
scind.export.{name}.host={hostname}
scind.export.{name}.port.{internal-port}.visibility={public|protected}
scind.export.{name}.port.{internal-port}.assigned={external-port}
```

### 5.3 Proxy Container Labels

Applied to the Scind-managed Traefik container:

| Label | Value | Purpose |
|-------|-------|---------|
| `scind.managed` | `true` | Marks container as Scind-managed |
| `scind.component` | `proxy` | Identifies component type |

### 5.4 Traefik Routing Labels

Generated automatically on service containers:

| Label | Description | Example |
|-------|-------------|---------|
| `traefik.enable` | Exposes container to Traefik | `true` |
| `traefik.http.routers.{name}.rule` | Host matcher | `Host(\`dev-frontend-web.scind.test\`)` |
| `traefik.http.routers.{name}.entrypoints` | Entry point | `websecure` |
| `traefik.http.routers.{name}.tls` | Enable TLS | `true` |
| `traefik.http.services.{name}.loadbalancer.server.port` | Container port | `8080` |

**Router naming convention:** `{workspace}-{application}-{exported_service}-{protocol}` (e.g., `dev-frontend-web-https`)

### 5.5 Complete Label Example

```yaml
labels:
  # Context
  - "scind.workspace.name=dev"
  - "scind.workspace.path=/Users/beau/workspaces/dev"
  - "scind.app.name=frontend"
  - "scind.app.path=/Users/beau/workspaces/dev/frontend"
  # Proxied export: web
  - "scind.export.web.host=dev-frontend-web.scind.test"
  - "scind.export.web.proxy.http.visibility=public"
  - "scind.export.web.proxy.http.url=http://dev-frontend-web.scind.test"
  - "scind.export.web.proxy.https.visibility=public"
  - "scind.export.web.proxy.https.url=https://dev-frontend-web.scind.test"
  # Assigned port export: debug
  - "scind.export.debug.host=frontend-debug"
  - "scind.export.debug.port.9000.visibility=protected"
  - "scind.export.debug.port.9000.assigned=9003"
```

---

## 6. Proxy Infrastructure

### 6.1 Directory Structure

Created by `scind proxy init`:

```
~/.config/scind/proxy/
├── docker-compose.yaml   # Traefik service definition
├── traefik.yaml          # Traefik static configuration
├── dynamic/              # Dynamic configuration (auto-discovered)
│   └── tls.yaml          # TLS certificate configuration (generated)
└── certs/                # TLS certificates (copied or generated here)
```

### 6.2 Traefik Compose File

```yaml
name: scind-proxy

services:
  traefik:
    image: ${TRAEFIK_IMAGE:-traefik:v3.2.3}
    command:
      - "--configFile=/etc/traefik/traefik.yaml"
      - "--api.dashboard=true"
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yaml:/etc/traefik/traefik.yaml:ro
      - ./dynamic:/etc/traefik/dynamic:ro
      - ./certs:/etc/traefik/certs:ro
    networks:
      - scind-proxy
    restart: unless-stopped
    labels:
      - "scind.managed=true"
      - "scind.component=proxy"

networks:
  scind-proxy:
    external: true
```

### 6.3 Traefik Static Configuration

```yaml
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
    network: scind-proxy
    watch: true
  file:
    directory: /etc/traefik/dynamic
    watch: true

log:
  level: INFO

accessLog: {}
```

### 6.4 Entry Points

| Entrypoint | Port | Purpose |
|------------|------|---------|
| `web` | 80 | HTTP traffic |
| `websecure` | 443 | HTTPS traffic (TLS termination) |
| `dashboard` | 8080 | Traefik dashboard (local access) |

### 6.5 Proxy Lifecycle

Commands: `scind proxy init`, `scind proxy up`, `scind proxy down`

The proxy starts automatically with `workspace up` if needed. It is a prerequisite for proxied services.

---

## 7. TLS Certificate Management (ADR-0009)

Three modes supported via `proxy.yaml`:

| Mode | Behavior |
|------|----------|
| `auto` | Uses mkcert if available to generate locally-trusted certificates; falls back to Traefik's default self-signed certificate |
| `custom` | Uses user-provided certificate and key files (enterprise CA) |
| `disabled` | HTTP only, no HTTPS entrypoint |

**Auto mode with mkcert:**
1. User runs `mkcert -install` (once per machine)
2. User generates wildcard cert: `mkcert "*.scind.test"`
3. Scind discovers certificates from `~/.config/scind/certs/`, CWD, or mkcert default location
4. Certificates are mounted into Traefik container

**DNS note:** Scind uses `.test` TLD (RFC 2606) which requires DNS configuration (dnsmasq, `/etc/hosts`, etc.).

---

## 8. Configuration Schemas

### 8.1 `proxy.yaml` (Global)

Location: `~/.config/scind/proxy.yaml`

```yaml
proxy:
  domain: scind.test
  traefik_image: traefik:v3.2.3
  dashboard:
    enabled: true
    port: 8080
  tls:
    mode: auto              # auto | custom | disabled
    cert_file: ~/.config/scind/certs/wildcard.crt   # for custom mode
    key_file: ~/.config/scind/certs/wildcard.key
```

### 8.2 `application.yaml` (Per-App)

Location: `{application}/application.yaml`

```yaml
default_flavor: full

flavors:
  lite:
    compose_files:
      - docker-compose.yaml
  full:
    compose_files:
      - docker-compose.yaml
      - docker-compose.worker.yaml
      - docker-compose.extras.yaml

exported_services:
  web:
    ports:
      - type: proxied
        protocol: https
        visibility: public
      - type: proxied
        protocol: http
        visibility: protected
  api:
    ports:
      - type: proxied
        protocol: https
        visibility: public
  worker:
    ports:
      - type: assigned
        port: 9000
        visibility: protected
  db:
    service: postgres          # Maps to Compose service "postgres", exported as "db"
    ports:
      - type: assigned
        port: 5432
        visibility: protected
```

### 8.3 `workspace.yaml` (Per-Workspace)

Location: `{workspace}/workspace.yaml`

```yaml
workspace:
  name: dev
  applications:
    frontend:
      repository: git@github.com:company/frontend.git
    backend:
      repository: git@github.com:company/backend.git
    shared-db:
      repository: git@github.com:company/shared-db.git
      path: ./database
```

---

## 9. Generated Override Files

Location: `{workspace}/.generated/{application-name}.override.yaml`

Override files wire applications into Scind infrastructure without modifying the application's own compose files. They contain:
- Explicit project name (`name: {workspace}-{app}`)
- Network attachments (workspace-internal + proxy)
- Service aliases for internal hostname resolution
- Traefik routing labels for proxied services
- Scind context and export labels
- Environment variables for service discovery

### Complete Override Example

```yaml
# AUTO-GENERATED - Do not edit directly
# Source: workspace.yaml + frontend/application.yaml
# Flavor: full
# Generated: 2024-12-27T10:30:00Z

name: dev-frontend

services:
  web:
    networks:
      dev-internal:
        aliases:
          - frontend-web
      scind-proxy: {}
    labels:
      # Traefik HTTPS router
      - "traefik.enable=true"
      - "traefik.http.routers.dev-frontend-web-https.rule=Host(`dev-frontend-web.scind.test`)"
      - "traefik.http.routers.dev-frontend-web-https.entrypoints=websecure"
      - "traefik.http.routers.dev-frontend-web-https.tls=true"
      - "traefik.http.services.dev-frontend-web-https.loadbalancer.server.port=80"
      # Scind context labels
      - "scind.workspace.name=dev"
      - "scind.workspace.path=/home/user/workspaces/dev"
      - "scind.app.name=frontend"
      - "scind.app.path=/home/user/workspaces/dev/frontend"
      # Scind export labels
      - "scind.export.web.host=dev-frontend-web.scind.test"
      - "scind.export.web.proxy.https.visibility=public"
      - "scind.export.web.proxy.https.url=https://dev-frontend-web.scind.test"
    environment:
      - SCIND_WORKSPACE_NAME=dev
      - SCIND_FRONTEND_WEB_HOST=dev-frontend-web.scind.test
      - SCIND_FRONTEND_WEB_PORT=443
      - SCIND_FRONTEND_WEB_SCHEME=https
      - SCIND_FRONTEND_WEB_URL=https://dev-frontend-web.scind.test

networks:
  dev-internal:
    external: true
  scind-proxy:
    external: true
```

### Merge Order

```
docker compose -f base.yaml -f .generated/app.override.yaml -f overrides/app.yaml
```

Manual overrides in `{workspace}/overrides/` are never modified by Scind and persist across regeneration.

---

## 10. Hostname Generation & Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Proxied hostname | `{workspace}-{application}-{exported_service}.{domain}` | `dev-frontend-web.scind.test` |
| Internal alias | `{application}-{exported_service}` | `frontend-web` |
| Project name | `{workspace}-{application}` | `dev-frontend` |
| Traefik router | `{workspace}-{application}-{exported_service}-{protocol}` | `dev-frontend-web-https` |
| Environment variable | `SCIND_{APPLICATION}_{EXPORTED_SERVICE}_{SUFFIX}` | `SCIND_FRONTEND_WEB_HOST` |

**Naming constraints:**
- Workspace names: lowercase alphanumeric with hyphens, valid DNS label
- Application names: lowercase alphanumeric with hyphens, inferred from directory name
- Exported service names: lowercase alphanumeric with hyphens

**Hostname templates** (customizable per workspace):
```yaml
workspace:
  templates:
    hostname: "%WORKSPACE_NAME%-%APPLICATION_NAME%-%EXPORTED_SERVICE%.%PROXY_DOMAIN%"
    alias: "%APPLICATION_NAME%-%EXPORTED_SERVICE%"
    project-name: "%WORKSPACE_NAME%-%APPLICATION_NAME%"
```

---

## 11. Environment Variable Injection

All exported services receive `SCIND_`-prefixed environment variables for service discovery. Hyphens are converted to underscores, names uppercased.

### Base Variables (always generated)

```
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_HOST={hostname_or_alias}
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_PORT={port}
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_SCHEME={scheme}    # proxied only
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_URL={url}          # proxied only
```

### Protocol-Specific Variables (proxied only)

```
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_{PROTOCOL}_HOST={hostname}
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_{PROTOCOL}_PORT={port}
SCIND_{APPLICATION}_{EXPORTED_SERVICE}_{PROTOCOL}_URL={url}
```

### Generation Rules

| Type | Protocol | `*_HOST` | `*_PORT` | `*_SCHEME` | `*_URL` | Protocol Vars |
|------|----------|----------|----------|------------|---------|---------------|
| `proxied` | `https` | Proxied hostname | 443 | `https` | Yes | `*_HTTPS_*` |
| `proxied` | `http` | Proxied hostname | 80 | `http` | Yes | `*_HTTP_*` |
| `proxied` | both | Proxied hostname | 443 | `https` | Yes | Both |
| `assigned` | — | Internal alias | Assigned port | No | No | No |

**HTTPS-default:** When both HTTP and HTTPS are configured, base variables default to HTTPS (port 443).

---

## 12. Global State Management

### State File (`~/.config/scind/state.yaml`)

Tracks port assignments for `assigned` type ports and port availability:

```yaml
assigned_ports:
  dev:
    frontend:
      web: 8080
    shared-db:
      db: 5432
      cache: 6379

port_inventory:
  5432:
    status: assigned       # assigned | unavailable | released
    first_seen: 2025-12-28T17:53:55Z
    last_checked: 2025-12-29T13:01:33Z
    assignment:
      workspace: dev
      application: shared-db
      exported_service: db
```

### Port Assignment Algorithm

1. Try the port specified in `application.yaml`
2. If unavailable, increment and try again
3. Record assignment in `assigned_ports` and `port_inventory`
4. Subsequent runs use the recorded port (sticky assignment)

### Workspace Registry (`~/.config/scind/workspaces.yaml`)

Tracks all known workspaces, their paths, and registration timestamps. Enables `workspace list` and prevents name collisions.

---

## 13. Override Generation Algorithm

From the workspace lifecycle spec, the generation sequence:

1. **Resolve flavor** for each application (CLI → state → default_flavor → "default")
2. **Get compose files** from resolved flavor's `compose_files` list
3. **Validate compose files** exist on disk
4. **Validate service references** in `exported_services` point to actual Compose services
5. **Infer port values** for any exported services with omitted `port:` field
6. **Default service names** for any exported services with omitted `service:` field
7. **Collect all exported services** across all applications in workspace
8. **Generate override file** with:
   - `name:` (project name for isolation)
   - `services:` with networks, aliases, labels, environment
   - `networks:` referencing external workspace-internal and scind-proxy networks
9. **Update state file** with resolved flavors
10. **Update manifest** with computed values

### Staleness Detection

Override files are regenerated when any source file has a newer mtime:
- `workspace.yaml`
- `{app}/application.yaml`
- `.generated/state.yaml`
- Active flavor's compose files

---

## 14. CLI Surface Area

### Proxy Commands

| Command | Purpose |
|---------|---------|
| `scind proxy init` | Create proxy infrastructure files in `~/.config/scind/proxy/` |
| `scind proxy up` | Start the Traefik proxy |
| `scind proxy down` | Stop the Traefik proxy |

### Workspace Commands

| Command | Purpose |
|---------|---------|
| `scind workspace init` | Initialize workspace from `workspace.yaml` |
| `scind workspace up` | Start workspace (ensures proxy running, creates networks, generates overrides, starts containers) |
| `scind workspace down` | Stop workspace |
| `scind workspace destroy` | Remove workspace entirely |
| `scind workspace generate` | Regenerate override files |
| `scind workspace list` | List known workspaces |

### Port Management

| Command | Purpose |
|---------|---------|
| `scind port scan` | Check port conflicts |
| `scind port release` | Release a port assignment |
| `scind port gc` | Garbage collect released ports |

---

## 15. Key Decision Records

| ADR | Title | Key Decision |
|-----|-------|-------------|
| ADR-0001 | Docker Compose Project Name Isolation | Use `{workspace}-{app}` project names to prevent conflicts |
| ADR-0002 | Two-Layer Networking | `scind-proxy` (host-wide) + `{workspace}-internal` (per-workspace) |
| ADR-0003 | Pure Overlay Design | All integration via generated override files, no modifications to app compose files |
| ADR-0004 | Convention-Based Naming | Predictable patterns for hostnames, aliases, env vars, router names |
| ADR-0005 | Structure vs State Separation | Configuration (YAML files) separate from runtime state |
| ADR-0006 | Three Configuration Schemas | `proxy.yaml` (global) + `workspace.yaml` (per-workspace) + `application.yaml` (per-app) |
| ADR-0007 | Port Type System | `proxied` (through Traefik) vs `assigned` (direct host bind) |
| ADR-0008 | Traefik for Reverse Proxy | Docker provider with label-based dynamic routing |
| ADR-0009 | Flexible TLS Configuration | Three modes: auto (mkcert), custom (enterprise CA), disabled |
