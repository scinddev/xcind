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

### Flavors are deferred, not rejected

Scind's canon includes **flavors** — named variant configurations with a
`default_flavor`, a resolution step, and `flavor list` / `flavor set` commands.
Xcind implements none of them, and that omission follows directly from the
separation above: selecting a flavor means recording *which flavor is active*,
which is state, and Xcind keeps no such state. Instead, an app lists compose
files flatly in `XCIND_COMPOSE_FILES` and selects between variants by expanding
an environment variable in the file pattern (for example
`compose.${APP_ENV}.yaml`), so the choice lives in the caller's environment
rather than in a persisted active-flavor record.

The deferral is deliberate and this ADR is the record of it. Scind keeps
flavors: they map to a standard, well-understood pattern (compose profiles) and
Scind persists active-flavor state by design. Xcind is not asserting that the
mechanism is over-built. If Xcind ever gains persisted per-app state, flavors
become buildable and this decision should be revisited. See sync divergence
[0024](../sync/divergence/0024-flavors-variant-configs.md).

## Consequences

- Configuration files describe the system's shape, not its current state
- State changes frequently; structure changes rarely
- Avoids polluting config files with transient information
- Branch management stays with git where it belongs
- No flavor mechanism: variant selection is an environment-variable expansion in
  the caller's environment, not a stored choice
