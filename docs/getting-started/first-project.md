# Your first project

This walkthrough takes you from zero to a running, proxied app.

## Prerequisites

- Docker Desktop or a working `docker compose`
- Xcind installed — see [Installation](./installation.md)

## 1. Initialize an application

In any directory containing (or about to contain) a `compose.yaml`:

```bash
cd my-app
xcind-application init --name my-app
```

This creates a `.xcind.sh` file in the current directory. `--name` controls how Xcind labels containers, networks, and proxy hostnames; if omitted it defaults to the directory name.

`.xcind.sh` is a sourceable bash script. For most projects, the defaults inside it are enough — Xcind discovers `compose.yaml` and `.env` automatically.

## 2. Bring it up

```bash
xcind-compose up -d
```

`xcind-compose` is a thin wrapper around `docker compose`. It walks up to find your `.xcind.sh`, applies the resolved compose files and env files, and forwards the rest of your arguments straight through.

```bash
xcind-compose ps
xcind-compose logs -f
xcind-compose exec app bash
xcind-compose down
```

## 3. (Optional) Reach it by hostname

If you want to hit your app at `https://my-app.localhost.scind.io` instead of `localhost:PORT`, set up the shared Traefik proxy once:

```bash
xcind-proxy init
xcind-proxy up
```

Then declare an export in your `.xcind.sh`:

```bash
XCIND_PROXY_EXPORTS=("web:8080")    # service "web", port 8080
```

Recreate the app and visit the generated URL:

```bash
xcind-compose up -d
# https://my-app-web.localhost.scind.io
```

Full walkthrough: [Set up the Traefik proxy](../guides/proxy-setup.md).

## Next

- [Add Xcind to an existing Compose project](../guides/add-to-existing-project.md)
- [Configuration reference](../reference/configuration.md)
- [CLI reference](../reference/cli.md)
