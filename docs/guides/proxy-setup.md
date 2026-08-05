# Set up the Traefik proxy

Xcind ships a shared Traefik reverse proxy so you can reach apps at `https://myapp.localhost.scind.io` instead of `localhost:PORT`. One Traefik instance runs across all your Xcind apps. For certificate trust and the domain rules behind that hostname, see [Local HTTPS](./https-tls.md).

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
| Workspaceless | `{app}-{export}.{domain}` | `myapp-api.localhost.scind.io` |
| Workspace | `{workspace}-{app}-{export}.{domain}` | `dev-backend-api.localhost.scind.io` |

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

`xcind-proxy init` creates `~/.config/xcind/proxy/config.sh` with the current values. The file is yours to edit:

```bash
XCIND_PROXY_DOMAIN="localhost.scind.io"   # domain suffix for hostnames (use ≥2 labels)
XCIND_PROXY_IMAGE="traefik:v3"
XCIND_PROXY_HTTP_PORT="80"
XCIND_PROXY_DASHBOARD="false"
XCIND_PROXY_DASHBOARD_PORT="8080"
XCIND_PROXY_AUTO_START="1"
```

Two ways to apply changes:

```bash
# Edit config.sh by hand, then re-run up to regenerate compose / Traefik config:
xcind-proxy up

# Or pass flags to `init` — it merges existing config.sh values with your overrides
# and rewrites the file:
xcind-proxy init --proxy-domain xcind.localhost --tls-mode auto

xcind-proxy up --force                # recreate proxy container + network
```

`xcind-proxy up` on its own never modifies `config.sh`; only `xcind-proxy init` rewrites it.

## Use an existing Traefik (external mode)

If the host already runs a Traefik that owns ports 80/443 — a Coolify server
is the typical case — don't run a second proxy. Switch xcind to **external
mode**: apps attach to the existing proxy's Docker network and emit labels its
Docker provider picks up directly. Xcind never starts, stops, or reconfigures
the external proxy.

### Coolify walkthrough

Coolify's proxy (`coolify-proxy`) lives on the `coolify` network, names its
entrypoints `http`/`https`, and terminates TLS with a certresolver named
`letsencrypt`. Point xcind at all three:

```bash
xcind-proxy init --mode external --network coolify \
  --http-entrypoint http --https-entrypoint https \
  --certresolver letsencrypt --proxy-domain apps.example.com
```

Then point DNS for `*.apps.example.com` (and `apps.example.com` if you use
apex URLs) at the host, and bring your apps up as usual:

```bash
xcind-compose up -d
xcind-proxy status        # Mode: external, network, detected proxy container
```

The HTTPS routers carry `tls.certresolver=letsencrypt`, so the Coolify Traefik
requests real ACME certificates for each hostname on first use. Xcind's own
cert machinery (mkcert/self-signed) is skipped entirely, and `--tls-mode
custom` is rejected in external mode.

In external mode `xcind-proxy up` only verifies the shared network, and
`down`/`logs` refuse — manage the proxy with the host's own tooling. If you're
migrating from managed mode and the old xcind Traefik is still running,
`xcind-proxy down` will still stop it once.

### Alternate wiring: connect the proxy to xcind's network

Instead of joining the external proxy's network, you can keep the default
`xcind-proxy` network and attach the external proxy to it:

```bash
docker network connect xcind-proxy <your-traefik-container>
```

Caveat: platform-managed proxies (Coolify's included) are recreated on
upgrades and redeploys, which silently drops this connection — you'd need to
re-run the `connect` after each recreation. Joining the proxy's own network
via `--network` avoids that, which is why it's the recommended wiring.

Two more host-proxy caveats worth knowing:

- A global HTTP→HTTPS redirect on the host proxy (Coolify's "Force HTTPS")
  shadows xcind's HTTP routers at the entrypoint. Harmless — requests land on
  the HTTPS routers anyway.
- If the host Traefik sets `providers.docker.constraints`, xcind's containers
  won't be discovered unless they carry the matching label.

Switching back to managed mode later requires restating the managed values,
since `init` merges existing config:

```bash
xcind-proxy init --mode managed --network xcind-proxy \
  --http-entrypoint web --https-entrypoint websecure
```

## Day-to-day commands

```bash
xcind-proxy status          # is it running?
xcind-proxy logs -f         # tail Traefik logs
xcind-proxy down            # stop the shared proxy
xcind-proxy dispose          # remove generated state; keep config.sh
xcind-proxy dispose --purge --yes  # also remove config.sh without prompting
```

## Where to go next

- [Configuration reference](../reference/configuration.md) — `XCIND_PROXY_EXPORTS`, `XCIND_PROXY_DOMAIN`, URL templates.
- [`engineering/specs/proxy-infrastructure.md`](../../engineering/specs/proxy-infrastructure.md) — full behavior spec, including TLS posture and edge cases.
