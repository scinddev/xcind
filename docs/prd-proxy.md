# PRD: xcind-proxy

**Status:** Draft
**Author:** —
**Date:** 2026-03-12

---

## 1. Problem Statement

When running multi-service applications with Docker Compose, developers frequently need a reverse proxy (e.g., Traefik, Caddy, Nginx) to route traffic between services. Today, each project must manually define and maintain proxy configuration in its compose files. This creates boilerplate, divergent patterns across teams, and friction when onboarding new services.

Xcind already solves the "compose file discovery and resolution" problem. **xcind-proxy** extends this by automatically generating proxy configuration from the resolved compose graph — zero manual proxy setup required.

---

## 2. Goals

1. Introduce a new `xcind-proxy` command that inspects the resolved compose configuration and generates an additional compose file wiring up a reverse proxy.
2. Establish the `.xcind/` directory convention for cache and generated artifacts.
3. Introduce a hook system that lets xcind-proxy (and future extensions) participate in the configuration resolution pipeline.
4. Keep xcind-proxy optional — existing `xcind-compose` workflows must continue to work without it.
5. Provide proxy infrastructure lifecycle management (`xcind-proxy init|up|down|status`) so the shared Traefik instance can be managed independently of any project.
6. Use `.localhost` as the default domain for zero-configuration DNS resolution (RFC 6761 — browsers and OS resolve `*.localhost` to `127.0.0.1` without any setup).
7. Lightweight workspace discovery from directory structure, enabling consistent naming across co-located projects without manual workspace declaration.

## 3. Non-Goals (for v1)

- TLS certificate management (ACME, mkcert, etc.) — HTTP only
- Full multi-project orchestration (starting/stopping all workspace apps together)
- GUI or web dashboard for proxy status
- Support for proxy engines other than Traefik (future work)
- Environment variable injection (`SCIND_*`-style service discovery vars)
- Per-workspace internal networks (Scind's `{workspace}-internal` concept)
- Assigned port type (direct host port binding with auto-increment)
- Per-service hostname overrides (URL templates are overridable but individual per-service hostname strings are not)

---

## 4. New Concepts

### 4.1 The `.xcind/` directory

A new project-local directory at the app root (sibling to `.xcind.sh`), used for xcind-managed artifacts that should **not** be committed to version control.

```
<app-root>/
  .xcind.sh
  .xcind/
    cache/<sha>/       # Cached intermediate artifacts
    generated/<sha>/   # Generated compose files (e.g., proxy)
```

**`<sha>`** is derived from the resolved configuration inputs (compose file paths + their content hashes). This ensures generated output is invalidated when any input changes.

**`.gitignore` recommendation:** Projects should add `.xcind/` to `.gitignore`. xcind-proxy should warn (or auto-create a `.gitignore` entry) if it detects the directory is not ignored.

### 4.2 Cache directory — `.xcind/cache/<sha>/`

Stores intermediate data that speeds up repeated runs but can be safely deleted at any time. Contains:

| Artifact | Filename | Contents |
|----------|----------|----------|
| Resolved config metadata | `config.json` | JSON matching `xcind-config` format: `{ appRoot, composeFiles, envFiles, bakeFiles }` |
| Resolved compose output | `resolved-config.yaml` | Output of `docker compose config` (fully merged, variable-expanded) |

### 4.3 Generated directory — `.xcind/generated/<sha>/`

Stores compose files that xcind-proxy (and other hooks) produce. Key artifacts include:

```
.xcind/generated/<sha>/compose.proxy.yaml        # Generated proxy compose file
.xcind/generated/<sha>/.hook-output-<hook_name>   # Persisted stdout from each hook
```

Generated compose files are **appended** to the list of compose flags when `xcind-compose` runs, so Docker Compose merges them with the user's own files.

On cache hit, the pipeline reads all `.hook-output-*` files and replays their contents (appending to `XCIND_DOCKER_COMPOSE_OPTS`) instead of re-running hooks.

### 4.4 Hook System

A mechanism that allows commands (like `xcind-proxy`) to participate in the configuration resolution pipeline.

#### Hook point: `post-resolve-generate`

**When:** After the resolution pipeline has computed the SHA, populated the cache, and exported pipeline env vars — but **before** the final `docker compose` invocation. **Only called on cache miss** (i.e., when `$XCIND_GENERATED_DIR` does not yet exist). On cache hit, the pipeline replays persisted hook output instead of re-running hooks.

**Contract:** A hook is a bash function (or external script) that:

1. Receives `$app_root` as its sole positional argument.
2. Accesses pipeline-computed data via environment variables: `XCIND_SHA`, `XCIND_CACHE_DIR`, `XCIND_GENERATED_DIR`.
3. Reads pre-computed artifacts from `$XCIND_CACHE_DIR/` (e.g., `resolved-config.yaml`, `config.json`).
4. May produce additional files in `$XCIND_GENERATED_DIR/`.
5. Prints zero or more additional Docker Compose flags (e.g., `-f <path>`, `--env-file <path>`) to stdout.
6. Returns exit code 0 on success, non-zero to abort.
7. **Only called on cache miss** — stdout is persisted to `$XCIND_GENERATED_DIR/.hook-output-<hook_name>` and replayed on subsequent cache-hit runs.

**Registration:** Hooks are registered in `.xcind.sh` via a configuration variable:

```bash
XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook")
```

Each entry names a function or command available on `$PATH`. xcind's library invokes them in order after resolution completes.

#### Hook execution flow

```
1. __xcind-app-root              → locate XCIND_APP_ROOT
2. __xcind-discover-workspace    → workspace discovery (see Section 4.6)
   if dirname(XCIND_APP_ROOT)/.xcind.sh exists:
     XCIND_WORKSPACE_ROOT = dirname(XCIND_APP_ROOT)
     XCIND_WORKSPACE = basename(XCIND_WORKSPACE_ROOT)
     XCIND_WORKSPACELESS = 0
     source XCIND_WORKSPACE_ROOT/.xcind.sh
   else:
     XCIND_WORKSPACELESS = 1
     XCIND_WORKSPACE_ROOT = ""
     XCIND_WORKSPACE = ""
3. __xcind-load-config           → source XCIND_APP_ROOT/.xcind.sh (overrides workspace)
4. __xcind-late-bind-workspace   → late-bind self-declaration
   if XCIND_WORKSPACELESS=1 AND XCIND_WORKSPACE != "":
     XCIND_WORKSPACE_ROOT=${XCIND_WORKSPACE_ROOT:-$XCIND_APP_ROOT}
     XCIND_WORKSPACELESS=0
5. __xcind-resolve-app           → XCIND_APP=${XCIND_APP:-$(basename "$XCIND_APP_ROOT")}
6. __xcind-resolve-url-templates → set XCIND_APP_URL_TEMPLATE and XCIND_ROUTER_TEMPLATE
                                   (see Section 4.7)
7. __xcind-resolve-files         → resolved compose files & env files
8. __xcind-build-compose-opts    → XCIND_DOCKER_COMPOSE_OPTS populated
9. __xcind-compute-sha           → SHA from resolved file paths + content hashes
10. export XCIND_SHA, XCIND_CACHE_DIR, XCIND_GENERATED_DIR
11. __xcind-populate-cache       → docker compose config → cache dir
                                   config.json + resolved-config.yaml
12. ── post-resolve-generate hooks (CACHE MISS ONLY) ──
    if $XCIND_GENERATED_DIR does not exist:
      mkdir -p "$XCIND_GENERATED_DIR"
      for each hook in XCIND_HOOKS_POST_RESOLVE_GENERATE:
        output=$(hook "$app_root")
        echo "$output" > "$XCIND_GENERATED_DIR/.hook-output-$hook_name"
        append $output to XCIND_DOCKER_COMPOSE_OPTS
    else (CACHE HIT):
      for each .hook-output-* in $XCIND_GENERATED_DIR:
        read and append to XCIND_DOCKER_COMPOSE_OPTS
13. exec docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" "$@"
```

### 4.5 Template Rendering

`xcind-lib.bash` provides a general-purpose template rendering function, `__xcind-render-template`, that replaces `{key}` placeholders in a string with provided values.

**Signature:**

```bash
__xcind-render-template <template> [key value]...
```

**Example:**

```bash
__xcind-render-template "{app}-{export}.{domain}" \
  app "myapp" \
  export "web" \
  domain "localhost"
# → myapp-web.localhost
```

This function is used by `xcind-proxy-hook` for both hostname/router name generation (see Sections 8 and 12) and for rendering YAML snippets in generated compose override files (see Section 12). It is available for any future template-driven output in the xcind pipeline, including other override file generators that follow the same hybrid pattern.

### 4.6 Workspace Discovery

Xcind supports lightweight workspace discovery from directory structure, using a two-level `.xcind.sh` hierarchy. A parent directory's `.xcind.sh` defines workspace-level config that applies to all apps within it.

#### Discovery algorithm

During step 2 of the hook execution flow, `__xcind-discover-workspace` checks whether a `.xcind.sh` file exists in the parent directory of `XCIND_APP_ROOT`:

```bash
parent="$(dirname "$XCIND_APP_ROOT")"
if [[ -f "$parent/.xcind.sh" ]]; then
  XCIND_WORKSPACE_ROOT="$parent"
  XCIND_WORKSPACE="$(basename "$parent")"
  XCIND_WORKSPACELESS=0
  source "$parent/.xcind.sh"
else
  XCIND_WORKSPACELESS=1
  XCIND_WORKSPACE_ROOT=""
  XCIND_WORKSPACE=""
fi
```

#### Sourcing order

1. **Workspace `.xcind.sh`** — sourced first (if discovered)
2. **App `.xcind.sh`** — sourced second, overrides any workspace-level settings

This means an app can override workspace-level hook registrations, URL templates, or any other variable set by the workspace config.

#### Late-bind self-declaration

An app can self-declare `XCIND_WORKSPACE` in its own `.xcind.sh` without a parent workspace directory. Step 4 (`__xcind-late-bind-workspace`) detects this:

- If no workspace was discovered (`XCIND_WORKSPACELESS=1`) but the app's `.xcind.sh` set `XCIND_WORKSPACE` to a non-empty value:
  - `XCIND_WORKSPACE_ROOT` defaults to `XCIND_APP_ROOT` (unless already set)
  - `XCIND_WORKSPACELESS` flips to `0`

This enables standalone apps to opt into workspace-prefixed URLs without requiring a parent directory structure.

#### Directory layout example

```
workspaces/dev/           ← XCIND_WORKSPACE_ROOT
  .xcind.sh               ← workspace config (sourced first)
  frontend/               ← XCIND_APP_ROOT
    .xcind.sh             ← app config (sourced second, overrides workspace)
    compose.yaml
  backend/
    .xcind.sh
    compose.yaml
```

#### Comparison to Scind

Scind uses separate file types (`workspace.yaml` + `application.yaml`) with a full workspace management system. Xcind's approach is lighter — it reuses the same `.xcind.sh` format at both levels, with discovery based purely on directory structure. This avoids new file formats while enabling the key benefit: consistent naming across co-located projects.

### 4.7 URL Template System

Hostnames and router names are generated from configurable URL templates. The pipeline resolves which template variant to use based on `XCIND_WORKSPACELESS`, so downstream code (hooks) only references the resolved templates.

#### Source templates (user-configurable)

These can be set in workspace or app `.xcind.sh` files:

| Variable | Default |
|----------|---------|
| `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` | `{app}-{export}.{domain}` |
| `XCIND_WORKSPACE_APP_URL_TEMPLATE` | `{workspace}-{app}-{export}.{domain}` |
| `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` | `{app}-{export}-{protocol}` |
| `XCIND_WORKSPACE_ROUTER_TEMPLATE` | `{workspace}-{app}-{export}-{protocol}` |

#### Resolved templates (computed by pipeline)

Step 6 (`__xcind-resolve-url-templates`) selects the appropriate variant:

| Variable | Set from |
|----------|----------|
| `XCIND_APP_URL_TEMPLATE` | `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` or `XCIND_WORKSPACE_APP_URL_TEMPLATE` based on `XCIND_WORKSPACELESS` |
| `XCIND_ROUTER_TEMPLATE` | `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` or `XCIND_WORKSPACE_ROUTER_TEMPLATE` based on `XCIND_WORKSPACELESS` |

Downstream code (e.g., `xcind-proxy-hook`) only references `XCIND_APP_URL_TEMPLATE` and `XCIND_ROUTER_TEMPLATE` — no workspace-mode branching needed.

Note: unused `{workspace}` placeholder is simply absent from workspaceless templates, so no special handling is needed in the rendering function.

---

## 5. `xcind-proxy` Command

### 5.1 Overview

`xcind-proxy` is a new executable (`bin/xcind-proxy`) that manages the shared Traefik proxy infrastructure and provides a hook for per-project proxy configuration generation.

Two distinct roles:
1. **Infrastructure management** — `xcind-proxy init|up|down|status` manages the shared Traefik instance at `~/.config/xcind/proxy/`.
2. **Hook function** — `xcind-proxy-hook` generates per-project `compose.proxy.yaml` files during the resolution pipeline.

### 5.2 Service Discovery

Services opt-in to proxying via declarations in `.xcind.sh`:

```bash
# Required: array of services to expose through the proxy
# Format: "export_name" | "export_name:port" | "export_name=compose_service" | "export_name=compose_service:port"
XCIND_PROXY_EXPORTS=("web" "api:3000" "db=postgres:5432")

# Optional: application name (defaults to basename of app root directory)
XCIND_APP="myapp"
```

Note: `XCIND_WORKSPACE` is now discovered automatically from directory structure (see Section 4.6) rather than declared in the app `.xcind.sh`. Apps can still self-declare `XCIND_WORKSPACE` for late-bind scenarios where no parent workspace directory exists.

**Entry format:** Each entry in `XCIND_PROXY_EXPORTS` has the form `export_name[=compose_service][:port]`:

| Entry | Export name | Compose service | Port |
|-------|-------------|-----------------|------|
| `"web"` | web | web | inferred |
| `"api:3000"` | api | api | 3000 |
| `"db=postgres"` | db | postgres | inferred |
| `"db=postgres:5432"` | db | postgres | 5432 |

When no `=` separator is present, the export name and compose service name are the same. The **export name** is used for hostname generation, router names, and export labels. The **compose service name** is used for YAML merge keys and service validation.

**Port inference:** When no port is specified, the hook reads `$XCIND_CACHE_DIR/resolved-config.yaml` and looks up the compose service's port configuration:
- If the service has exactly **one** port mapping → use the container port (e.g., `"80:8080"` → `8080`)
- If the service has **zero** ports → error: "Service 'postgres' has no port mappings. Specify port explicitly: db=postgres:5432"
- If the service has **multiple** ports → error: "Service 'postgres' has multiple port mappings. Specify port explicitly: db=postgres:5432"

**Service validation:** The compose service name from each entry in `XCIND_PROXY_EXPORTS` must exist in `resolved-config.yaml`. Missing services produce an error listing available services.

### 5.3 Generated Compose File

The generated `compose.proxy.yaml` adds network attachment and Traefik labels to existing services. **Traefik itself runs separately** (via `xcind-proxy up`), so this file does NOT define a proxy service.

The file is generated using a hybrid template approach: a per-service YAML snippet template is rendered via `__xcind-render-template` for each export entry, and the rendered snippets are concatenated with static YAML boilerplate (header and footer). See Section 12 for the template and algorithm details.

Example output for `XCIND_PROXY_EXPORTS=("web" "api:3000" "db=postgres:5432")` with `XCIND_APP="myapp"` (workspaceless mode):

```yaml
services:
  web:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-web-http.rule=Host(`myapp-web.localhost`)"
      - "traefik.http.routers.myapp-web-http.entrypoints=web"
      - "traefik.http.services.myapp-web-http.loadbalancer.server.port=80"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"
      - "xcind.export.web.host=myapp-web.localhost"
      - "xcind.export.web.url=http://myapp-web.localhost"

  api:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-api-http.rule=Host(`myapp-api.localhost`)"
      - "traefik.http.routers.myapp-api-http.entrypoints=web"
      - "traefik.http.services.myapp-api-http.loadbalancer.server.port=3000"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"
      - "xcind.export.api.host=myapp-api.localhost"
      - "xcind.export.api.url=http://myapp-api.localhost"

  postgres:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-db-http.rule=Host(`myapp-db.localhost`)"
      - "traefik.http.routers.myapp-db-http.entrypoints=web"
      - "traefik.http.services.myapp-db-http.loadbalancer.server.port=5432"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"
      - "xcind.export.db.host=myapp-db.localhost"
      - "xcind.export.db.url=http://myapp-db.localhost"

networks:
  xcind-proxy:
    external: true
```

Note that the `postgres` service uses its compose service name as the YAML key but the export name `db` in hostnames, router names, and export labels.

With workspace active (`XCIND_WORKSPACE="dev"`), hostnames and router names are generated from `XCIND_APP_URL_TEMPLATE` and `XCIND_ROUTER_TEMPLATE` (see Section 4.7). For example, with default workspace templates: `dev-myapp-web.localhost`, `dev-myapp-api.localhost`, etc. Additionally, `xcind.workspace.name` and `xcind.workspace.path` labels are included:

```yaml
      - "xcind.workspace.name=dev"
      - "xcind.workspace.path=/path/to/workspaces/dev"
```

### 5.4 CLI Interface

```
xcind-proxy <subcommand>

Subcommands:
  init       Create proxy infrastructure files in ~/.config/xcind/proxy/
  up         Start the shared Traefik proxy
  down       Stop the shared Traefik proxy
  status     Show proxy state (running/stopped, port, URL)
```

### 5.5 Integration as a Hook

`xcind-proxy` ships a hook function, `xcind-proxy-hook`, that users register in `.xcind.sh`:

```bash
XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook")
```

When invoked as a hook (cache miss only), `xcind-proxy-hook`:

1. Reads `XCIND_APP`, `XCIND_WORKSPACE`, `XCIND_APP_URL_TEMPLATE`, and `XCIND_ROUTER_TEMPLATE` from the environment (already set by the pipeline — see Section 4.4, steps 2–6).
2. Sources global config (`~/.config/xcind/proxy/config.sh`) for `XCIND_PROXY_DOMAIN`.
3. Reads `$XCIND_CACHE_DIR/resolved-config.yaml` to validate services and infer ports.
4. For each export entry: validates service exists, infers port if needed, renders hostname and router name using `XCIND_APP_URL_TEMPLATE` and `XCIND_ROUTER_TEMPLATE`.
5. Writes `compose.proxy.yaml` to `$XCIND_GENERATED_DIR/`.
6. Prints `-f $XCIND_GENERATED_DIR/compose.proxy.yaml` to stdout.

The hook no longer re-sources `.xcind.sh` or selects template variants itself — the pipeline handles workspace discovery, app name resolution, and URL template resolution before hooks run.

No SHA check is needed within the hook — it is only called on cache miss by the pipeline. On cache hit, the pipeline replays the hook's persisted output automatically.

This means `xcind-compose up` automatically includes the proxy with zero extra steps once the hook is registered.

---

## 6. SHA Computation

The `<sha>` used for cache and generated directories is computed as:

```
sha256( sorted(resolved_compose_file_paths) + content_hash(each_file) )
```

This ensures:
- Adding, removing, or reordering compose files invalidates the cache.
- Changing the content of any compose file invalidates the cache.
- Identical configurations across runs reuse the same directory.

The SHA is computed by the resolution pipeline (step 9 in the execution flow) and exported as `XCIND_SHA` for use by hooks and other tooling.

---

## 7. Configuration

### 7.1 Project Configuration

#### 7.1a Workspace Configuration (workspace `.xcind.sh`)

Workspace-level settings apply to all apps within the workspace directory. Apps can override any of these in their own `.xcind.sh`.

```bash
# Hook registration (applies to all apps in this workspace)
XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook")

# URL template overrides (optional — defaults shown in Section 4.7)
XCIND_WORKSPACE_APP_URL_TEMPLATE="{workspace}-{app}-{export}.{domain}"
XCIND_WORKSPACE_ROUTER_TEMPLATE="{workspace}-{app}-{export}-{protocol}"
```

#### 7.1b App Configuration (app `.xcind.sh`)

Per-app settings. Values here override workspace-level settings.

```bash
# Service exports — which services to expose through the proxy
XCIND_PROXY_EXPORTS=("web" "api:3000")

# Application name (optional, defaults to basename of app root)
XCIND_APP="myapp"

# Late-bind workspace self-declaration (optional — only needed when
# no parent workspace directory exists)
# XCIND_WORKSPACE="dev"
```

#### 7.1c Full Variable Reference

| Variable | Set By | Default | Description |
|----------|--------|---------|-------------|
| `XCIND_APP` | user | `basename "$XCIND_APP_ROOT"` | Application name used in hostnames and labels |
| `XCIND_WORKSPACE` | computed/user | `basename "$XCIND_WORKSPACE_ROOT"` or `""` | Workspace name; auto-discovered or self-declared |
| `XCIND_WORKSPACE_ROOT` | computed | `dirname "$XCIND_APP_ROOT"` (if workspace found) | Path to workspace root directory |
| `XCIND_WORKSPACELESS` | computed | `1` (no workspace) or `0` | Whether workspace mode is active |
| `XCIND_APP_ROOT` | computed | — | Path to app root directory (where app `.xcind.sh` lives) |
| `XCIND_PROXY_EXPORTS` | user | `()` | Array of service export declarations |
| `XCIND_PROXY_DOMAIN` | user (global) | `localhost` | Domain suffix for generated hostnames |
| `XCIND_WORKSPACELESS_APP_URL_TEMPLATE` | user | `{app}-{export}.{domain}` | Hostname template (no workspace) |
| `XCIND_WORKSPACE_APP_URL_TEMPLATE` | user | `{workspace}-{app}-{export}.{domain}` | Hostname template (with workspace) |
| `XCIND_WORKSPACELESS_ROUTER_TEMPLATE` | user | `{app}-{export}-{protocol}` | Router name template (no workspace) |
| `XCIND_WORKSPACE_ROUTER_TEMPLATE` | user | `{workspace}-{app}-{export}-{protocol}` | Router name template (with workspace) |
| `XCIND_APP_URL_TEMPLATE` | computed | — | Resolved hostname template (from workspaceless or workspace variant) |
| `XCIND_ROUTER_TEMPLATE` | computed | — | Resolved router name template (from workspaceless or workspace variant) |
| `XCIND_HOOKS_POST_RESOLVE_GENERATE` | user | `()` | Array of hook function/command names |
| `XCIND_SHA` | computed | — | SHA of resolved configuration inputs |
| `XCIND_CACHE_DIR` | computed | — | Path to cache directory for current SHA |
| `XCIND_GENERATED_DIR` | computed | — | Path to generated directory for current SHA |

### 7.2 Global Configuration (`~/.config/xcind/proxy/config.sh`)

Proxy engine settings live in a global config file, not per-project:

```bash
# Default domain suffix for generated hostnames
# .localhost requires zero DNS config (RFC 6761)
XCIND_PROXY_DOMAIN="localhost"

# Traefik Docker image
XCIND_PROXY_IMAGE="traefik:v3"

# Host port for HTTP traffic
XCIND_PROXY_HTTP_PORT="80"

# Enable Traefik dashboard
XCIND_PROXY_DASHBOARD="false"

# Dashboard port (only used if dashboard is enabled)
XCIND_PROXY_DASHBOARD_PORT="8080"
```

---

## 8. Hostname Generation

### Pattern

Hostnames and router names are generated using `__xcind-render-template` (see Section 4.5) with the resolved templates from the pipeline (see Section 4.7):

```bash
# Hostname generation — uses pre-resolved XCIND_APP_URL_TEMPLATE
hostname=$(__xcind-render-template "$XCIND_APP_URL_TEMPLATE" \
  workspace "$XCIND_WORKSPACE" app "$XCIND_APP" \
  export "$export_name" domain "$XCIND_PROXY_DOMAIN")

# Router name — uses pre-resolved XCIND_ROUTER_TEMPLATE
router=$(__xcind-render-template "$XCIND_ROUTER_TEMPLATE" \
  workspace "$XCIND_WORKSPACE" app "$XCIND_APP" \
  export "$export_name" protocol "http")
```

Template variables:
- `{export}` = export name from `XCIND_PROXY_EXPORTS` (the key, or left side of `=`)
- `{app}` = `XCIND_APP` (or `basename "$XCIND_APP_ROOT"`)
- `{workspace}` = `XCIND_WORKSPACE` (if set; absent from workspaceless templates)
- `{domain}` = `XCIND_PROXY_DOMAIN` (default: `localhost`)
- `{protocol}` = protocol suffix (always `http` for v1)

Note: unused `{workspace}` placeholder is simply absent from workspaceless templates, so no special handling is needed. The hook does not branch on workspace mode — the pipeline pre-resolves the correct template variant.

**Default templates and examples:**

| Mode | Template | Example |
|------|----------|---------|
| Workspaceless hostname | `{app}-{export}.{domain}` | `myapp-web.localhost` |
| Workspace hostname | `{workspace}-{app}-{export}.{domain}` | `dev-myapp-web.localhost` |
| Workspaceless router | `{app}-{export}-{protocol}` | `myapp-web-http` |
| Workspace router | `{workspace}-{app}-{export}-{protocol}` | `dev-myapp-web-http` |

### Why `.localhost`

RFC 6761 reserves `.localhost` for loopback resolution. Modern browsers and operating systems resolve any `*.localhost` address to `127.0.0.1` without DNS configuration, `/etc/hosts` entries, or dnsmasq. This eliminates a significant onboarding friction point compared to `.test` or `.local` domains.

---

## 9. Proxy Infrastructure Management

### `xcind-proxy init`

Creates the proxy infrastructure directory and files:

1. Create `~/.config/xcind/proxy/` if it doesn't exist
2. Write `config.sh` with defaults (if not present)
3. Write `docker-compose.yaml` (Traefik service definition)
4. Write `traefik.yaml` (Traefik static configuration)
5. Create `scind-proxy` Docker network if it doesn't exist (`docker network create xcind-proxy`)

Idempotent — safe to run multiple times. Existing `config.sh` is never overwritten.

### `xcind-proxy up`

1. Ensure infrastructure files exist (run `init` if needed)
2. Ensure `xcind-proxy` Docker network exists
3. `docker compose -f ~/.config/xcind/proxy/docker-compose.yaml up -d`

### `xcind-proxy down`

1. `docker compose -f ~/.config/xcind/proxy/docker-compose.yaml down`

Does NOT remove the `xcind-proxy` network (running project containers may still reference it).

### `xcind-proxy status`

Displays:
- Proxy running state (running/stopped/not initialized)
- Traefik image version
- HTTP port
- Dashboard URL (if enabled)
- Network status (`xcind-proxy` exists/missing)

---

## 10. Generated Traefik Config Files

### `docker-compose.yaml`

Generated by `xcind-proxy init` into `~/.config/xcind/proxy/`:

```yaml
name: xcind-proxy

services:
  traefik:
    image: ${XCIND_PROXY_IMAGE:-traefik:v3}
    command:
      - "--configFile=/etc/traefik/traefik.yaml"
    ports:
      - "${XCIND_PROXY_HTTP_PORT:-80}:80"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yaml:/etc/traefik/traefik.yaml:ro
    networks:
      - xcind-proxy
    restart: unless-stopped
    labels:
      - "xcind.managed=true"
      - "xcind.component=proxy"

networks:
  xcind-proxy:
    external: true
```

When `XCIND_PROXY_DASHBOARD="true"`, the compose file additionally includes:
- `--api.dashboard=true` in command
- Port mapping for `${XCIND_PROXY_DASHBOARD_PORT:-8080}:8080`

### `traefik.yaml`

```yaml
entryPoints:
  web:
    address: ":80"

providers:
  docker:
    exposedByDefault: false
    network: xcind-proxy

log:
  level: INFO
```

When dashboard is enabled, adds:
```yaml
api:
  dashboard: true
  insecure: true
```

---

## 11. Context Labels

Labels added to every proxied service container for discovery and tooling:

| Label | Source | Example |
|-------|--------|---------|
| `xcind.app.name` | `XCIND_APP` or dirname | `myapp` |
| `xcind.app.path` | `$XCIND_APP_ROOT` | `/Users/dev/myapp` |
| `xcind.workspace.name` | `XCIND_WORKSPACE` (if set) | `dev` |
| `xcind.workspace.path` | `XCIND_WORKSPACE_ROOT` (if set) | `/Users/dev/workspaces/dev` |
| `xcind.export.{export_name}.host` | Generated hostname | `myapp-web.localhost` |
| `xcind.export.{export_name}.url` | `http://{hostname}` | `http://myapp-web.localhost` |

The `xcind.export.*` labels (aligned with Scind's `scind.export.*` convention) provide machine-readable service discovery, enabling tooling to find the hostname and URL for any exported service.

These labels enable queries like:

```bash
# Find all xcind-proxied containers
docker ps --filter "label=xcind.app.name"

# Find containers for a specific app
docker ps --filter "label=xcind.app.name=myapp"

# Find the URL for a specific export
docker inspect --format '{{index .Config.Labels "xcind.export.web.url"}}' <container>
```

---

## 12. Override Generation Algorithm

### 12.1 Hybrid Template Approach

The generated `compose.proxy.yaml` is built using a hybrid template approach rather than a monolithic heredoc. A per-service YAML snippet is defined as a template string with `{key}` placeholders, rendered via `__xcind-render-template` for each export entry, and concatenated with static YAML boilerplate.

This approach keeps template content readable and editable, avoids heredoc escaping issues, and establishes a consistent pattern for other compose override generators to follow.

**Per-service template (without workspace):**

```bash
XCIND_PROXY_SERVICE_TEMPLATE='  {compose_service}:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"'
```

When workspace is active, the template includes additional workspace labels:

```bash
XCIND_PROXY_SERVICE_TEMPLATE_WORKSPACE='  {compose_service}:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.workspace.name={workspace}"
      - "xcind.workspace.path={workspace_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"'
```

**Rendering per export entry:**

```bash
__xcind-render-template "$service_template" \
  compose_service "$compose_svc" \
  router "$router" \
  hostname "$hostname" \
  port "$port" \
  app "$XCIND_APP" \
  app_path "$app_root" \
  workspace "$XCIND_WORKSPACE" \
  workspace_path "$XCIND_WORKSPACE_ROOT" \
  export "$export_name"
```

**Assembly:** The final file is built by writing `services:\n` as a header, appending each rendered service snippet (separated by blank lines), then appending the static network footer (`networks:\n  xcind-proxy:\n    external: true`).

### 12.2 Step-by-Step Flow

When `xcind-proxy-hook` is invoked during a cache miss:

1. **Receive `$app_root`** as positional argument from the hook system.
2. **Read pipeline env vars** — `XCIND_APP`, `XCIND_WORKSPACE`, `XCIND_WORKSPACE_ROOT`, `XCIND_WORKSPACELESS`, `XCIND_APP_URL_TEMPLATE`, `XCIND_ROUTER_TEMPLATE`, and `XCIND_PROXY_EXPORTS` are already set by the pipeline (steps 1–6).
3. **Source global config** — `~/.config/xcind/proxy/config.sh` for `XCIND_PROXY_DOMAIN` (default: `localhost`).
4. **Select service template** — choose `XCIND_PROXY_SERVICE_TEMPLATE_WORKSPACE` or `XCIND_PROXY_SERVICE_TEMPLATE` based on `XCIND_WORKSPACELESS`.
5. **Parse resolved config** — read `$XCIND_CACHE_DIR/resolved-config.yaml` using `yq` to get available services and their port mappings.
6. **Initialize output** — start with `services:\n` header.
7. **For each entry in `XCIND_PROXY_EXPORTS`:**
   - a. **Parse entry**: split on `=` to get export name and optional compose service; split the right side on `:` to get compose service name and optional port. If no `=`, export name = compose service name.
   - b. **Validate compose service** exists in resolved config. If not, error with list of available services.
   - c. **Resolve port**: If port specified, use it. If not, infer from resolved config using the compose service name (exactly one port → use it; zero or multiple → error).
   - d. **Generate hostname** via `__xcind-render-template` using `XCIND_APP_URL_TEMPLATE` (see Section 8).
   - e. **Generate router name** via `__xcind-render-template` using `XCIND_ROUTER_TEMPLATE` (see Section 8).
   - f. **Render service snippet** via `__xcind-render-template` using the selected service template with all resolved values.
   - g. **Append** rendered snippet to output.
8. **Append network footer** — `networks:\n  xcind-proxy:\n    external: true`.
9. **Write `compose.proxy.yaml`** to `$XCIND_GENERATED_DIR/`.
10. **Print** `-f $XCIND_GENERATED_DIR/compose.proxy.yaml` to stdout.

Note: the hook no longer needs workspace-mode branching for template selection — `XCIND_APP_URL_TEMPLATE` and `XCIND_ROUTER_TEMPLATE` are pre-resolved by the pipeline. The only workspace-dependent choice within the hook is which service snippet template to use (with or without workspace labels).

---

## 13. File & Directory Layout (after implementation)

```
<xcind repo>/
  bin/
    xcind-compose          # existing
    xcind-config           # existing
    xcind-proxy            # NEW — proxy infrastructure + hook command
  lib/xcind/
    xcind-lib.bash         # existing (extended with hook support)
    xcind-proxy-lib.bash   # NEW — proxy generation logic
  test/
    test-xcind.sh          # existing
    test-xcind-proxy.sh    # NEW — proxy tests
```

```
<workspace>/
  .xcind.sh                # workspace config (sourced first)
  <app>/
    .xcind.sh              # app config (sourced second, overrides workspace)
    .xcind/
      cache/<sha>/
      generated/<sha>/
        compose.proxy.yaml
    compose.yaml           # user's compose file(s)
```

```
<standalone app>/
  .xcind.sh                # app config (+ hook registration + proxy exports)
  .xcind/
    cache/<sha>/
    generated/<sha>/
      compose.proxy.yaml
  compose.yaml             # user's compose file(s)
```

```
~/.config/xcind/proxy/     # NEW — global proxy infrastructure
  config.sh                # Global proxy settings
  docker-compose.yaml      # Traefik service definition
  traefik.yaml             # Traefik static configuration
```

---

## 14. Open Questions

1. **SHA scope:** Should the SHA include env file contents too, or only compose files? Env files don't affect proxy routing, but they could affect variable expansion in compose files.

2. **Garbage collection:** Should old `<sha>` directories be cleaned up automatically? If so, what retention policy (keep N most recent, age-based, manual only)?

3. ~~**Multi-proxy support:** Should we support generating configurations for multiple proxy engines (Traefik, Caddy, Nginx) from the start, or ship Traefik-only and extend later?~~ **Resolved:** Traefik only for v1.

4. ~~**Network creation:** Should xcind-proxy create a shared network or require the user to define one? Docker Compose's default per-project network may be sufficient for single-project use.~~ **Resolved:** Single `xcind-proxy` external network, created by `xcind-proxy init`.

5. **Hook ordering guarantees:** If multiple hooks are registered, do they run in declared order? Can one hook's output influence another's input?

6. ~~**Compose file parsing:** Pure bash YAML parsing is fragile. Should we require `yq` as a dependency, or shell out to `docker compose config` to get a normalized view of the resolved config?~~ **Resolved:** `yq` is required for YAML parsing. The resolved config is already produced by `docker compose config` and cached in `resolved-config.yaml`.

7. **Auto-start behavior:** Should `xcind-compose up` automatically run `xcind-proxy up` if the proxy isn't running? Or should users explicitly start it?

8. **Network-not-exists handling:** If a project's compose references `xcind-proxy` network but it doesn't exist (e.g., `xcind-proxy init` never ran), what's the failure mode? Should the hook check and provide a helpful error?

9. ~~**Workspace SHA inclusion:** Should workspace `.xcind.sh` content be included in SHA computation?~~ **Resolved:** Yes, include workspace `.xcind.sh` content in SHA computation. Workspace config changes (e.g., template overrides) should invalidate all app caches.

10. **DNS-safe names:** Should workspace/app names be validated as DNS-safe (lowercase alphanumeric + hyphens)?

---

## 15. Future Work

- **TLS support:** Add HTTPS via mkcert integration (auto mode) or custom certificates, following Scind's ADR-0009 three-mode pattern.
- **Environment variable injection:** Generate `XCIND_*` service discovery variables for inter-service communication.
- **Per-workspace internal networks:** `{workspace}-internal` networks for cross-project communication within a workspace.
- **Assigned port type:** Direct host port binding with auto-increment for non-HTTP services (databases, debug ports).
- **Multi-project orchestration:** Coordinate multiple `.xcind.sh` projects in a workspace, with a `workspace.yaml` analog.
- **Dashboard port:** Optionally expose Traefik's dashboard for debugging routing rules.

See [Research: Scind Proxy Architecture](research-scind-proxy.md) for the full Scind spec these features are drawn from.

---

## 16. Success Criteria

- [ ] `xcind-proxy init` creates valid proxy infrastructure that `docker compose up` accepts.
- [ ] `xcind-proxy up|down|status` manage the Traefik lifecycle correctly.
- [ ] The `post-resolve-generate` hook integrates transparently — `xcind-compose up` starts the proxy alongside application services.
- [ ] Generated `compose.proxy.yaml` is valid and routes traffic to the correct services on the expected hostnames.
- [ ] Hostnames resolve correctly via `.localhost` with zero DNS configuration.
- [ ] SHA-based caching avoids regeneration when inputs haven't changed.
- [ ] Existing xcind workflows (no proxy, no hooks) are completely unaffected.
- [ ] Test coverage for hook execution, SHA computation, proxy generation, hostname generation, and cache invalidation.
- [ ] Workspace `.xcind.sh` discovered and sourced before app `.xcind.sh`.
- [ ] App `.xcind.sh` overrides workspace-level settings.
- [ ] Late-bind self-declared workspace works without parent directory.
- [ ] URL templates resolve correctly for both workspaceless and workspace modes.
- [ ] Custom URL templates override defaults.
- [ ] Workspace labels (`xcind.workspace.name`, `xcind.workspace.path`) appear when workspace is active.
