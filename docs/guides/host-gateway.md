# `host.docker.internal` and host-gateway

Containers sometimes need to reach services running on the host (a database started outside Docker, a debugger, a local DNS resolver). The standard hostname for that is `host.docker.internal`. On Docker Desktop it works out of the box; on native Linux it requires a flag; on WSL2 the right value depends on the network mode.

Xcind's `xcind-host-gateway-hook` normalizes this so the same compose file works everywhere. It generates a `compose.host-gateway.yaml` overlay that adds:

```yaml
services:
  <every-service>:
    extra_hosts:
      - "host.docker.internal:host-gateway"   # or platform-specific value
```

The hook only adds the mapping to services that don't already define one — your manual overrides win.

## Platforms it handles

| Platform | What gets injected |
|----------|--------------------|
| Docker Desktop (macOS / Windows / Linux) | `host.docker.internal:host-gateway` |
| Native Linux (no Desktop) | `host.docker.internal:host-gateway` |
| WSL2 (NAT mode) | the WSL2 host IP |
| WSL2 (mirrored mode) | `host-gateway` |

Detection is automatic.

## Disable it

If your project handles `host.docker.internal` itself, opt out in `.xcind.sh`:

```bash
XCIND_HOST_GATEWAY_ENABLED=0
```

## Override the value

Force a specific value (rare — useful in CI or unusual network setups):

```bash
XCIND_HOST_GATEWAY="172.17.0.1"
```

## Requirements

`yq` must be installed for the overlay to be generated. If it's missing, the hook is skipped with a warning and the rest of Xcind continues to work.

## Where to go next

- [Author custom hooks](./custom-hooks.md) — disable, replace, or extend the host-gateway hook.
- [`engineering/specs/generated-override-files.md`](../../engineering/specs/generated-override-files.md) — exhaustive overlay-generation behavior, including host-gateway.
