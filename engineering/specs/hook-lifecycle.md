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
- On **cache miss**: The generated directory is rebuilt atomically — any prior contents are removed, hooks run in registration order with their stdout persisted to `.hook-output-{name}`, and a `.complete` marker (containing the registered hook list for diagnostics) is written only after every hook succeeds. If any hook fails, the partial directory is removed before the error propagates so the next invocation rebuilds from scratch.
- On **cache hit**: The hit is accepted only when the `.complete` marker exists **and** every hook currently registered in `XCIND_HOOKS_GENERATE` has a persisted `.hook-output-{name}` file. A missing marker, missing per-hook output, or a hook newly added to the array forces a full rebuild rather than a partial replay. For each registered hook, persisted stdout is replayed and referenced `-f` files are validated; if a referenced file is missing, the cache is invalidated and hooks re-run.
- **Always-run hooks** (`XCIND_HOOKS_ALWAYS`, currently `xcind-assigned-hook` and `xcind-discovery-hook`): hooks listed here stay in `XCIND_HOOKS_GENERATE` for ordering, marker, and completeness purposes, but on a cache hit they are re-executed against current live state instead of replaying from `.hook-output-{name}`. Their persisted output is refreshed so a future run that drops them from `XCIND_HOOKS_ALWAYS` still sees current state. This exists for hooks whose output depends on state outside the SHA inputs (assigned-port TSV, port availability) that would otherwise drift from the cached overlay. `xcind-discovery-hook` is included because its assigned `*_HOST_PORT` variables embed those same live-allocated host ports.
- **Cache key inputs**: SHA-256 over compose files (paths + content), compose env files (`XCIND_COMPOSE_ENV_FILES`), app env files (`XCIND_APP_ENV_FILES`), app `.xcind.sh`, workspace `.xcind.sh` (workspace mode), additional config files plus their `.override.sh` siblings (every path tracked in `__XCIND_SOURCED_CONFIG_FILES`), the global proxy config under `${XDG_CONFIG_HOME}/xcind/proxy/config.sh`, `XCIND_TOOLS` declarations, the literal naming inputs (`XCIND_APP`, `XCIND_WORKSPACE`, `XCIND_WORKSPACELESS`), the per-worktree isolation token `XCIND_INSTANCE` (only when set — empty on the main checkout, so its SHA is byte-identical to pre-instance builds while each linked worktree gets its own cache/generated dirs), the host-gateway configuration variables (`XCIND_HOST_GATEWAY_ENABLED`, `XCIND_HOST_GATEWAY`), and — when host-gateway is enabled — the runtime-detected host-gateway value from `__xcind-detect-host-gateway`. See [Generated Override Files: Caching](./generated-override-files.md#caching) for the full list.
- **Sibling cache artifacts**: `__xcind-populate-cache` writes `resolved-config.yaml` *before* hooks so they can enumerate services. `__xcind-write-cache-config-json` writes `config.json` *after* `__xcind-run-hooks` so the cached JSON reflects post-hook state (notably `assignedExports`). The JSON write goes through a `.tmp` sidecar and `mv` and is a no-op when `jq` is unavailable.

**Built-in hooks:**

| Hook | Generated file | Purpose | Missing `yq` |
|------|---------------|---------|--------------|
| `xcind-naming-hook` | `compose.naming.yaml` | Docker Compose project `name:` | n/a (no `yq` dependency) |
| `xcind-app-hook` | `compose.app.yaml` | App context labels for all services | Soft-skip |
| `xcind-app-env-hook` | `compose.app-env.yaml` | Injects `XCIND_APP_ENV_FILES` via `env_file:` | Hard-fail |
| `xcind-host-gateway-hook` | `compose.host-gateway.yaml` | Maps `host.docker.internal` via `extra_hosts` | Soft-skip |
| `xcind-proxy-hook` | `compose.proxy.yaml` | Traefik labels, proxy network attachment, export labels | Hard-fail |
| `xcind-assigned-hook` | `compose.assigned.yaml` | Stable host port bindings with flock-serialized state | Hard-fail |
| `xcind-workspace-hook` | `compose.workspace.yaml` | Workspace network aliases and context labels | Soft-skip |
| `xcind-discovery-hook` | `compose.discovery.yaml` | Service-discovery `environment:` vars for all services | Soft-skip |

**`yq` availability policy:** `yq` is a required dependency overall (see
[tech stack](../implementation/tech-stack.md)), and `xcind-config --check`
will flag it as missing. As defense-in-depth for users who bypass the
dependency check, default-registered GENERATE hooks fall into two categories
when `yq` is nevertheless absent at runtime:

- **Soft-skip** — the hook is a no-op that returns `0`, records itself in a
  run-level skipped-hook list, and lets the pipeline continue. All
  soft-skipping hooks are default-enabled and produce
  *non-load-bearing* output (identity labels, workspace DNS aliases, host
  gateway wiring). `__xcind-run-hooks` emits one consolidated warning at the
  end of the run listing every hook that skipped.
- **Hard-fail** — the hook prints an error to stderr and returns `1`, which
  aborts the pipeline. All hard-failing hooks are either opt-in (triggered
  by a user-set variable like `XCIND_PROXY_EXPORTS` or `XCIND_APP_ENV_FILES`)
  or produce *load-bearing* output whose absence would silently break
  routing, env injection, or port stability.

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
| `__xcind-hostenv-execute-hook` | Write the host-view env file with host-flavored discovery vars (opt-in via `XCIND_HOST_ENV_FILE`; runs after assigned-port allocation) |

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
