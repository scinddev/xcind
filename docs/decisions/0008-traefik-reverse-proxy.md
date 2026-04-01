# Traefik for Reverse Proxy

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0008-traefik-reverse-proxy.md).

**Status**: Accepted

## Context

Need a reverse proxy that can dynamically route to containers.

## Decision

Use Traefik with Docker provider, reading labels from containers.

## Consequences

Traefik's Docker integration allows dynamic routing without config file changes. Labels on containers (added via generated overrides) define routing rules.

## Related Decisions

- [ADR-0002: Two-Layer Networking](0002-two-layer-networking.md) - Network architecture that Traefik operates within
- [ADR-0007: Port Type System](0007-port-type-system.md) - Defines proxied vs assigned port types
- [ADR-0009: Flexible TLS Configuration](0009-flexible-tls-configuration.md) - TLS termination at Traefik
