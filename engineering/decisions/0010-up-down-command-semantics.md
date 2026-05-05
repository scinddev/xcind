# up/down Command Semantics

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0010-up-down-command-semantics.md).

**Status**: Accepted

## Context

Commands could use `start`/`stop` or `up`/`down` terminology.

## Decision

Use `up` and `down` as primary commands, matching Docker Compose semantics:
- `up`: Build, create networks/volumes, generate overrides, start containers
- `down`: Stop containers, remove containers/networks, optionally remove volumes

## Consequences

- Semantic alignment with Docker Compose, which users already know
- `up` conveys "bring the environment into existence" (more than just starting)
- `down` conveys "tear down" rather than just pausing
- Matches the underlying `docker compose up/down` commands that `xcind-compose` invokes
