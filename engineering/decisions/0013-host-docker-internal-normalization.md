# Automatic `host.docker.internal` Normalization

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0014-host-docker-internal-normalization.md).

**Status**: Accepted

## Context

Docker's `host.docker.internal` DNS name resolves to the developer's workstation from inside containers, but behavior varies across platforms. Docker Desktop handles it automatically, while native Linux and WSL2 (without Desktop) require manual `extra_hosts` configuration. Common advice to add `host.docker.internal:host-gateway` is incorrect for WSL2 standalone setups where `host-gateway` resolves to the WSL2 VM rather than the Windows host.

This breaks development tools that need host connectivity—Xdebug, webhook receivers, and IDE integrations—and requires per-project, per-platform boilerplate.

## Decision

Xcind automatically ensures `host.docker.internal` resolves to the developer's workstation for all services via a generated compose overlay (`compose.host-gateway.yaml`). The implementation:

1. Detects the platform (Docker Desktop, native Linux, WSL2 NAT/mirrored)
2. Determines the correct gateway value (IP address or `host-gateway`)
3. Generates `extra_hosts` entries for services that lack the mapping, preserving any existing `extra_hosts` entries
4. Provides opt-out (`XCIND_HOST_GATEWAY_ENABLED=0`) and override (`XCIND_HOST_GATEWAY=<value>`) mechanisms

The hook requires `yq` and degrades gracefully with a warning when `yq` is unavailable.

## Consequences

### Positive

- Development tools work immediately across all platforms without per-project setup
- Docker Desktop users see no behavioral change
- Native Linux users gain `host.docker.internal` without manual configuration
- WSL2-without-Desktop users receive the correct Windows host IP
- Existing `extra_hosts` entries are preserved during overlay generation

### Negative

- Platform detection adds complexity and requires maintenance as WSL evolves
- Introduces `yq` as a soft dependency for full functionality

### Neutral

- Services with existing `host.docker.internal` mappings are left unchanged
- The hook is registered by default but can be disabled or overridden

## Related Documents

- [Scind ADR-0014](https://github.com/scinddev/scind/blob/main/docs/decisions/0014-host-docker-internal-normalization.md) — Specification-level decision
- [ADR-0003](./0003-pure-overlay-design.md) — Pure Overlay Design (pattern followed)
- [Configuration Reference](../reference/configuration.md) — `XCIND_HOST_GATEWAY_ENABLED` and `XCIND_HOST_GATEWAY` documentation
- [`xcind-host-gateway-lib.bash`](../../lib/xcind/xcind-host-gateway-lib.bash) — Implementation
