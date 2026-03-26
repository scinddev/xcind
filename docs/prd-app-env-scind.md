# Prompt: Add Application-Level Environment Files to Scind Spec

> This document is designed to be copied into the Scind project (fictional-dollop) and executed as a prompt to augment the existing specification. It references Scind spec file paths directly.

---

## Goal

Add support for **two distinct types of environment files** in Scind's application configuration, making the difference between compose-level and container-level env files explicit.

**The problem:** Docker Compose has two completely separate scopes for environment files that are commonly confused ([docker/compose#9135](https://github.com/docker/compose/issues/9135)):

| | Compose-level (`--env-file`) | Container-level (`env_file:`) |
|---|---|---|
| **What it does** | Variable substitution in compose YAML (`${VAR}`) | Injects vars into running containers |
| **Where configured** | CLI flag passed to `docker compose` | `env_file:` directive in compose service definition |
| **Scope** | Compose process only | Container runtime only |

**Current behavior:** Scind has no explicit concept for either type of environment file in `application.yaml`. Applications manage their own `env_file:` directives in their compose files, and compose-level env files are not configurable.

**Desired behavior:** `application.yaml` supports two top-level keys:
- `compose_env_files` — files passed as `--env-file` to `docker compose` (YAML interpolation only)
- `app_env_files` — files injected into all container services via `env_file:` in the generated override

---

## Design

### New Configuration Keys

Add two new top-level keys to `application.yaml`:

```yaml
# application.yaml
default_flavor: full

compose_env_files:
  - .env.compose

app_env_files:
  - .env
  - .env.local

flavors:
  full:
    compose_files:
      - docker-compose.yaml

exported_services:
  web:
    port: 8080
    type: proxied
    protocol: https
```

#### `compose_env_files`

- **Type:** list of strings (file paths relative to the application directory)
- **Default:** `[".env"]` (mirrors Docker Compose's default `.env` file behavior)
- **Purpose:** These files are passed as `--env-file` flags when Scind invokes `docker compose`. Variables defined in these files are available for `${VAR}` interpolation in compose YAML files but are **not** available inside running containers.
- **Resolution:** Each pattern is resolved relative to the application directory. Files that do not exist are silently skipped.

#### `app_env_files`

- **Type:** list of strings (file paths relative to the application directory)
- **Default:** `[]` (empty — no app-level env files are injected unless explicitly configured)
- **Purpose:** These files are injected into **all** container services in the application via Docker Compose's `env_file:` directive in the generated override file. Variables defined in these files **are** available inside running containers.
- **Resolution:** Each pattern is resolved relative to the application directory. Files that do not exist are silently skipped. Resolved paths are written as **absolute paths** in the generated override file (because the override lives in `{workspace}/.generated/` while the env files live in the application directory).

### Generated Override Changes

The generated override file (`{workspace}/.generated/{application-name}.override.yaml`) gains `env_file:` entries for every service when `app_env_files` is configured and at least one file resolves.

**Before (existing override structure):**

```yaml
name: dev-frontend

services:
  web:
    networks:
      dev-internal:
        aliases:
          - frontend-web
          - frontend
      scind-proxy: {}
    labels:
      - "traefik.http.routers.dev-frontend-web-https.rule=Host(`dev-frontend-web.scind.test`)"
      # ... other labels ...
    environment:
      - SCIND_FRONTEND_WEB_HOST=dev-frontend-web.scind.test
      - SCIND_FRONTEND_WEB_URL=https://dev-frontend-web.scind.test
      # ... other discovery vars ...

networks:
  dev-internal:
    external: true
  scind-proxy:
    external: true
```

**After (with `app_env_files: [".env", ".env.local"]`):**

```yaml
name: dev-frontend

services:
  web:
    networks:
      dev-internal:
        aliases:
          - frontend-web
          - frontend
      scind-proxy: {}
    labels:
      - "traefik.http.routers.dev-frontend-web-https.rule=Host(`dev-frontend-web.scind.test`)"
      # ... other labels ...
    env_file:
      - /absolute/path/to/frontend/.env
      - /absolute/path/to/frontend/.env.local
    environment:
      - SCIND_FRONTEND_WEB_HOST=dev-frontend-web.scind.test
      - SCIND_FRONTEND_WEB_URL=https://dev-frontend-web.scind.test
      # ... other discovery vars ...

  worker:
    env_file:
      - /absolute/path/to/frontend/.env
      - /absolute/path/to/frontend/.env.local

networks:
  dev-internal:
    external: true
  scind-proxy:
    external: true
```

Key points:
- `env_file:` entries are added to **every** service in the compose project, not just exported services.
- Paths are **absolute** to avoid ambiguity (the override file lives in `.generated/`, not the app directory).
- `env_file:` is placed before `environment:` in the YAML. Docker Compose's precedence rules ensure that `environment:` entries (including `SCIND_*` discovery vars) override any conflicting keys from `env_file:`.
- Docker Compose **appends** `env_file:` lists when merging overrides. If the application's base compose file already has `env_file:` entries, the generated entries are added after them.

### Docker Compose Invocation

When `compose_env_files` is configured, Scind passes the resolved files as `--env-file` flags:

```bash
docker compose \
  --env-file /absolute/path/to/frontend/.env.compose \
  -f /path/to/frontend/docker-compose.yaml \
  -f /workspace/.generated/dev-frontend.override.yaml \
  up -d
```

### Staleness Detection

Add `app_env_files` resolution to the staleness detection inputs. The generated override must be regenerated when:
- `application.yaml` changes (already tracked)
- Any file referenced by `app_env_files` is added, removed, or modified
- Any file referenced by `compose_env_files` is added, removed, or modified

### Validation Rules

- `compose_env_files` entries must be strings (file paths).
- `app_env_files` entries must be strings (file paths).
- Duplicate entries within a list are allowed but redundant (Docker Compose deduplicates).
- No validation that files exist at config-parse time (resolved at generation time; missing files are silently skipped).

---

## Spec Files to Modify

### 1. `docs/specs/configuration-schemas.md`

Add `compose_env_files` and `app_env_files` to the application configuration schema:

```yaml
# Application Configuration Schema
compose_env_files:            # Optional, list of strings
  - .env                      # Default: [".env"]

app_env_files:                # Optional, list of strings
  - .env                      # Default: [] (empty)
  - .env.local
```

Document:
- Both are top-level keys in `application.yaml`, alongside `flavors` and `exported_services`.
- `compose_env_files` defaults to `[".env"]`; `app_env_files` defaults to `[]`.
- Path resolution: relative to application directory, missing files silently skipped.

### 2. `docs/reference/configuration.md`

In the "Application Configuration" section:
- Add documentation for `compose_env_files` with explanation that these are for compose YAML interpolation only.
- Add documentation for `app_env_files` with explanation that these are injected into containers.
- Add a callout/note explaining the distinction between the two, referencing Docker Compose's two scopes.

### 3. `docs/specs/generated-override-files.md`

Add `env_file:` to the generated override file structure. Show it appearing on every service when `app_env_files` is configured. Note:
- Absolute paths are used.
- Placed before `environment:` in the YAML output.
- Additive merge with any existing `env_file:` in the base compose file.

### 4. `docs/specs/environment-variables.md`

Add a new section or note distinguishing between:
- **Service discovery variables** (`SCIND_*`) — injected via `environment:` in the generated override (existing behavior).
- **Application environment files** — injected via `env_file:` in the generated override (new behavior).

Note that `environment:` entries take precedence over `env_file:` entries per Docker Compose's precedence rules, so `SCIND_*` discovery variables cannot be accidentally overridden by app env files.

### 5. `docs/architecture/overview.md`

If the architecture overview discusses configuration flow, add a mention that `compose_env_files` affect the Docker Compose invocation (CLI flags) while `app_env_files` affect the generated override (service-level injection).

### 6. `docs/specs/docker-compose-invocation.md` (if it exists)

Document that `compose_env_files` are passed as `--env-file` flags in the Docker Compose command. Show the full command structure including these flags.

---

## Examples

### Basic — App env files only

```yaml
# application.yaml
app_env_files:
  - .env
  - .env.local

flavors:
  default:
    compose_files:
      - docker-compose.yaml

exported_services:
  web:
    port: 8080
    type: proxied
    protocol: https
```

Result: `.env` and `.env.local` (if they exist) are referenced via `env_file:` in the generated override for every service. The default `compose_env_files: [".env"]` is also used for YAML interpolation.

### Both types explicitly configured

```yaml
# application.yaml
compose_env_files:
  - .env.compose
  - .env.compose.local

app_env_files:
  - .env
  - .env.local
  - .env.secrets

flavors:
  default:
    compose_files:
      - docker-compose.yaml
```

Result:
- `.env.compose` and `.env.compose.local` are passed as `--env-file` to `docker compose` for YAML interpolation.
- `.env`, `.env.local`, and `.env.secrets` are injected into containers via `env_file:`.

### Same file in both

```yaml
# application.yaml
compose_env_files:
  - .env

app_env_files:
  - .env
```

This is valid. The `.env` file serves double duty: its variables are available for YAML interpolation in compose files **and** injected into containers at runtime. This matches the behavior most people expect from `.env`.

### No app env files (default)

```yaml
# application.yaml
flavors:
  default:
    compose_files:
      - docker-compose.yaml
```

When `app_env_files` is omitted, it defaults to `[]`. No `env_file:` entries are added to the generated override. The default `compose_env_files: [".env"]` still applies for YAML interpolation.

---

## Differences from xcind

| Aspect | Scind | xcind |
|--------|-------|-------|
| Config format | YAML keys in `application.yaml` | Bash arrays in `.xcind.sh` |
| Compose env files key | `compose_env_files` | `XCIND_COMPOSE_ENV_FILES` |
| App env files key | `app_env_files` | `XCIND_APP_ENV_FILES` |
| Compose env files default | `[".env"]` | `(".env")` |
| App env files default | `[]` | `()` |
| Override pattern support | No (plain file paths) | Yes (`${APP_ENV}` expansion, `.override` variants) |
| Backward compatibility | N/A (new feature) | BC shim migrates `XCIND_ENV_FILES` with deprecation warning |
| Injection mechanism | `env_file:` in single generated override | `env_file:` in dedicated `compose.app-env.yaml` via hook |
| Injection scope | All services | All services |

---

## Open Questions

1. **Should `app_env_files` support glob or variable patterns?** xcind supports shell variable expansion (e.g., `.env.${APP_ENV}`) in file patterns. Scind's YAML config doesn't have a natural equivalent. For now, only literal file paths are supported. Pattern support could be added later if needed.

2. **Should `compose_env_files` default to `[".env"]` or `[]`?** Defaulting to `[".env"]` mirrors Docker Compose's native behavior (it auto-loads `.env` from the project directory). Defaulting to `[]` would be more explicit but would break expectations. Recommend `[".env"]`.

3. **Interaction with flavors:** Should different flavors be able to specify different env files? This could be modeled as `compose_env_files` and `app_env_files` keys inside flavor definitions, but adds significant complexity. Recommend deferring this to a future enhancement.
