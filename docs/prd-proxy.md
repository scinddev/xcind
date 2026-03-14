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
XCIND_HOOKS_POST_RESOLVE_GENERATE=("xcind-proxy-hook")
```

When invoked as a hook (cache miss only), `xcind-proxy-hook`:

1. Reads `$XCIND_CACHE_DIR/resolved-config.yaml` to discover services, their exposed ports, and proxy labels.
2. Generates `compose.proxy.yaml` in `$XCIND_GENERATED_DIR/`.
3. Prints `-f $XCIND_GENERATED_DIR/compose.proxy.yaml` to stdout.

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

## 7. Configuration in `.xcind.sh`

New optional variables:

```bash
# Hook registration (array of function/command names)
XCIND_HOOKS_POST_RESOLVE_GENERATE=()

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
- [ ] The `post-resolve-generate` hook integrates transparently — `xcind-compose up` starts the proxy alongside application services.
- [ ] SHA-based caching avoids regeneration when inputs haven't changed.
- [ ] Existing xcind workflows (no proxy, no hooks) are completely unaffected.
- [ ] Test coverage for hook execution, SHA computation, proxy generation, and cache invalidation.
