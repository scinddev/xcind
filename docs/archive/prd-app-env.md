# PRD: Application-Level Environment Files

**Status:** Draft
**Author:** —
**Date:** 2026-03-26
**Depends on:** [PRD: xcind-proxy](archive/prd-proxy.md) (hook system)

---

## 1. Problem Statement

Docker Compose has two completely separate scopes for environment files, and confusing them is one of the most common Docker Compose pitfalls ([docker/compose#9135](https://github.com/docker/compose/issues/9135)):

| | Compose-level (`--env-file`) | Container-level (`env_file:`) |
|---|---|---|
| **What it does** | Variable substitution in compose YAML (`${VAR}`) | Injects vars into running containers |
| **Where configured** | CLI flag or `COMPOSE_ENV_FILES` env var | `env_file:` directive in compose service definition |
| **Scope** | Compose process only | Container runtime only |

Today, `XCIND_ENV_FILES` configures files passed as `--env-file` to `docker compose`. The name suggests these files will be available to the application, but they are **not** — they are only used for YAML interpolation. There is no mechanism to declare environment files that should be injected into containers.

This PRD:
1. Renames `XCIND_ENV_FILES` to `XCIND_COMPOSE_ENV_FILES` to make the scope explicit.
2. Introduces `XCIND_APP_ENV_FILES` for container-level environment file injection via a new hook.

### Community Context

Research into the Docker Compose ecosystem shows:
- **No standard naming convention exists.** The community uses informal terms: "compose-level" vs "service-level" or "container-level." The best taxonomy (vsupalov.com) uses "compose-template scope" vs "container-runtime scope."
- **Very few tools attempt automatic injection.** DDEV generates `environment:` entries in compose files via Go templates. Lando passes `env_file` from its config into compose `env_file:` directives. Coolify distinguishes "build variables" (compose-level) from "runtime variables" (container-level) with separate UI toggles.
- **Docker Compose itself** has a `COMPOSE_ENV_FILES` env var for compose-level files and a rejected proposal for a `--container-env-file` flag ([moby#47876](https://github.com/moby/moby/issues/47876)).

---

## 2. Goals

1. Make the distinction between compose-level and container-level env files explicit through naming.
2. Provide a mechanism for injecting env files into all container services via `XCIND_APP_ENV_FILES`.
3. Maintain backward compatibility for existing `XCIND_ENV_FILES` usage.
4. Follow the existing hook pattern (workspace, proxy) for the implementation.

## 3. Non-Goals

- Per-service env file targeting (inject into specific services only). All services receive the same files, consistent with how workspace and proxy hooks operate.
- Parsing env file contents. The generated override references files via Docker Compose's `env_file:` directive; Docker Compose handles parsing.
- Replacing or modifying Docker Compose's native `env_file:` support. Users can still use `env_file:` in their compose files directly — the generated entries are additive.

---

## 4. Design

### 4.1 Rename: `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES`

All references to `XCIND_ENV_FILES` are renamed to `XCIND_COMPOSE_ENV_FILES`. The semantics are identical — these files are passed as `--env-file` flags to the `docker compose` CLI for YAML variable interpolation.

#### Backward Compatibility Shim

In `__xcind-load-config`, after sourcing `.xcind.sh`, add a migration check:

```bash
# BC shim: migrate XCIND_ENV_FILES → XCIND_COMPOSE_ENV_FILES
if [[ -z ${XCIND_COMPOSE_ENV_FILES+set} ]] && [[ -n ${XCIND_ENV_FILES+set} ]]; then
  XCIND_COMPOSE_ENV_FILES=("${XCIND_ENV_FILES[@]}")
  echo "xcind: warning: XCIND_ENV_FILES is deprecated, use XCIND_COMPOSE_ENV_FILES instead" >&2
fi
```

This runs after `source "$app_root/.xcind.sh"` so it catches user-defined values. The shim:
- Only activates when `XCIND_COMPOSE_ENV_FILES` is **not** set but `XCIND_ENV_FILES` **is** set.
- Copies the old array value to the new variable name.
- Emits a deprecation warning to stderr (visible in terminal, does not interfere with stdout-based hook output).

The default assignment changes from:

```bash
if [[ -z ${XCIND_ENV_FILES+set} ]]; then
  XCIND_ENV_FILES=(".env")
fi
```

To:

```bash
if [[ -z ${XCIND_COMPOSE_ENV_FILES+set} ]]; then
  XCIND_COMPOSE_ENV_FILES=(".env")
fi
```

### 4.2 New Variable: `XCIND_APP_ENV_FILES`

A new bash array variable that lists environment file patterns to inject into **all container services** via Docker Compose's `env_file:` directive.

```bash
# In .xcind.sh
XCIND_APP_ENV_FILES=(".env" ".env.local")
```

**Default:** empty array `()` — no app-level env files are injected unless explicitly configured.

Resolution follows the same rules as `XCIND_COMPOSE_ENV_FILES`:
1. Patterns support shell variable expansion (e.g., `.env.${APP_ENV}`)
2. Each expanded pattern is checked for existence
3. For each file found, an `.override` variant is also checked
4. All resolved files are collected in order

This reuses the existing `__xcind-resolve-files` function.

### 4.3 New Hook: `xcind-app-env-hook`

A new hook function, following the same pattern as `xcind-workspace-hook` and `xcind-proxy-hook`. It generates a `compose.app-env.yaml` override file that adds `env_file:` entries to every service.

#### Implementation File

`lib/xcind/xcind-app-env-lib.bash` — auto-sourced by `xcind-lib.bash`, registered as a default hook.

#### Hook Logic

```bash
xcind-app-env-hook() {
  local app_root="$1"

  # Skip when no app env files are configured (guard against unset under set -u)
  if [[ -z ${XCIND_APP_ENV_FILES+set} || ${#XCIND_APP_ENV_FILES[@]} -eq 0 ]]; then
    return 0
  fi

  # Resolve app env files to absolute paths
  local resolved_files=()
  local f
  while IFS= read -r f; do
    resolved_files+=("$f")
  done < <(__xcind-resolve-files "$app_root" ${XCIND_APP_ENV_FILES[@]+"${XCIND_APP_ENV_FILES[@]}"})

  # Skip if no files resolved
  if [[ ${#resolved_files[@]} -eq 0 ]]; then
    return 0
  fi

  # Require yq for service enumeration
  if ! command -v yq &>/dev/null; then
    echo "Error: yq is required for app-env hook but was not found." >&2
    return 1
  fi

  local resolved_config="$XCIND_CACHE_DIR/resolved-config.yaml"

  # Enumerate all compose services
  local services
  services=$(yq -r '.services | keys | .[]' "$resolved_config" 2>/dev/null)

  if [ -z "$services" ]; then
    return 0
  fi

  # Build env_file YAML list
  local env_file_yaml=""
  for f in "${resolved_files[@]}"; do
    env_file_yaml+=$'\n'"      - $f"
  done

  # Build output
  local output="services:"
  local service_name
  while IFS= read -r service_name; do
    [ -z "$service_name" ] && continue
    output+=$'\n\n'"  ${service_name}:"
    output+=$'\n'"    env_file:${env_file_yaml}"
  done <<<"$services"

  output+=$'\n'

  # Write to generated dir
  echo "$output" >"$XCIND_GENERATED_DIR/compose.app-env.yaml"

  # Print compose flag to stdout (hook contract)
  echo "-f $XCIND_GENERATED_DIR/compose.app-env.yaml"
}
```

#### Generated Output Example

For an app with `XCIND_APP_ENV_FILES=(".env" ".env.local")` where both files exist, and compose services `web` and `worker`:

```yaml
services:

  web:
    env_file:
      - /path/to/app/.env
      - /path/to/app/.env.local

  worker:
    env_file:
      - /path/to/app/.env
      - /path/to/app/.env.local
```

Paths are **absolute** because the generated override lives in `.xcind/generated/{SHA}/` while the env files live in the app root. Absolute paths avoid ambiguity in Docker Compose's path resolution.

#### Merge Behavior

Docker Compose **appends** `env_file:` lists when merging override files. If the user's base compose file already has `env_file:` entries on a service, the generated entries are added after them. Later entries take precedence for duplicate keys, per Docker Compose's [precedence rules](https://docs.docker.com/compose/how-tos/environment-variables/envvars-precedence/).

### 4.4 Hook Registration

The hook is registered in the default hooks array alongside the existing hooks:

```bash
XCIND_HOOKS_POST_RESOLVE_GENERATE=(
  "xcind-app-env-hook"
  "xcind-proxy-hook"
  "xcind-workspace-hook"
)
```

The app-env hook runs **first** so that its generated compose file is loaded before proxy and workspace overrides. This ensures env files are available as a base layer.

### 4.5 SHA Computation Update

The SHA computation (used for cache invalidation) must include both compose env file and app env file content so that changes to any env file trigger hook re-execution. Add to the SHA inputs:

- Resolved `XCIND_COMPOSE_ENV_FILES` file paths and content hashes
- Resolved `XCIND_APP_ENV_FILES` file paths and content hashes

Compose env files affect `docker compose config` output (YAML interpolation), so changes to them can produce stale `resolved-config.yaml` — they must be included alongside compose file content. App env files affect the generated `compose.app-env.yaml` override, so their content must also be tracked.

This mirrors how compose file content is already included in the SHA.

### 4.6 JSON Contract Update

`__xcind-resolve-json` (used by `xcind-config` and the JetBrains plugin) adds two new fields. The existing `envFiles` key is renamed to `composeEnvFiles`, and a new `appEnvFiles` field is added:

```json
{
  "appRoot": "/path/to/app",
  "composeFiles": ["..."],
  "composeEnvFiles": ["/path/to/app/.env"],
  "appEnvFiles": ["/path/to/app/.env", "/path/to/app/.env.local"],
  "bakeFiles": ["..."]
}
```

The rename from `envFiles` → `composeEnvFiles` is a breaking contract change. Clients (including the JetBrains plugin) must be updated to read `composeEnvFiles` instead of `envFiles`.

---

## 5. Impact on Existing Code

### 5.1 `lib/xcind/xcind-lib.bash`

| Function | Change |
|----------|--------|
| `__xcind-load-config` | Rename default from `XCIND_ENV_FILES` to `XCIND_COMPOSE_ENV_FILES`. Add BC shim after sourcing `.xcind.sh`. Add default for `XCIND_APP_ENV_FILES=()`. |
| `__xcind-build-compose-opts` | Change `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` in the `--env-file` resolution loop. |
| `__xcind-resolve-json` | Rename `envFiles` key to `composeEnvFiles`. Add `appEnvFiles` key. |
| Comment block (lines 89-96) | Update variable documentation to list `XCIND_COMPOSE_ENV_FILES` and `XCIND_APP_ENV_FILES`. |

### 5.2 `bin/xcind-config`

Line 169 (`__xcind-resolve-files "$app_root" "${XCIND_ENV_FILES[@]}"`) changes to use `XCIND_COMPOSE_ENV_FILES`. Add a second block for app env files:

```bash
echo "# Compose env files:"
__xcind-resolve-files "$app_root" "${XCIND_COMPOSE_ENV_FILES[@]}"

echo "# App env files:"
__xcind-resolve-files "$app_root" ${XCIND_APP_ENV_FILES[@]+"${XCIND_APP_ENV_FILES[@]}"}
```

### 5.3 `test/test-xcind.sh`

All references to `XCIND_ENV_FILES` in test assertions and setup are renamed to `XCIND_COMPOSE_ENV_FILES`. New test cases added:

- BC shim: verify `XCIND_ENV_FILES` is migrated to `XCIND_COMPOSE_ENV_FILES` with warning.
- `XCIND_APP_ENV_FILES` defaults to empty array.
- `XCIND_APP_ENV_FILES` resolution produces correct absolute paths.
- App-env hook generates correct `compose.app-env.yaml` for multiple services.
- App-env hook is a no-op when `XCIND_APP_ENV_FILES` is empty.

### 5.4 Examples

All `.xcind.sh` files in `examples/` are updated:

| File | Change |
|------|--------|
| `examples/workspaceless/acmeapps/.xcind.sh` | `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` |
| `examples/workspaceless/advanced/.xcind.sh` | `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` |
| `examples/workspaces/dev/backend/.xcind.sh` | `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` |
| `examples/workspaces/dev/frontend/.xcind.sh` | `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` |

### 5.5 `README.md`

Update the Configuration Reference section:
- Rename `XCIND_ENV_FILES` heading to `XCIND_COMPOSE_ENV_FILES`.
- Add `XCIND_APP_ENV_FILES` heading with description.
- Add a note about the distinction between the two.

### 5.6 Other PRDs

Update references in `docs/prd-additional-config-files.md` (lines 13, 44, 50, 60, 290) from `XCIND_ENV_FILES` to `XCIND_COMPOSE_ENV_FILES`.

---

## 6. Variable Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `XCIND_COMPOSE_ENV_FILES` | bash array | `(".env")` | Env file patterns for Docker Compose YAML interpolation. Passed as `--env-file` flags. |
| `XCIND_APP_ENV_FILES` | bash array | `()` | Env file patterns injected into all container services via `env_file:` directive. |
| `XCIND_ENV_FILES` | bash array | *(deprecated)* | Legacy name for `XCIND_COMPOSE_ENV_FILES`. Migrated automatically with a warning. |

---

## 7. Examples

### 7.1 Compose-Only (Current Behavior, Renamed)

```bash
# .xcind.sh — only compose-level interpolation
XCIND_COMPOSE_ENV_FILES=(".env" ".env.local")
XCIND_COMPOSE_FILES=("compose.yaml")
```

Behavior: `.env` and `.env.local` are passed as `--env-file` to `docker compose`. Variables like `${DB_IMAGE}` in `compose.yaml` are interpolated. Containers do **not** see these variables.

### 7.2 App-Level Injection

```bash
# .xcind.sh — inject env files into containers
XCIND_COMPOSE_ENV_FILES=(".env")
XCIND_APP_ENV_FILES=(".env" ".env.local")
XCIND_COMPOSE_FILES=("compose.yaml")
```

Behavior:
- `.env` is passed as `--env-file` for YAML interpolation.
- `.env` and `.env.local` are injected into every service via `env_file:` in the generated `compose.app-env.yaml`.
- Containers **can** read `DATABASE_URL`, `API_KEY`, etc. from these files.

### 7.3 Environment-Specific App Env Files

```bash
# .xcind.sh
XCIND_COMPOSE_ENV_FILES=(".env" '.env.${APP_ENV}')
XCIND_APP_ENV_FILES=(".env.app" '.env.app.${APP_ENV}')
XCIND_COMPOSE_FILES=("compose.yaml" 'compose.${APP_ENV}.yaml')
```

With `APP_ENV=staging`:
- Compose-level: `.env`, `.env.staging` (+ `.override` variants if they exist)
- App-level: `.env.app`, `.env.app.staging` (+ `.override` variants if they exist)

### 7.4 Backward Compatibility

```bash
# .xcind.sh — old-style config (still works)
XCIND_ENV_FILES=(".env" ".env.local")
```

Behavior:
- `XCIND_ENV_FILES` is migrated to `XCIND_COMPOSE_ENV_FILES` automatically.
- Warning printed to stderr: `xcind: warning: XCIND_ENV_FILES is deprecated, use XCIND_COMPOSE_ENV_FILES instead`
- No app-level injection (default `XCIND_APP_ENV_FILES` is empty).

### 7.5 Same File in Both

```bash
# .xcind.sh — .env used for both interpolation AND container injection
XCIND_COMPOSE_ENV_FILES=(".env")
XCIND_APP_ENV_FILES=(".env")
```

This is valid and useful. The same `.env` file serves double duty: its variables are available for YAML interpolation in compose files **and** injected into containers at runtime. This is the configuration that "just works" the way most people expect `.env` to behave.

---

## 8. Open Questions

1. **Should `XCIND_APP_ENV_FILES` default to `(".env")` instead of `()`?** This would match the common expectation that `.env` is available in containers. However, it would be a behavior change for existing setups where `.env` contains compose-level variables (like `COMPOSE_PROJECT_NAME`) that shouldn't leak into containers. Defaulting to empty is safer.

2. **Should the BC shim be time-limited?** The shim could be removed in a future major version. For now, no removal timeline is proposed.

3. **Override file interaction:** When a user's base compose file already has `env_file:` entries, Docker Compose appends the generated entries. Should xcind warn about this? Probably not — it's standard merge behavior and warning would be noisy.

---

## 9. Success Criteria

- [ ] `XCIND_COMPOSE_ENV_FILES` replaces `XCIND_ENV_FILES` in all code, tests, examples, and docs.
- [ ] BC shim migrates `XCIND_ENV_FILES` → `XCIND_COMPOSE_ENV_FILES` with deprecation warning.
- [ ] `XCIND_APP_ENV_FILES` defaults to empty array.
- [ ] `xcind-app-env-hook` generates `compose.app-env.yaml` with `env_file:` entries for all services.
- [ ] Generated `env_file:` entries use absolute paths.
- [ ] Hook is a no-op when `XCIND_APP_ENV_FILES` is empty or no files resolve.
- [ ] SHA computation includes compose env file and app env file paths and content.
- [ ] `xcind-config` JSON output includes `composeEnvFiles` and `appEnvFiles` keys.
- [ ] `xcind-config --preview` / `--files` shows both compose and app env files.
- [ ] All existing tests pass with renamed variable.
- [ ] New tests cover BC shim, app env file resolution, and hook generation.
- [ ] Examples updated to use `XCIND_COMPOSE_ENV_FILES`.
- [ ] README documents both variables with clear explanation of the distinction.
