# Set up the Traefik proxy

Xcind ships a shared Traefik reverse proxy so you can reach apps at `https://myapp.localhost` instead of `localhost:PORT`. One Traefik instance runs across all your Xcind apps.

## Initialize once

```bash
xcind-proxy init
xcind-proxy up
```

`init` creates the proxy configuration at `~/.config/xcind/proxy/config.sh` and a generated state directory at `~/.local/state/xcind/proxy/`. `up` starts the Traefik container and creates the `xcind-proxy` Docker network.

Verify:

```bash
xcind-proxy status
```

## Declare exports per app

In each app's `.xcind.sh`:

```bash
XCIND_PROXY_EXPORTS=(
    "api=app:3000"    # export "api" → service "app", port 3000
    "web:8080"        # export "web" → service "web" (export name defaults to service)
    "app"             # port inferred from the service's port mapping
)
```

Generated hostnames:

| Mode | Template | Example |
|------|----------|---------|
| Workspaceless | `{app}-{export}.{domain}` | `myapp-api.localhost` |
| Workspace | `{workspace}-{app}-{export}.{domain}` | `dev-backend-api.xcind.localhost` |

After editing exports, recreate the app:

```bash
xcind-compose up -d
```

## Stable host ports (assigned, not proxied)

Some services (databases, debuggers) want a fixed host port instead of a hostname. Use `type=assigned`:

```bash
XCIND_PROXY_EXPORTS=(
    "worker:9000;type=assigned"      # publish container port 9000 on a stable host port
    "database=db:3306;type=assigned"
)
```

Bindings persist across restarts under `~/.local/state/xcind/proxy/assigned-ports.tsv`.

## Customize the proxy

Edit `~/.config/xcind/proxy/config.sh` (created by `init`, never overwritten):

```bash
XCIND_PROXY_DOMAIN="localhost"        # domain suffix for hostnames
XCIND_PROXY_IMAGE="traefik:v3"
XCIND_PROXY_HTTP_PORT="80"
XCIND_PROXY_DASHBOARD="false"
XCIND_PROXY_DASHBOARD_PORT="8080"
XCIND_PROXY_AUTO_START="1"
```

Apply changes:

```bash
xcind-proxy up         # regenerates and applies
xcind-proxy up --force # also recreates the proxy container and network
```

## Day-to-day commands

```bash
xcind-proxy status          # is it running?
xcind-proxy logs -f         # tail Traefik logs
xcind-proxy down            # stop the shared proxy
```

## Where to go next

- [Configuration reference](../reference/configuration.md) — `XCIND_PROXY_EXPORTS`, `XCIND_PROXY_DOMAIN`, URL templates.
- [`engineering/specs/proxy-infrastructure.md`](../../engineering/specs/proxy-infrastructure.md) — full behavior spec, including TLS posture and edge cases.
