# Docker Compose Project Name Isolation

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0001-docker-compose-project-name-isolation.md).

**Status**: Accepted

## Context

Need to run multiple instances of the same application simultaneously.

## Decision

Use Docker Compose's native `--project-name` (or `name:` in compose file) to create isolated namespaces. Each application in a workspace gets project name `{workspace}-{application}`.

> **Update (worktree isolation).** The project name is further namespaced by the
> per-worktree isolation token `XCIND_INSTANCE` when it is non-empty:
> `{workspace}-{instance}-{application}` (or `{application}-{instance}`
> workspaceless). This disambiguates multiple git worktrees of the same
> repository, which otherwise derive an identical project name and collide. An
> empty instance (the default on the main checkout) leaves the name
> byte-identical to `{workspace}-{application}`. See
> [Naming Conventions](../specs/naming-conventions.md#instance-token-xcind_instance).
> (This capability post-dates the original decision; a dedicated ADR for
> `XCIND_INSTANCE` is a recommended follow-up.)

## Consequences

This is Docker's official mechanism for running multiple copies of the same stack. It isolates containers, networks, and volumes without requiring modifications to the application.
