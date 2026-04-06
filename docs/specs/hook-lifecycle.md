# Hook Lifecycle

> Xcind's pipeline exposes hook phases that allow built-in and custom extensions to participate in configuration, generation, and execution.

---

## Overview

The xcind-compose pipeline processes an application's configuration through a series of phases. Each phase has a corresponding hook array where functions can be registered. Hooks are executed in registration order.

### Naming Convention

Hook phase names use **grammatical tense as a signal**:

- **Past tense** (`CONFIGURED`, `RESOLVED`) — "this already happened, react to it." These hooks observe or modify state produced by a preceding pipeline step.
- **Present tense** (`GENERATE`, `EXECUTE`) — "this is about to happen, do your part." These hooks actively perform work that is part of the phase itself.

---

## Pipeline and Hook Phases

```
xcind-compose pipeline
======================

  1.  Detect app root
  2.  Discover workspace
  3.  Source workspace additional configs
  4.  Load app config (.xcind.sh)
  5.  Source app additional configs
                │
          CONFIGURED ·············· react to loaded config
                │
  6.  Late-bind workspace
  7.  Resolve app name
  8.  Resolve URL templates
  9.  Resolve compose files
  10. Build compose opts
                │
          RESOLVED ················ react to resolved state
                │
  11. Compute SHA
  12. Export pipeline vars
  13. Populate cache
  14. Run generation hooks
                │
          GENERATE ················ produce compose overlays
                │
  15. Run execute hooks
                │
          EXECUTE ················· ensure runtime state
                │
  16. exec docker compose
```

---

## Phase Reference

### `CONFIGURED`

> **Status: Specified — not yet implemented.**

| | |
|---|---|
| **Array** | `XCIND_HOOKS_CONFIGURED` |
| **When** | After all `.xcind.sh` files are sourced (steps 3-5), before resolution (steps 6-10) |
| **Purpose** | Modify or augment configuration variables before they are resolved |
| **Cached** | No |
| **Consumers** | xcind-compose, xcind-config |

**Contract:**
- Hook signature: `hook_name "$app_root"`
- Hooks may read and modify exported pipeline variables (e.g., `XCIND_COMPOSE_FILES`, `XCIND_PROXY_EXPORTS`)
- No stdout contract — these hooks operate via side effects on shell variables
- Hooks run in the current shell (sourced), not in a subshell

**Use cases (hypothetical):**
- Injecting `XCIND_COMPOSE_FILES` entries based on external state
- Conditionally setting `XCIND_PROXY_EXPORTS` based on environment detection

---

### `RESOLVED`

> **Status: Specified — not yet implemented.**

| | |
|---|---|
| **Array** | `XCIND_HOOKS_RESOLVED` |
| **When** | After file resolution and compose opts are built (step 10), before SHA computation (step 11) |
| **Purpose** | Modify or extend compose options after resolution |
| **Cached** | No |
| **Consumers** | xcind-compose, xcind-config |

**Contract:**
- Hook signature: `hook_name "$app_root"`
- Hooks may read pipeline state and modify `XCIND_DOCKER_COMPOSE_OPTS`
- No stdout contract — these hooks operate via side effects
- Hooks run in the current shell (sourced), not in a subshell

**Use cases (hypothetical):**
- Appending additional `-f` flags based on resolved state
- Modifying compose options before the SHA is computed

---

### `GENERATE`

| | |
|---|---|
| **Array** | `XCIND_HOOKS_GENERATE` |
| **When** | During step 14, after SHA computation and cache population |
| **Purpose** | Produce Docker Compose overlay files |
| **Cached** | **Yes** — on cache hit, persisted stdout is replayed without re-executing hooks |
| **Consumers** | xcind-compose, xcind-config |

**Contract:**
- Hook signature: `hook_name "$app_root"`
- Hooks run in a **subshell** — variable side effects are not visible to the caller
- **stdout**: Print Docker Compose flags (e.g., `-f /path/to/overlay.yaml`). This output is captured, persisted to `.xcind/generated/{sha}/.hook-output-{name}`, and appended to `XCIND_DOCKER_COMPOSE_OPTS`
- **stderr**: Free for user-facing messages (not captured or cached)
- Hooks write generated files to `$XCIND_GENERATED_DIR`
- Hooks have access to `$XCIND_CACHE_DIR/resolved-config.yaml` for service enumeration

**Cache behavior:**
- On **cache miss**: Hook function is executed, stdout is persisted
- On **cache hit**: Persisted stdout is replayed; referenced `-f` files are validated. If a referenced file is missing, the cache is invalidated and hooks re-run
- Cache key: SHA-256 of compose files, config files, env files, proxy config, and XCIND_TOOLS

**Built-in hooks:**

| Hook | Generated file | Purpose |
|------|---------------|---------|
| `xcind-naming-hook` | `compose.naming.yaml` | Docker Compose project `name:` |
| `xcind-app-env-hook` | `compose.app-env.yaml` | Injects `XCIND_APP_ENV_FILES` via `env_file:` |
| `xcind-host-gateway-hook` | `compose.host-gateway.yaml` | Maps `host.docker.internal` via `extra_hosts` |
| `xcind-proxy-hook` | `compose.proxy.yaml` | Traefik labels, proxy network, context labels |
| `xcind-workspace-hook` | `compose.workspace.yaml` | Workspace network aliases |

**Important:** GENERATE hooks must be **pure generators** — no runtime side effects. Side effects (creating networks, starting services) belong in EXECUTE hooks. GENERATE hooks may be skipped entirely on cache hit.

---

### `EXECUTE`

| | |
|---|---|
| **Array** | `XCIND_HOOKS_EXECUTE` |
| **When** | After generation (step 15), immediately before `exec docker compose` |
| **Purpose** | Ensure runtime preconditions before Docker Compose runs |
| **Cached** | **No** — always runs on every invocation |
| **Consumers** | xcind-compose only (not xcind-config) |

**Contract:**
- Hook signature: `hook_name "$app_root"`
- Hooks run in the **current shell** — variable side effects are visible
- No stdout contract — output goes directly to the terminal
- Errors are **non-fatal** by convention — hooks should handle their own failures gracefully rather than aborting the pipeline
- Hooks should be **fast and idempotent** — they run on every invocation, including cached runs

**Built-in hooks:**

| Hook | Purpose |
|------|---------|
| `__xcind-proxy-execute-hook` | Ensure Traefik proxy is running (if `XCIND_PROXY_EXPORTS` is set) |
| `__xcind-workspace-execute-hook` | Ensure workspace network exists (if in workspace mode) |

**Why not in GENERATE?** Runtime state (running containers, existing networks) is independent of generated compose files. The generation cache should reflect config state, not runtime state. A stopped proxy doesn't mean the generated `compose.proxy.yaml` is wrong — it just means the proxy needs starting.

---

## xcind-config Behavior

`xcind-config` is a read-only introspection tool. It participates in:

- **CONFIGURED** — yes (if implemented)
- **RESOLVED** — yes (if implemented)
- **GENERATE** — yes (needs generated files for complete config output)
- **EXECUTE** — **no** (no Docker Compose execution happens)

---

## Custom Hooks

Hooks can be registered in `.xcind.sh` or additional config files:

```bash
# Add a custom GENERATE hook
my-custom-generate-hook() {
  local app_root="$1"
  # Write overlay to $XCIND_GENERATED_DIR
  echo "custom: true" > "$XCIND_GENERATED_DIR/compose.custom.yaml"
  # Print flags to stdout
  echo "-f $XCIND_GENERATED_DIR/compose.custom.yaml"
}
XCIND_HOOKS_GENERATE+=("my-custom-generate-hook")

# Add a custom EXECUTE hook
my-custom-execute-hook() {
  local app_root="$1"
  # Ensure some runtime dependency
  docker network create my-network 2>/dev/null || true
}
XCIND_HOOKS_EXECUTE+=("my-custom-execute-hook")
```

To disable all hooks for a phase:

```bash
XCIND_HOOKS_GENERATE=()   # skip all generation
XCIND_HOOKS_EXECUTE=()    # skip all runtime preparation
```

---

## Related Documents

- [Generated Override Files](./generated-override-files.md) — Details on generated compose overlays and merge order
- [Proxy Infrastructure](./proxy-infrastructure.md) — Proxy lifecycle and auto-start behavior
- [Architecture Overview](../architecture/overview.md) — System architecture and component relationships
- [Configuration Reference](../reference/configuration.md) — Hook array configuration
