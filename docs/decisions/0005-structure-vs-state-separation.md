# Structure vs State Separation

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0005-structure-vs-state-separation.md).

**Status**: Accepted

## Context

Configuration could include runtime choices (which branch, which flavor) or only structural definitions.

## Decision

Separate structure (what exists) from state (what's active):

| Aspect | Structure (`.xcind.sh` files) | State (runtime) |
|--------|-------------------------------|-----------------|
| What apps exist | Workspace `.xcind.sh` | - |
| Compose file patterns | App `.xcind.sh` | - |
| Proxy exports | App `.xcind.sh` | - |
| Active branch | - | git working directory |
| Running containers | - | Docker |
| Generated files | - | `.xcind/generated/` cache |

## Consequences

- Configuration files describe the system's shape, not its current state
- State changes frequently; structure changes rarely
- Avoids polluting config files with transient information
- Branch management stays with git where it belongs
