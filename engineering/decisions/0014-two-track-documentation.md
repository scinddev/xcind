# Two-Track Documentation: User (Diátaxis) + Engineering (LDS)

**Status**: Accepted

## Context

[ADR-0011](./0011-layered-documentation-system.md) established the Layered Documentation System (LDS) with seven layers (decisions, product, architecture, specs, reference, behaviors, implementation). LDS works well for the audience it was designed for — contributors and AI agents who need to understand, change, and validate Xcind's internals — but it is not the right shape for end users who only want to install Xcind, configure their `.xcind.sh`, and run their compose project.

By the time the project README reached ~760 lines, it was clearly serving as a stand-in user manual. End users had to wade through ADR pointers and architecture diagrams to find the proxy walkthrough; contributors had to scroll past install instructions to reach the file-structure tour. Diátaxis (the dominant framework for end-user product documentation, used by Django, NumPy, Cloudflare, FastAPI, and others) explicitly excludes ADRs and specifications from its scope — which confirmed that the two audiences are different shapes, not different volumes, of documentation.

## Decision

Adopt a two-track documentation model:

| Track | Directory | Audience | Shape |
|-------|-----------|----------|-------|
| **User documentation** | `docs/` | People installing, configuring, and running Xcind against their projects | [Diátaxis](https://diataxis.fr): tutorials, how-to guides, reference, explanation |
| **Engineering documentation** | `engineering/` | Contributors and AI agents building or maintaining Xcind itself | Layered Documentation System (LDS) per ADR-0011 |

The previous `docs/` directory (containing the LDS) is renamed to `engineering/`. A new `docs/` directory holds the Diátaxis-shaped user documentation. The project `README.md` shrinks to install + minimal quick-start + signposting to `docs/` and `engineering/`.

Key conventions:

- **Cross-track linking**: User reference (`docs/reference/`) **may** link out to engineering reference (`engineering/reference/`) for exhaustive detail. Engineering documents **should not** link into user docs except from top-level READMEs.
- **Reference duplication is intentional**: `docs/reference/configuration.md` and `engineering/reference/configuration.md` are not the same document. The user version is a slim narrative covering the variables most users actually set; the engineering version remains the exhaustive, authoritative reference. The user version footers with a pointer to the engineering version.
- **Single Source of Truth still applies within each track**, per ADR-0011's principles. Authoritative facts about behavior remain in `engineering/specs/` and `engineering/reference/`.

This ADR extends ADR-0011; it does not supersede it. LDS continues to govern the engineering track unchanged.

## Consequences

### Positive

- End users get documentation shaped to their tasks, with clear progression from getting started → guides → reference → explanation.
- Engineering canon stays intact and authoritative; contributors and AI agents continue to use the LDS conventions they know.
- The project README can stop being a manual and become a signpost.
- The user-doc layout is compatible with mdBook / VitePress / Starlight if a static site is added later.

### Negative

- Slight duplication risk between `docs/reference/*` and `engineering/reference/*`. Mitigation: user reference stays narrative-only — no flag tables, nothing canonical to drift from.
- External inbound links pointing at `docs/decisions/...` from the previous layout break. Acceptable at the project's current scale.
- Contributors now need to be aware that two directories exist and that they serve different audiences. The Documentation Guide and the top-level READMEs make this explicit.

### Neutral

- The term "engineering documentation" replaces the implicit "the docs" framing. The Documentation Guide adds a "Two-Track Documentation" section defining both terms.

## Related Documents

- [ADR-0011: Layered Documentation System](./0011-layered-documentation-system.md) — the LDS that governs the engineering track
- [Documentation Guide](../DOCUMENTATION-GUIDE.md) — full guidance on both tracks
- [User docs README](../../docs/README.md) — user-track entry point
- [Engineering docs README](../README.md) — engineering-track entry point
