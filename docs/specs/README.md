# Specifications

Detailed behavioral specifications for Xcind features. Adapted from the [Scind specification](https://github.com/scinddev/scind) for Xcind's Bash implementation.

## Contents

### Core Specifications

- [Naming Conventions](./naming-conventions.md) — Hostname, alias, router, and variable naming patterns
- [Proxy Infrastructure](./proxy-infrastructure.md) — Traefik reverse proxy architecture and configuration
- [Docker Labels](./docker-labels.md) — Label conventions for service discovery and routing
- [Hook Lifecycle](./hook-lifecycle.md) — Pipeline hook phases (GENERATE, EXECUTE, and future phases)
- [Generated Override Files](./generated-override-files.md) — Hook-generated compose overlay files
- [Port Types](./port-types.md) — Proxied vs. direct port exposure

### Configuration and Detection

- [Configuration Schemas](./configuration-schemas.md) — Behavioral rules for `.xcind.sh` configuration
- [Context Detection](./context-detection.md) — How xcind finds app roots and workspaces
- [Directory Structure](./directory-structure.md) — File and directory layout
- [Environment Variables](./environment-variables.md) — Service discovery variables injected into containers
- [Workspace Lifecycle](./workspace-lifecycle.md) — Workspace operations and state

## Appendices

- [Proxy Infrastructure Appendix](./appendices/proxy-infrastructure/) — Traefik configuration examples
- [Generated Override Files Appendix](./appendices/generated-override-files/) — Example generated YAML
