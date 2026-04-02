# Flexible TLS Configuration

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0009-flexible-tls-configuration.md).

**Status**: Proposed

## Context

HTTPS support for local development requires TLS certificates. Different environments have different constraints (personal dev machines, enterprise networks with managed CAs).

## Decision

Support multiple TLS modes via proxy configuration:

| Mode | Use Case |
|------|----------|
| `auto` | Personal development — uses mkcert if available, falls back to self-signed |
| `custom` | Enterprise environments — user provides cert/key signed by enterprise CA |
| `disabled` | HTTP-only development (not recommended) |

## Consequences

- `auto` provides zero-config HTTPS for most users with mkcert installed
- `custom` supports enterprise environments where developers already have CA-signed certs
- Avoids mandating a specific certificate tool while still enabling secure-by-default development

## Related Decisions

- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) - Traefik performs TLS termination
