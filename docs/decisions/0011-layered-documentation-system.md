# Layered Documentation System

> **Origin**: This decision originates from the [Scind specification](https://github.com/scinddev/scind/blob/main/docs/decisions/0012-layered-documentation-system.md).

**Status**: Accepted

## Context

As the project grew, documentation accumulated organically without a consistent organizational structure. Different types of content — decisions, specifications, reference material, and implementation guides — were intermixed or duplicated across files. This created problems with discoverability, maintenance burden, unclear authority, and inconsistent depth.

## Decision

Adopt the Layered Documentation System (LDS) with seven distinct layers, each serving a specific purpose:

| Layer | Directory | Purpose | Stability |
|-------|-----------|---------|-----------|
| 1. Decisions | `decisions/` | Capture WHY choices were made | Immutable |
| 2. Vision | `product/` | Define WHAT we're building | Stable |
| 3. Architecture | `architecture/` | Show HOW components relate | Evolving |
| 4. Specifications | `specs/` | Detail HOW features work | Living |
| 5. Reference | `reference/` | Provide lookup tables | Generated/maintained |
| 6. Behaviors | `behaviors/` | Verify expected behaviors | Executable |
| 7. Implementation | `implementation/` | Guide HOW to build | Short-lived |

Key principles:
- **Single Source of Truth**: Each fact lives in exactly one place
- **Linkage Over Duplication**: Reference other documents rather than copying
- **Appendix for Scale**: Large content moves to appendices, keeping main docs scannable
- **Authority Hierarchy**: ADRs > Gherkin > Vision > Specifications > Reference > Implementation

## Consequences

### Positive

- Clear placement rules via classification decision tree
- Defined authority hierarchy resolves conflicts unambiguously
- Appendix system keeps main documents scannable while preserving detail
- Cross-layer linking creates navigable documentation graph

### Negative

- Contributors must learn the layer system before adding documentation
- More files to navigate compared to monolithic documentation

### Neutral

- Documentation structure is now convention-driven rather than ad-hoc
- The `DOCUMENTATION-GUIDE.md` file becomes the authoritative reference for documentation practices

## Related Documents

- [Documentation Guide](../DOCUMENTATION-GUIDE.md) - Complete LDS reference
