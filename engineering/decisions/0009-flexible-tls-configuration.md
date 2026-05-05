# Flexible TLS Configuration

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0009-flexible-tls-configuration.md).

**Status**: Accepted

## Context

HTTPS support for local development requires TLS certificates. Different environments have different constraints (personal dev machines, enterprise networks with managed CAs).

## Decision

Support multiple TLS modes via `XCIND_PROXY_TLS_MODE` in the global proxy config:

| Mode | Use Case |
|------|----------|
| `auto` (default) | Personal development — uses mkcert if available, falls back to a self-signed wildcard generated via openssl |
| `custom` | Enterprise environments — user provides cert/key signed by enterprise CA via `XCIND_PROXY_TLS_CERT_FILE` / `XCIND_PROXY_TLS_KEY_FILE` |
| `disabled` | HTTP-only development (not recommended) |

Wildcard certificates cover `*.${XCIND_PROXY_DOMAIN}` plus the bare domain, so TLS Just Works for every generated hostname.

Per-export TLS behaviour is controlled by the `tls` metadata key on each `XCIND_PROXY_EXPORTS` entry:

| `tls` value | Behaviour |
|-------------|-----------|
| `auto` (default) | Emit both HTTP and HTTPS routers |
| `require` | HTTPS-only; HTTP router is a 301 redirect to HTTPS |
| `disable` | HTTP-only for this export even when proxy TLS is enabled |

When `XCIND_PROXY_TLS_MODE=disabled`, all exports collapse to HTTP regardless of per-export setting.

## Consequences

- `auto` provides zero-config HTTPS for most users with mkcert installed; an openssl fallback keeps HTTPS working on bare machines at the cost of a browser warning.
- `custom` supports enterprise environments where developers already have CA-signed certs.
- Router naming keeps the existing `{...}-http` literal and adds a parallel `{...}-https` router, so existing label consumers continue to work byte-for-byte.
- Avoids mandating a specific certificate tool while still enabling secure-by-default development.

## Related Decisions

- [ADR-0008: Traefik for Reverse Proxy](0008-traefik-reverse-proxy.md) - Traefik performs TLS termination
