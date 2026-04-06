# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) documenting significant design choices for Xcind.

Many of these decisions originate from the [Scind specification](https://github.com/scinddev/scind) and apply to Xcind's implementation.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](./0001-docker-compose-project-name-isolation.md) | Docker Compose Project Name Isolation | Accepted |
| [0002](./0002-two-layer-networking.md) | Two-Layer Networking | Accepted |
| [0003](./0003-pure-overlay-design.md) | Pure Overlay Design | Accepted |
| [0004](./0004-convention-based-naming.md) | Convention-Based Naming | Accepted |
| [0005](./0005-structure-vs-state-separation.md) | Structure vs State Separation | Accepted |
| [0006](./0006-three-configuration-schemas.md) | Three Configuration Schemas | Accepted |
| [0007](./0007-port-type-system.md) | Port Type System | Accepted |
| [0008](./0008-traefik-reverse-proxy.md) | Traefik for Reverse Proxy | Accepted |
| [0009](./0009-flexible-tls-configuration.md) | Flexible TLS Configuration | Accepted |
| [0010](./0010-up-down-command-semantics.md) | up/down Command Semantics | Accepted |
| [0011](./0011-layered-documentation-system.md) | Layered Documentation System | Accepted |
| [0012](./0012-unified-generate-flag-semantics.md) | Unified Generate Flag Semantics | Accepted |
| [0013](./0013-host-docker-internal-normalization.md) | Automatic `host.docker.internal` Normalization | Accepted |

## ADR Format

Each ADR follows the MADR minimal template with:
- **Title**: Short descriptive name
- **Status**: Accepted, Superseded, or Deprecated
- **Context**: The situation requiring a decision
- **Decision**: The choice made
- **Consequences**: Resulting implications
