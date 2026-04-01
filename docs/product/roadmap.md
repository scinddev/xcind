# Roadmap

> **Note**: This roadmap describes planned features without specific version targets. Features are prioritized based on community feedback and project needs.

## Assigned Ports (Future)

*Extends [ADR-0007: Port Type System](../decisions/0007-port-type-system.md)*

**Context**: Currently `XCIND_PROXY_EXPORTS` supports proxied (HTTP/HTTPS) services through Traefik. Some services (databases, caches) need direct port binding with automatic port assignment to avoid conflicts.

**Consideration**: Add an `XCIND_ASSIGNED_EXPORTS` array for services that need direct host port mapping without proxy routing.

## Application Dependencies (Future)

*Related to [ADR-0010: Up/Down Command Semantics](../decisions/0010-up-down-command-semantics.md)*

**Context**: Some applications may need others to be running first (e.g., backend depends on shared-db).

**Consideration**: Dependency ordering or startup sequencing within a workspace.

## Health Checks (Future)

**Context**: Starting applications in order isn't sufficient if they need warm-up time.

**Consideration**: Integration with Docker health checks to wait for readiness before starting dependent applications.
