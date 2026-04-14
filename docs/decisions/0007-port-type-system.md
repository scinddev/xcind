# Port Type System for Exported Services

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0007-port-type-system.md). Xcind implements exported services via the `XCIND_PROXY_EXPORTS` Bash array.

**Status**: Accepted

## Context

Services need different handling based on how they're accessed — some need HTTP proxying, others need direct port binding.

## Decision

Each exported service declares how it should be accessed. In Xcind, all exports are declared in a single `XCIND_PROXY_EXPORTS` array; the `type` metadata attribute picks between the two port-exposure mechanisms:

```bash
XCIND_PROXY_EXPORTS=(
    "web=nginx:8080"                 # proxied (default): Traefik routing on a hostname
    "api=app:3000"                   # proxied: Traefik routing on a hostname
    "app"                            # proxied, port inferred from compose config
    "worker:9000;type=assigned"      # assigned: stable host-port binding
    "database=db:3306;type=assigned" # assigned: stable host-port binding
)
```

`type=proxied` entries are handled by `xcind-proxy-hook`, which generates Traefik routing labels. The first proxied entry is implicitly primary and receives an apex hostname. `type=assigned` entries are handled by `xcind-assigned-hook`, which publishes the container port on a free host port (sticky across restarts via a TSV state file).

## Consequences

- Proxied services route through Traefik by hostname
- Assigned services bind directly to a host port, stable across restarts
- Supports multiple exports per application
- Position-based primary designation (first *proxied* entry = apex URL) avoids additional configuration
- Environment variables use proxy values (port 80/443) for proxied services

## Related Decisions

- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) - Traefik handles proxied port routing
- [ADR-0009: Flexible TLS Configuration](0009-flexible-tls-configuration.md) - TLS for proxied ports
