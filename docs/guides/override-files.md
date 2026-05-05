# Override files

Override files are the standard Compose mechanism for layering local-only changes on top of a committed compose file. Xcind picks them up automatically, including for environment files and additional config scripts.

## How resolution works

For every file pattern Xcind checks (compose files, env files, additional config files), it also checks for an `.override` variant on disk. Both are included if present; missing files are silently skipped.

For files with a recognized extension (`.yaml`, `.yml`, `.json`, `.hcl`, `.toml`), `.override` is inserted **before** the extension:

| Base | Override |
|------|----------|
| `compose.yaml` | `compose.override.yaml` |
| `compose.common.yaml` | `compose.common.override.yaml` |
| `docker-bake.hcl` | `docker-bake.override.hcl` |

For all other files (env files, shell scripts), `.override` is **appended**:

| Base | Override |
|------|----------|
| `.env` | `.env.override` |
| `.env.local` | `.env.local.override` |
| `.xcind-tools.sh` | `.xcind-tools.sh.override` |

## Common pattern

Commit the base file. `.gitignore` the override.

```
compose.yaml              # committed — production-ish defaults
compose.override.yaml     # local — port forwards, mounts, debug services
.env                      # committed — non-secret defaults
.env.override             # local — secrets, machine-specific paths
```

This is identical to the convention `docker compose` itself uses for `compose.override.yaml`. Xcind extends it to env files and additional config scripts.

## Generated overrides — don't hand-edit

Xcind hooks generate compose overlay files at `$XCIND_APP_ROOT/.xcind/generated/`. Examples: `compose.naming.yaml`, `compose.proxy.yaml`, `compose.workspace.yaml`, `compose.host-gateway.yaml`. These are output, not input — re-generated on every relevant change. Add `.xcind/generated/` to `.gitignore`.

If you need to tweak something a generated file produces, prefer:

1. Configuration (`XCIND_PROXY_EXPORTS`, `XCIND_HOST_GATEWAY`, etc.).
2. Your own `compose.override.yaml`, which loads after the generated overlays.
3. A [custom hook](./custom-hooks.md), if you need conditional logic.

## Where to go next

- [Environment files: compose-level vs app-level](./env-files.md).
- [`engineering/specs/generated-override-files.md`](../../engineering/specs/generated-override-files.md) — exact ordering of overlay files in the final `docker compose` command line.
