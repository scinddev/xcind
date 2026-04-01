# Port Type System for Exported Services

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0007-port-type-system.md). Xcind implements exported services via the `XCIND_PROXY_EXPORTS` Bash array.

**Status**: Accepted

## Context

Services need different handling based on how they're accessed — some need HTTP proxying, others need direct port binding.

## Decision

Each exported service declares how it should be accessed. In Xcind, exports are declared via the `XCIND_PROXY_EXPORTS` array:

```bash
XCIND_PROXY_EXPORTS=(
    "web=nginx:8080"    # export "web" from service "nginx" on port 8080
    "api=app:3000"      # export "api" from service "app" on port 3000
    "app"               # export "app" from service "app", port from compose config
)
```

The proxy hook generates Traefik labels for HTTP/HTTPS routing. The first entry in the array is implicitly primary and receives an apex hostname.

## Consequences

- Proxied services route through Traefik by hostname
- Supports multiple exports per application
- Position-based primary designation (first entry = apex URL) avoids additional configuration
- Environment variables use proxy values (port 80/443) for proxied services

## Related Decisions

- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) - Traefik handles proxied port routing
- [ADR-0009: Flexible TLS Configuration](0009-flexible-tls-configuration.md) - TLS for proxied ports
