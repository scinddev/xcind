# Xcind Engineering Documentation

This directory holds Xcind's **engineering documentation** — the design canon for contributors and AI agents working on Xcind itself. It follows the Layered Documentation System (LDS) defined in [ADR-0011](./decisions/0011-layered-documentation-system.md) and the two-track split established in [ADR-0014](./decisions/0014-two-track-documentation.md).

If you are **using** Xcind (installing, configuring, running it against your project), see the user documentation under [`../docs/`](../docs/) instead.

Xcind implements concepts from the [Scind specification](https://github.com/scinddev/scind).

## Layers

| Layer | Description | Entry Point |
|-------|-------------|-------------|
| **Decisions** | Architectural decision records | [decisions/](./decisions/README.md) |
| **Product** | Vision, comparison, roadmap | [product/](./product/README.md) |
| **Architecture** | System design overview | [architecture/](./architecture/README.md) |
| **Specifications** | Detailed feature specs | [specs/](./specs/README.md) |
| **Reference** | Exhaustive CLI and configuration reference | [reference/](./reference/README.md) |
| **Behaviors** | Executable behavior specifications | [behaviors/](./behaviors/README.md) |
| **Implementation** | Developer guides | [implementation/](./implementation/README.md) |
| **Maintenance** | Documentation maintenance workflows | [maintenance/](./maintenance/README.md) |

## Where to start

- New to the project? Read the [Product Vision](./product/vision.md), then the project [README](../README.md).
- Looking for design rationale? Browse [Decisions](./decisions/README.md).
- Adding or changing a feature? Start with [specs/](./specs/README.md) and [maintenance/update.md](./maintenance/update.md).
- Maintaining the docs themselves? Read the [Documentation Guide](./DOCUMENTATION-GUIDE.md).

## Other

- [Release Process](./maintenance/releasing.md)
- [Archive](./archive/) — historical PRDs, research, and dated audits
