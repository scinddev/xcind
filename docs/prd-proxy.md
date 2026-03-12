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

## 3. Non-Goals (for v1)

- TLS certificate management (ACME, mkcert, etc.)
- Multi-project proxy orchestration (single `.xcind.sh` root at a time)
- GUI or web dashboard for proxy status
- Support for proxy engines other than Traefik (future work)

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

Stores intermediate data that speeds up repeated runs but can be safely deleted at any time. Examples:

- Parsed service metadata extracted from compose files
- Hash manifests used for change detection

### 4.3 Generated directory — `.xcind/generated/<sha>/`

Stores compose files that xcind-proxy produces. The key artifact is:

```
.xcind/generated/<sha>/compose.proxy.yaml
```

This file is **appended** to the list of `-f` flags when `xcind-compose` runs, so Docker Compose merges it with the user's own files.

### 4.4 Hook System

A mechanism that allows commands (like `xcind-proxy`) to participate in the configuration resolution pipeline.

#### Hook point: `post-resolve`

**When:** After `__xcind-build-compose-opts` has resolved all compose and env files, but **before** the final `docker compose` invocation.

**Contract:** A hook is a bash function (or external script) that:

1. Receives the app root and the list of resolved compose files as arguments.
2. May inspect the resolved configuration (parse compose files, read labels, etc.).
3. May produce additional compose files (written to `.xcind/generated/<sha>/`).
4. Prints zero or more additional `-f <path>` flags to stdout.
5. Returns exit code 0 on success, non-zero to abort.

**Registration:** Hooks are registered in `.xcind.sh` via a new configuration variable:

```bash
XCIND_HOOKS_POST_RESOLVE=("xcind-proxy-hook")
```

Each entry names a function or command available on `$PATH`. xcind's library invokes them in order after resolution completes.

#### Hook execution flow

```
1. __xcind-load-config
2. __xcind-resolve-files  →  resolved compose files & env files
3. __xcind-build-compose-opts  →  XCIND_DOCKER_COMPOSE_OPTS populated
4. ── post-resolve hooks ──
   for each hook in XCIND_HOOKS_POST_RESOLVE:
     output=$(hook "$app_root" "${resolved_compose_files[@]}")
     append $output to XCIND_DOCKER_COMPOSE_OPTS
5. exec docker compose "${XCIND_DOCKER_COMPOSE_OPTS[@]}" "$@"
```

---

## 5. `xcind-proxy` Command

### 5.1 Overview

`xcind-proxy` is a new executable (`bin/xcind-proxy`) that:

1. Resolves the current project's compose configuration (reuses xcind-lib).
2. Parses the resolved compose files to discover services and their exposed ports / labels.
3. Generates a `compose.proxy.yaml` that defines a Traefik reverse-proxy service and wires discovered services to it via labels.
4. Writes the generated file to `.xcind/generated/<sha>/compose.proxy.yaml`.

### 5.2 Service Discovery

xcind-proxy inspects each service in the resolved compose files for:

| Source | Example | Purpose |
|--------|---------|---------|
| `ports` | `"8080:80"` | Infer upstream port |
| `labels` | `xcind.proxy.host=app.local` | Explicit virtual-host routing |
| `labels` | `xcind.proxy.port=3000` | Override inferred port |
| `labels` | `xcind.proxy.enable=false` | Opt-out of proxy |

Services without ports and without explicit proxy labels are skipped.

### 5.3 Generated Compose File

The generated `compose.proxy.yaml` will:

- Define a `proxy` service running Traefik (or a configurable image).
- Attach it to all networks referenced by proxied services.
- Add routing labels to each proxied service (Traefik-style `traefik.http.routers.*` labels).
- Expose port 80 (and optionally 443) on the host.

### 5.4 CLI Interface

```
xcind-proxy [OPTIONS]

Options:
  --generate       Generate/regenerate the proxy compose file (default action)
  --clean          Remove .xcind/generated/ and .xcind/cache/
  --status         Show current proxy state (generated file path, staleness)
  --dry-run        Print the generated compose YAML to stdout without writing
  --help, -h       Show help
  --version, -V    Show version
```

### 5.5 Integration as a Hook

`xcind-proxy` ships a hook function, `xcind-proxy-hook`, that users register in `.xcind.sh`:

```bash
XCIND_HOOKS_POST_RESOLVE=("xcind-proxy-hook")
```

When invoked as a hook, `xcind-proxy-hook`:

1. Computes the SHA of the resolved compose files.
2. Checks if `.xcind/generated/<sha>/compose.proxy.yaml` is up-to-date.
3. If stale or missing, regenerates it (same logic as `xcind-proxy --generate`).
4. Prints `-f <path-to-generated-file>` to stdout.

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

---

## 7. Configuration in `.xcind.sh`

New optional variables:

```bash
# Hook registration (array of function/command names)
XCIND_HOOKS_POST_RESOLVE=()

# Proxy-specific settings (only relevant when xcind-proxy is in use)
XCIND_PROXY_IMAGE="traefik:v3"          # Proxy engine image
XCIND_PROXY_HTTP_PORT="80"              # Host port for HTTP
XCIND_PROXY_DASHBOARD="false"           # Enable Traefik dashboard
XCIND_PROXY_DEFAULT_DOMAIN="localhost"  # Default domain suffix
```

---

## 8. File & Directory Layout (after implementation)

```
<xcind repo>/
  bin/
    xcind-compose          # existing
    xcind-config           # existing
    xcind-proxy            # NEW — proxy command
  lib/xcind/
    xcind-lib.bash         # existing (extended with hook support)
    xcind-proxy-lib.bash   # NEW — proxy generation logic
  test/
    test-xcind.sh          # existing
    test-xcind-proxy.sh    # NEW — proxy tests
```

```
<user project>/
  .xcind.sh                # existing (+ optional hook registration)
  .xcind/                  # NEW
    cache/<sha>/
    generated/<sha>/
      compose.proxy.yaml
  compose.yaml             # user's compose file(s)
```

---

## 9. Open Questions

1. **SHA scope:** Should the SHA include env file contents too, or only compose files? Env files don't affect proxy routing, but they could affect variable expansion in compose files.

2. **Garbage collection:** Should old `<sha>` directories be cleaned up automatically? If so, what retention policy (keep N most recent, age-based, manual only)?

3. **Multi-proxy support:** Should we support generating configurations for multiple proxy engines (Traefik, Caddy, Nginx) from the start, or ship Traefik-only and extend later?

4. **Network creation:** Should xcind-proxy create a shared network or require the user to define one? Docker Compose's default per-project network may be sufficient for single-project use.

5. **Hook ordering guarantees:** If multiple hooks are registered, do they run in declared order? Can one hook's output influence another's input?

6. **Compose file parsing:** Pure bash YAML parsing is fragile. Should we require `yq` as a dependency, or shell out to `docker compose config` to get a normalized view of the resolved config?

---

## 10. Success Criteria

- [ ] `xcind-proxy --generate` produces a valid compose file that `docker compose config` accepts when combined with the user's files.
- [ ] The `post-resolve` hook integrates transparently — `xcind-compose up` starts the proxy alongside application services.
- [ ] SHA-based caching avoids regeneration when inputs haven't changed.
- [ ] Existing xcind workflows (no proxy, no hooks) are completely unaffected.
- [ ] Test coverage for hook execution, SHA computation, proxy generation, and cache invalidation.
