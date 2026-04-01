# Pure Overlay Design (Applications Remain Workspace-Agnostic)

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0003-pure-overlay-design.md).

**Status**: Accepted

## Context

Applications could embed workspace configuration, or it could be applied externally.

## Decision

Applications' own `docker-compose.yaml` files have no knowledge of workspaces. All workspace integration is achieved through generated Docker Compose override files.

## Consequences

- Applications can run standalone without Xcind
- No vendor lock-in or special conventions in application code
- Workspace concerns are cleanly separated from application concerns
- Same application can participate in multiple workspace systems
