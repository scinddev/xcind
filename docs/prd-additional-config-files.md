# PRD: Additional Config File Inclusion (`XCIND_ADDITIONAL_CONFIG_FILES`)

**Status:** Draft
**Author:** —
**Date:** 2026-03-26

---

## 1. Problem Statement

Xcind applications are configured via a single `.xcind.sh` file at the app root. As projects grow, teams need environment-specific overrides (dev vs. staging vs. production), machine-local tweaks, and shared workspace-level defaults — all without cluttering the base config.

Today, xcind supports environment-specific *compose* files and *env* files through array variables (`XCIND_COMPOSE_FILES`, `XCIND_ENV_FILES`) with variable expansion and automatic `.override` derivation. However, there is no equivalent mechanism for the `.xcind.sh` config files themselves. If a team wants different proxy exports, compose file lists, or workspace settings per environment, they must either:

- Cram conditional logic into `.xcind.sh`, or
- Maintain separate branches / symlinks

Neither scales well.

---

## 2. Goals

1. Allow `.xcind.sh` to declare **additional config scripts** that are sourced after the base config, enabling environment-specific and local overrides.
2. Apply the same `.override` derivation convention used for compose/env files (e.g., `.xcind.dev.sh` automatically checks for `.xcind.dev.override.sh`).
3. Support variable expansion in file patterns (e.g., `${APP_ENV:-dev}`), consistent with existing compose/env file resolution.
4. Support workspace-level `XCIND_ADDITIONAL_CONFIG_FILES` that are resolved relative to the workspace root and sourced before the app config.
5. Include additional config files in SHA computation for cache invalidation.
6. Surface the full config file chain in `xcind-config` JSON output.

## 3. Non-Goals (for v1)

- Recursive/chained inclusion (additional configs declaring further additional configs) — see Section 8, Known Issues.
- Suppression mechanism for apps to prevent workspace-level additional configs from being sourced.
- Strict mode or warnings for missing additional config files.
- Additional config file support for the global proxy config (`~/.config/xcind/proxy/config.sh`).

---

## 4. Design

### 4.1 New Variable: `XCIND_ADDITIONAL_CONFIG_FILES`

A new bash array variable that lists additional `.xcind.*.sh` scripts to source after the declaring config file. Unlike `XCIND_COMPOSE_FILES` or `XCIND_ENV_FILES` (which represent the *complete* list of files), this variable specifies only *additional* files — the base `.xcind.sh` is always sourced implicitly and should not be listed.

**Example `.xcind.sh`:**

```bash
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.${APP_ENV:-dev}.sh")
XCIND_ENV_FILES=(".env" ".env.${APP_ENV:-dev}" ".env.local")
XCIND_COMPOSE_FILES=("compose.yaml" "compose.${APP_ENV:-dev}.yaml")
XCIND_PROXY_EXPORTS=("nginx")
```

With `APP_ENV=dev`, this causes xcind to look for and source (if they exist):

1. `.xcind.dev.sh` — the additional config
2. `.xcind.dev.override.sh` — its automatically derived override variant

These files can override or extend any variable set by the base `.xcind.sh`, including `XCIND_COMPOSE_FILES`, `XCIND_ENV_FILES`, `XCIND_PROXY_EXPORTS`, etc.

### 4.2 Resolution Rules

For each entry in `XCIND_ADDITIONAL_CONFIG_FILES`:

1. **Variable expansion:** Apply the same `eval echo` mechanism used for compose/env file patterns. This supports both immediate expansion (double-quoted entries expand when `.xcind.sh` is sourced) and deferred expansion (single-quoted entries expand at resolution time).
2. **Relative path resolution:** Relative paths are resolved against the directory of the config that declared them — workspace root for workspace-level declarations, app root for app-level declarations.
3. **Existence check:** If the resolved file does not exist, skip it silently. Additional configs are optional by convention.
4. **Override derivation:** For each resolved file that exists, derive the `.override` variant using the existing `__xcind-derive-override` logic. For `.sh` files (no recognized config extension), this appends `.override` — e.g., `.xcind.dev.sh` → `.xcind.dev.override.sh`. If the override file exists, source it immediately after the base additional config.
5. **Sourcing:** Files are sourced in the current shell (same as `.xcind.sh`), so all variable assignments take effect in the calling context.

### 4.3 Sourcing Order

The complete config sourcing pipeline becomes:

```
1. __xcind-app-root                → locate XCIND_APP_ROOT

2. __xcind-discover-workspace      → workspace discovery
   if dirname(XCIND_APP_ROOT)/.xcind.sh exists and declares XCIND_IS_WORKSPACE=1:
     XCIND_WORKSPACE_ROOT = dirname(XCIND_APP_ROOT)
     source XCIND_WORKSPACE_ROOT/.xcind.sh

3. __xcind-source-additional-configs  → workspace additional configs   [NEW]
   if XCIND_ADDITIONAL_CONFIG_FILES is non-empty:
     for each pattern in XCIND_ADDITIONAL_CONFIG_FILES:
       expand variables, resolve relative to XCIND_WORKSPACE_ROOT
       if file exists: source it
       if override exists: source override

4. __xcind-load-config             → source XCIND_APP_ROOT/.xcind.sh
   (sets defaults for XCIND_COMPOSE_FILES, etc. if not already defined)

5. __xcind-source-additional-configs  → app additional configs         [NEW]
   resolve XCIND_ADDITIONAL_CONFIG_FILES (as set after step 4)
   relative to XCIND_APP_ROOT
   (same expansion + override logic as step 3)

6. __xcind-late-bind-workspace     → late-bind self-declaration
7. __xcind-resolve-app             → set XCIND_APP
8. __xcind-resolve-url-templates   → set URL templates
9. __xcind-build-compose-opts      → resolve files, build compose flags
── steps 10-13 only run if hooks are registered ──
10. __xcind-compute-sha            → includes additional config file hashes
11. export pipeline vars
12. __xcind-populate-cache
13. __xcind-run-hooks
──────────────────────────────────────────────────
14. exec docker compose ...
```

**Key property:** Workspace additional configs (step 3) are sourced *before* the app's `.xcind.sh` (step 4). This means the app config can override anything set by workspace-level additional configs, preserving the existing "app overrides workspace" hierarchy.

**Inheritance:** If the app's `.xcind.sh` does not set `XCIND_ADDITIONAL_CONFIG_FILES`, it inherits the workspace value. The inherited patterns are then resolved relative to the app root in step 5. This enables a workspace to declare "every app should load `.xcind.dev.sh`" while each app provides its own environment-specific config.

### 4.4 Variable Expansion

Additional config file patterns support the same dual expansion modes as compose/env files:

| Quote Style | Expansion Timing | Example | Resolves To |
|---|---|---|---|
| Double quotes | Immediate (when `.xcind.sh` is sourced) | `".xcind.${APP_ENV:-dev}.sh"` | `.xcind.dev.sh` (at source time) |
| Single quotes | Deferred (at resolution time via `eval`) | `'.xcind.${APP_ENV:-dev}.sh'` | `.xcind.dev.sh` (at resolution time) |

Deferred expansion is useful when a prior config file sets the variable that the pattern depends on. Since `.xcind.sh` is already sourced (which is effectively `eval` on the entire file), `eval echo` for pattern expansion does not meaningfully increase the attack surface.

### 4.5 Workspace-Level Additional Configs

Workspace `.xcind.sh` files can declare `XCIND_ADDITIONAL_CONFIG_FILES`. These are resolved relative to the workspace root and sourced before any app-level config.

**Example workspace `.xcind.sh`:**

```bash
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.${APP_ENV:-dev}.sh")
```

**Example workspace `.xcind.dev.sh`:**

```bash
# Workspace-wide dev defaults
XCIND_PROXY_DOMAIN="dev.localhost"
```

With this setup:

1. Workspace `.xcind.sh` is sourced → sets `XCIND_ADDITIONAL_CONFIG_FILES`
2. `.xcind.dev.sh` is resolved relative to workspace root, sourced if exists → overrides `XCIND_PROXY_DOMAIN`
3. `.xcind.dev.override.sh` checked relative to workspace root, sourced if exists
4. App `.xcind.sh` is sourced → can override anything
5. App-level additional configs resolved relative to app root

### 4.6 Override Derivation

The existing `__xcind-derive-override` function handles `.sh` files via the catch-all case:

```
.xcind.dev.sh → .xcind.dev.override.sh    (appends .override)
.xcind.local.sh → .xcind.local.override.sh
```

No changes to `__xcind-derive-override` are needed.

---

## 5. Impact on SHA Computation

`__xcind-compute-sha` currently includes:

- Compose file paths and content hashes
- App `.xcind.sh` content hash
- Workspace `.xcind.sh` content hash (if in workspace mode)
- Global proxy config content hash (if exists)

**Change:** After additional config files are sourced, their resolved paths and content hashes must be appended to the SHA input. This includes both the base additional config and its override variant (if sourced).

The additional config files should be tracked in a new array (e.g., `__XCIND_SOURCED_CONFIG_FILES`) populated during the sourcing step, so `__xcind-compute-sha` can iterate over them.

---

## 6. Impact on `xcind-config` JSON Output

### 6.1 Config Files

Add a new `configFiles` field to the JSON output that lists all sourced config files in order:

```json
{
  "appRoot": "/path/to/app",
  "configFiles": [
    "/path/to/workspace/.xcind.sh",
    "/path/to/workspace/.xcind.dev.sh",
    "/path/to/app/.xcind.sh",
    "/path/to/app/.xcind.dev.sh",
    "/path/to/app/.xcind.dev.override.sh"
  ],
  "composeFiles": [...],
  "envFiles": [...],
  "bakeFiles": [...]
}
```

Only files that were actually sourced (i.e., existed on disk) appear in the array. The order reflects the sourcing order.

### 6.2 Metadata

Add a `metadata` object with key identifiers:

```json
{
  "metadata": {
    "workspace": "dev",
    "app": "acmeapps",
    "workspaceless": false
  },
  "appRoot": "/path/to/app",
  "configFiles": [...],
  "composeFiles": [...],
  "envFiles": [...],
  "bakeFiles": [...]
}
```

When no workspace is detected, `workspace` is `null` and `workspaceless` is `true`.

---

## 7. Implementation Notes

### 7.1 New Function: `__xcind-source-additional-configs`

```
__xcind-source-additional-configs <base_dir>
```

- Reads `XCIND_ADDITIONAL_CONFIG_FILES` array
- For each entry: expand variables via `eval echo`, resolve relative to `base_dir`
- If file exists: source it, append path to `__XCIND_SOURCED_CONFIG_FILES`
- Derive override via `__xcind-derive-override`; if override exists: source it, append path

### 7.2 Integration Points

| File | Change |
|---|---|
| `lib/xcind/xcind-lib.bash` | Add `__xcind-source-additional-configs` function; update `__xcind-load-config` to set default for `XCIND_ADDITIONAL_CONFIG_FILES`; update `__xcind-compute-sha` to include sourced config file hashes; update `__xcind-resolve-json` to include `configFiles` and `metadata` |
| `bin/xcind-compose` | Call `__xcind-source-additional-configs` at workspace and app stages (steps 3 and 5) |
| `bin/xcind-config` | Call `__xcind-source-additional-configs` at workspace and app stages; output `configFiles` and `metadata` in JSON and `--files` modes |

### 7.3 Tracking Sourced Files

Introduce an internal array `__XCIND_SOURCED_CONFIG_FILES=()` that accumulates the absolute paths of all config files actually sourced. This array is:

- Populated by `__xcind-discover-workspace` (workspace `.xcind.sh`)
- Populated by `__xcind-source-additional-configs` (workspace + app additional configs)
- Populated by `__xcind-load-config` (app `.xcind.sh`)
- Read by `__xcind-compute-sha` for cache invalidation
- Read by `__xcind-resolve-json` for JSON output

---

## 8. Known Issues and Open Questions

### 8.1 Recursive Inclusion (Undefined Behavior)

If an additional config file (e.g., `.xcind.dev.sh`) modifies `XCIND_ADDITIONAL_CONFIG_FILES`, the behavior is **undefined**. The sourcing function reads the array once at invocation time; mutations during iteration may or may not be observed depending on bash's array expansion semantics. For v1, only the base `.xcind.sh` (or workspace `.xcind.sh`) should be considered a reliable place to declare `XCIND_ADDITIONAL_CONFIG_FILES`.

### 8.2 Workspace Additional Configs and App Inheritance

When a workspace declares `XCIND_ADDITIONAL_CONFIG_FILES` and an app inherits it, the same file patterns are resolved against both the workspace root (step 3) and the app root (step 5). This is intentional — it allows workspace-wide defaults with per-app overrides. However, it means a file like `.xcind.dev.sh` could be sourced twice (once from each root) if both exist. Each sourcing is independent and the app-level sourcing runs later, so app values win.

### 8.3 Workspace Directory Additional Configs

The current design applies additional config sourcing at both workspace and app levels. Future iterations may need to consider whether workspace-only additional configs (that should not cascade to apps) require a separate mechanism.

---

## 9. Examples

### 9.1 Basic: Environment-Specific Config

**`.xcind.sh`:**

```bash
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.${APP_ENV:-dev}.sh")
XCIND_ENV_FILES=(".env" ".env.${APP_ENV:-dev}" ".env.local")
XCIND_COMPOSE_FILES=("compose.yaml" "compose.${APP_ENV:-dev}.yaml")
XCIND_PROXY_EXPORTS=("nginx")

XCIND_WORKSPACE="$([ -f ".xcind-workspace" ] && [ -r ".xcind-workspace" ] && cat ".xcind-workspace")"
```

**`.xcind.dev.sh`:**

```bash
# Dev-specific overrides
XCIND_COMPOSE_FILES=("compose.yaml" "compose.dev.yaml" "compose.dev-tools.yaml")
```

**`.xcind.dev.override.sh`** (gitignored, machine-local):

```bash
# Local dev tweaks — not committed
XCIND_PROXY_EXPORTS=("nginx" "mailhog")
```

### 9.2 Workspace with Shared Defaults

**Workspace `.xcind.sh`:**

```bash
XCIND_IS_WORKSPACE=1
XCIND_PROXY_DOMAIN="xcind.localhost"
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.${APP_ENV:-dev}.sh")
```

**Workspace `.xcind.dev.sh`:**

```bash
XCIND_PROXY_DOMAIN="dev.localhost"
```

**App `.xcind.sh`** (does not override `XCIND_ADDITIONAL_CONFIG_FILES` — inherits workspace value):

```bash
XCIND_COMPOSE_FILES=("compose.yaml")
XCIND_PROXY_EXPORTS=("web")
```

**App `.xcind.dev.sh`** (resolved relative to app root via inherited pattern):

```bash
XCIND_COMPOSE_FILES=("compose.yaml" "compose.dev.yaml")
```

**Sourcing order:**

1. `workspace/.xcind.sh` → sets proxy domain, declares additional configs
2. `workspace/.xcind.dev.sh` → overrides proxy domain for dev
3. `app/.xcind.sh` → sets compose files and proxy exports
4. `app/.xcind.dev.sh` → overrides compose files for dev

### 9.3 App Overriding Workspace Additional Configs

**Workspace `.xcind.sh`:**

```bash
XCIND_IS_WORKSPACE=1
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.${APP_ENV:-dev}.sh")
```

**App `.xcind.sh`:**

```bash
# This app uses a different pattern
XCIND_ADDITIONAL_CONFIG_FILES=(".xcind.local.sh")
XCIND_COMPOSE_FILES=("compose.yaml")
```

**Sourcing order:**

1. `workspace/.xcind.sh` → declares additional configs
2. `workspace/.xcind.dev.sh` → sourced if exists (workspace-level)
3. `app/.xcind.sh` → overrides `XCIND_ADDITIONAL_CONFIG_FILES`
4. `app/.xcind.local.sh` → sourced if exists (app-level, using app's override)
