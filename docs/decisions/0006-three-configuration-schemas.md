# Three Configuration Schemas

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0006-three-configuration-schemas.md). Xcind implements this concept using sourceable Bash scripts instead of YAML files.

**Status**: Accepted

## Context

Configuration could be in one monolithic file or separated by concern.

## Decision

Three configuration levels that cascade:
- **Proxy** (`~/.config/xcind/proxy/config.sh`): Global/per-user settings (domain, Traefik image, ports)
- **Workspace** (workspace `.xcind.sh` with `XCIND_IS_WORKSPACE=1`): Per-workspace settings (domain override, hooks)
- **Application** (app `.xcind.sh`): Per-application settings (compose files, env files, proxy exports)

When in workspace mode, configuration is sourced in order: global proxy config, then workspace `.xcind.sh`, then app `.xcind.sh`. Later values override earlier ones.

## Consequences

Separation of concerns — proxy config rarely changes, workspace config defines the environment, application config is owned by the application team. Using sourceable Bash scripts means configuration can use shell features (variable expansion, conditionals) natively.
