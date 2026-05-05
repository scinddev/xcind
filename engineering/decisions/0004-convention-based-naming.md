# Convention-Based Naming

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0004-convention-based-naming.md).

**Status**: Accepted

## Context

Hostnames and aliases could be explicitly configured or derived from conventions.

## Decision

Derive names from conventions:
- Public hostname: `{workspace}-{application}-{export}.{domain}`
- Internal alias: `{application}-{service}`
- Network name: `{workspace}-internal`

Xcind provides configurable URL templates (`XCIND_WORKSPACELESS_APP_URL_TEMPLATE`, `XCIND_WORKSPACE_APP_URL_TEMPLATE`, etc.) that allow customizing hostname patterns while preserving convention-based defaults.

## Consequences

Conventions reduce configuration, ensure consistency, and make the system predictable. Configurable templates provide flexibility when defaults don't fit.
