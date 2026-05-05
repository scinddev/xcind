# Add Xcind to an existing Compose project

You have a project with a `compose.yaml` (and probably a `.env`). Here is how to drop Xcind on top of it without changing how Compose itself works.

## 1. Initialize

From the project root:

```bash
xcind-application init
```

This writes a `.xcind.sh` (mostly empty — the defaults match Compose's own discovery rules). Commit this file. From now on, `xcind-compose` works anywhere inside the project tree, not just the root.

## 2. Use `xcind-compose` instead of `docker compose`

Everything you used to do still works — Xcind forwards arguments straight through:

```bash
xcind-compose up -d
xcind-compose build --no-cache
xcind-compose exec app bash
xcind-compose down --remove-orphans
```

What you gain immediately:

- **Run from any subdirectory.** `xcind-compose` walks up to find `.xcind.sh`.
- **Override files are auto-included.** If `compose.override.yaml` or `.env.override` exists, they are picked up. See [Override files](./override-files.md).
- **Workspace mode.** If you have multiple apps under one parent directory, Xcind can wire them together. See [Workspaces vs single apps](./workspaces-vs-apps.md).
- **Optional proxy.** Hostname-based routing through Traefik with one config line. See [Set up the Traefik proxy](./proxy-setup.md).

## 3. (Optional) Customize discovery

If your project doesn't follow the default layout, set the relevant variables in `.xcind.sh`. Common cases:

- Compose files live in a subdirectory:
  ```bash
  XCIND_COMPOSE_DIR="docker"
  ```
- You use multiple compose files:
  ```bash
  XCIND_COMPOSE_FILES=("compose.common.yaml" "compose.dev.yaml")
  ```
- You have additional env files:
  ```bash
  XCIND_COMPOSE_ENV_FILES=(".env" ".env.local")
  ```
- You want some env files mounted **inside** containers (not just used for `${VAR}` substitution in the compose file):
  ```bash
  XCIND_APP_ENV_FILES=(".env")
  ```

See [Configuration reference](../reference/configuration.md) for the variables you'll set most often, and [the engineering reference](../../engineering/reference/configuration.md) for the exhaustive list.

## 4. (Optional) Verify what Xcind resolved

```bash
xcind-config --preview     # shows the docker compose command line that will run
xcind-config --json        # machine-readable resolved config
xcind-config doctor        # diagnose discovery issues
```

## When does Xcind get out of your way?

Xcind only adds flags to `docker compose`. You can always fall back to plain `docker compose` in the same directory and everything still works — Xcind is additive, not a replacement.
