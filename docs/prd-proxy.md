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

## 3. Non-Goals (for v1)

- TLS certificate management (ACME, mkcert, etc.) — HTTP only
- Multi-project proxy orchestration (single `.xcind.sh` root at a time)
- GUI or web dashboard for proxy status
- Support for proxy engines other than Traefik (future work)
- Environment variable injection (`SCIND_*`-style service discovery vars)
- Per-workspace internal networks (Scind's `{workspace}-internal` concept)
- Assigned port type (direct host port binding with auto-increment)
- Per-service hostname overrides (hostnames are auto-generated only)

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
1. __xcind-load-config           → source .xcind.sh
2. __xcind-resolve-files         → resolved compose files & env files
3. __xcind-build-compose-opts    → XCIND_DOCKER_COMPOSE_OPTS populated
4. __xcind-compute-sha           → SHA from resolved file paths + content hashes
5. export XCIND_SHA, XCIND_CACHE_DIR, XCIND_GENERATED_DIR
6. __xcind-populate-cache        → docker compose config → cache dir
                                   config.json + resolved-config.yaml
7. ── post-resolve-generate hooks (CACHE MISS ONLY) ──
   if $XCIND_GENERATED_DIR does not exist:
     mkdir -p "$XCIND_GENERATED_DIR"
     for each hook in XCIND_HOOKS_POST_RESOLVE_GENERATE:
       output=$(hook "$app_root")
       echo "$output" > "$XCIND_GENERATED_DIR/.hook-output-$hook_name"
       append $output to XCIND_DOCKER_COMPOSE_OPTS
   else (CACHE HIT):
     for each .hook-output-* in $XCIND_GENERATED_DIR:
       read and append to XCIND_DOCKER_COMPOSE_OPTS
8. exec docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" "$@"
```

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
# Format: "service" (port inferred) or "service:port" (explicit)
XCIND_PROXY_EXPORTS=("web" "api:3000")

# Optional: application name (defaults to basename of app root directory)
XCIND_APP_NAME="myapp"

# Optional: workspace qualifier (defaults to empty string)
XCIND_WORKSPACE="dev"
```

**Port inference:** When no port is specified (e.g., `"web"`), the hook reads `$XCIND_CACHE_DIR/resolved-config.yaml` and looks up the service's port configuration:
- If the service has exactly **one** port mapping → use the container port (e.g., `"80:8080"` → `8080`)
- If the service has **zero** ports → error: "Service 'web' has no port mappings. Specify port explicitly: web:8080"
- If the service has **multiple** ports → error: "Service 'web' has multiple port mappings. Specify port explicitly: web:8080"

**Service validation:** Each service name in `XCIND_PROXY_EXPORTS` must exist in `resolved-config.yaml`. Missing services produce an error listing available services.

### 5.3 Generated Compose File

The generated `compose.proxy.yaml` adds network attachment and Traefik labels to existing services. **Traefik itself runs separately** (via `xcind-proxy up`), so this file does NOT define a proxy service.

Example for `XCIND_PROXY_EXPORTS=("web" "api:3000")` with `XCIND_APP_NAME="myapp"`:

```yaml
services:
  web:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.web-myapp.rule=Host(`web-myapp.localhost`)"
      - "traefik.http.routers.web-myapp.entrypoints=web"
      - "traefik.http.services.web-myapp.loadbalancer.server.port=80"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"

  api:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api-myapp.rule=Host(`api-myapp.localhost`)"
      - "traefik.http.routers.api-myapp.entrypoints=web"
      - "traefik.http.services.api-myapp.loadbalancer.server.port=3000"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"

networks:
  xcind-proxy:
    external: true
```

With `XCIND_WORKSPACE="dev"`, hostnames become `web-myapp-dev.localhost` and `api-myapp-dev.localhost`.

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

1. Sources `.xcind.sh` to read `XCIND_PROXY_EXPORTS`, `XCIND_APP_NAME`, and `XCIND_WORKSPACE`.
2. Sources global config (`~/.config/xcind/proxy/config.sh`) for `XCIND_PROXY_DOMAIN`.
3. Reads `$XCIND_CACHE_DIR/resolved-config.yaml` to validate services and infer ports.
4. For each export entry: validates service exists, infers port if needed, generates hostname and router name.
5. Writes `compose.proxy.yaml` to `$XCIND_GENERATED_DIR/`.
6. Prints `-f $XCIND_GENERATED_DIR/compose.proxy.yaml` to stdout.

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

The SHA is computed by the resolution pipeline (step 4 in the execution flow) and exported as `XCIND_SHA` for use by hooks and other tooling.

---

## 7. Configuration

### 7.1 Project Configuration (`.xcind.sh`)

Proxy-related variables declared in `.xcind.sh`:

```bash
# Hook registration (array of function/command names)
XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook")

# Service exports — which services to expose through the proxy
# Format: "service" (port auto-inferred) or "service:port" (explicit)
XCIND_PROXY_EXPORTS=("web" "api:3000")

# Application name (optional, defaults to basename of app root)
XCIND_APP_NAME="myapp"

# Workspace qualifier (optional, defaults to empty)
XCIND_WORKSPACE="dev"
```

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

Hostnames follow a fixed pattern based on whether a workspace is specified:

| Workspace? | Pattern | Example |
|------------|---------|---------|
| No | `{service}-{app}.{domain}` | `web-myapp.localhost` |
| Yes | `{service}-{app}-{workspace}.{domain}` | `web-myapp-dev.localhost` |

Where:
- `{service}` = service name from `XCIND_PROXY_EXPORTS`
- `{app}` = `XCIND_APP_NAME` (or `basename "$app_root"`)
- `{workspace}` = `XCIND_WORKSPACE` (if set)
- `{domain}` = `XCIND_PROXY_DOMAIN` (default: `localhost`)

### Router Naming

Traefik router names follow the same pattern without the domain:
- Without workspace: `{service}-{app}` (e.g., `web-myapp`)
- With workspace: `{service}-{app}-{workspace}` (e.g., `web-myapp-dev`)

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
| `xcind.app.name` | `XCIND_APP_NAME` or dirname | `myapp` |
| `xcind.app.path` | `$app_root` | `/Users/dev/myapp` |
| `xcind.workspace.name` | `XCIND_WORKSPACE` (if set) | `dev` |

These labels enable queries like:

```bash
# Find all xcind-proxied containers
docker ps --filter "label=xcind.app.name"

# Find containers for a specific app
docker ps --filter "label=xcind.app.name=myapp"
```

---

## 12. Override Generation Algorithm

Step-by-step flow when `xcind-proxy-hook` is invoked during a cache miss:

1. **Receive `$app_root`** as positional argument from the hook system.
2. **Read `.xcind.sh`** — already sourced by pipeline. Extract `XCIND_PROXY_EXPORTS` array, `XCIND_APP_NAME` (default: `basename "$app_root"`), `XCIND_WORKSPACE` (default: empty).
3. **Source global config** — `~/.config/xcind/proxy/config.sh` for `XCIND_PROXY_DOMAIN` (default: `localhost`).
4. **Parse resolved config** — read `$XCIND_CACHE_DIR/resolved-config.yaml` using `yq` to get available services and their port mappings.
5. **For each entry in `XCIND_PROXY_EXPORTS`:**
   - a. Parse entry: split on `:` to get service name and optional port.
   - b. **Validate service** exists in resolved config. If not, error with list of available services.
   - c. **Resolve port**: If port specified, use it. If not, infer from resolved config (exactly one port → use it; zero or multiple → error).
   - d. **Generate hostname**: `{service}-{app}.{domain}` or `{service}-{app}-{workspace}.{domain}`.
   - e. **Generate router name**: same as hostname minus domain.
6. **Write `compose.proxy.yaml`** to `$XCIND_GENERATED_DIR/` containing:
   - Service entries with `networks: { xcind-proxy: {} }` and `labels` (Traefik routing + xcind context)
   - Top-level `networks: { xcind-proxy: { external: true } }`
7. **Print** `-f $XCIND_GENERATED_DIR/compose.proxy.yaml` to stdout.

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
<user project>/
  .xcind.sh                # existing (+ hook registration + proxy exports)
  .xcind/                  # NEW
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
