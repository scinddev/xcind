# Xcind Documentation Guide

**For AI Agents and Contributors**: This guide explains how Xcind's documentation is organized and how to maintain it.

Xcind implements concepts from the [Scind specification](https://github.com/scinddev/scind). The engineering documentation in this directory follows the Layered Documentation System (LDS) defined in [ADR-0011](./decisions/0011-layered-documentation-system.md). The two-track split between user and engineering documentation is established in [ADR-0014](./decisions/0014-two-track-documentation.md).

---

## Two-Track Documentation

Xcind has **two distinct tracks** of documentation, with different audiences, purposes, and conventions:

| Track | Directory | Audience | Shape |
|-------|-----------|----------|-------|
| **User documentation** | [`docs/`](../docs/) | People installing, configuring, and running Xcind against their projects | [Diátaxis](https://diataxis.fr) (Tutorials / How-to guides / Reference / Explanation) |
| **Engineering documentation** | `engineering/` (this tree) | Contributors and AI agents building or maintaining Xcind itself | Layered Documentation System (LDS) — see below |

### Diátaxis primer (user track)

| Quadrant | Purpose | Lives in | What belongs | What doesn't |
|----------|---------|----------|--------------|--------------|
| **Tutorial** | Learning by doing | `docs/getting-started/` | Step-by-step "first project" walkthroughs | Comprehensive option lists |
| **How-to** | Solving a specific task | `docs/guides/` | "How do I set up the proxy?", "How do I add Xcind to an existing project?" | Conceptual deep-dives |
| **Reference** | Looking up facts | `docs/reference/` | Slim narrative summaries of CLI / config; defer to engineering reference for exhaustive detail | Tutorials, design rationale |
| **Explanation** | Understanding | `docs/explanation/` | Why naming works the way it does, what the overlay model is | Step-by-step instructions |

### Cross-track linking

- User reference (`docs/reference/`) **may** link out to engineering reference (`engineering/reference/`) for exhaustive detail.
- Engineering documents **should not** link into user docs except from this guide and the top-level READMEs.
- Both tracks are public and live in this repo. "Engineering" does not mean private.

---

## Engineering Track (LDS)

The rest of this document covers the engineering track, which lives entirely under `engineering/`.

---

## Glossary

### Directory Terminology

| Term | Definition |
|------|------------|
| `USER_DOCS_DIR` | The user documentation root (`docs/`) — Diátaxis-shaped |
| `ENG_DOCS_DIR` | The engineering documentation root (`engineering/`) — LDS canon |

### Core System Terms

| Term | Definition |
|------|------------|
| **Layered Documentation System (LDS)** | A documentation framework organizing design documentation into seven distinct layers |
| **Layer** | A distinct category of documentation with a specific purpose, stability level, and lifecycle |

### Canonical Layer Names

| Layer | Canonical Name | Directory |
|-------|---------------|-----------|
| 1 | **Decisions** | `decisions/` |
| 2 | **Vision** | `product/` |
| 3 | **Architecture** | `architecture/` |
| 4 | **Specifications** | `specs/` |
| 5 | **Reference** | `reference/` |
| 6 | **Behaviors** | `behaviors/` |
| 7 | **Implementation** | `implementation/` |

### Key Terms

| Term | Definition |
|------|------------|
| **ADR** | Architecture Decision Record — an immutable document capturing a significant decision |
| **Appendix** | A supplementary file containing large content, stored in `appendices/{topic}/` |
| **Drift** | When documentation and implementation become out of sync |

---

## Core Principles

1. **Single Source of Truth**: Each piece of information lives in exactly one place
2. **Separation of Concerns**: Different document types serve different purposes
3. **Appropriate Stability**: Some documents are immutable; others evolve constantly
4. **Clear Ownership**: Each layer has defined maintainers and update triggers
5. **Linkage Over Duplication**: Reference other documents rather than copying content
6. **Appendix for Scale**: Large content lives in appendices, keeping main docs scannable

---

## Layer Overview

| Layer | Directory | Purpose | Stability | Audience |
|-------|-----------|---------|-----------|----------|
| 1. Decisions | `decisions/` | Capture WHY choices were made | Immutable | Future maintainers |
| 2. Vision | `product/` | Define WHAT we're building | Stable | All stakeholders |
| 3. Architecture | `architecture/` | Show HOW components relate | Evolving | Engineers, architects |
| 4. Specifications | `specs/` | Detail HOW features work | Living | Engineers |
| 5. Reference | `reference/` | Provide lookup tables | Generated/maintained | Engineers |
| 6. Behaviors | `behaviors/` | Verify expected behaviors | Executable | QA, engineers |
| 7. Implementation | `implementation/` | Guide HOW to build | Short-lived | Implementing engineers |

---

## Classification Decision Tree

When adding new content, use this tree to determine the correct layer:

```
Is this explaining WHY a choice was made?
├─ YES → Layer 1: Decisions (ADR)
└─ NO ↓

Is this about product vision, goals, or concepts?
├─ YES → Layer 2: Vision
└─ NO ↓

Is this showing how components relate (diagrams, flows)?
├─ YES → Layer 3: Architecture
└─ NO ↓

Is this detailing HOW a feature works (behavior, edge cases)?
├─ YES → Layer 4: Specifications
└─ NO ↓

Is this a lookup table (commands, options, configs)?
├─ YES → Layer 5: Reference
└─ NO ↓

Is this a concrete verifiable scenario (Given/When/Then)?
├─ YES → Layer 6: Behaviors
└─ NO ↓

Is this implementation scaffolding (code templates, dependencies)?
├─ YES → Layer 7: Implementation
└─ NO → May not need documentation
```

---

## Cross-Layer Linking

Documents should link to related content in other layers:

| From | Link To | Purpose |
|------|---------|---------|
| Specifications | ADRs | Explain "why" for design choices |
| Specifications | Reference | Point to detailed syntax |
| Architecture | ADRs | Justify architectural patterns |
| Architecture | Specifications | Deep-dive into component behavior |
| Reference | Specifications | Provide conceptual context |
| Implementation | ADRs | Explain technology choices |
| Implementation | Specifications | Reference what's being implemented |
| Behaviors | Specifications | Reference the spec being verified |

### Link Format

```markdown
## Related Documents

- [ADR-0008: Traefik Reverse Proxy](../decisions/0008-traefik-reverse-proxy.md) — Design rationale
- [Proxy Specification](../specs/proxy-infrastructure.md) — Detailed behavior
```

---

## Document Hierarchy (Authority Order)

When content appears in multiple places, this hierarchy determines the canonical source:

```
┌─────────────────────────────────────────────────────────────┐
│                      MOST AUTHORITATIVE                     │
├─────────────────────────────────────────────────────────────┤
│  ADRs (Architectural Decision Records)                      │
│  - Decisions are immutable once accepted                    │
│  - If anything conflicts with ADR, ADR wins                 │
├─────────────────────────────────────────────────────────────┤
│  Gherkin Feature Files                                      │
│  - Executable specifications                                │
│  - If test passes, documentation is accurate                │
├─────────────────────────────────────────────────────────────┤
│  Vision (PRD)                                               │
│  - High-level "what" and "why"                              │
├─────────────────────────────────────────────────────────────┤
│  Technical Specification                                    │
│  - Architecture and schemas                                 │
├─────────────────────────────────────────────────────────────┤
│  Reference Documentation (CLI, Config)                      │
│  - Factual, complete, lookup-oriented                       │
├─────────────────────────────────────────────────────────────┤
│  Implementation Guides (Tech Stack)                         │
│  - How to build, patterns to follow                         │
│                     LEAST AUTHORITATIVE                     │
└─────────────────────────────────────────────────────────────┘
```

---

## Directory Structure

```
engineering/
├── README.md                    # Engineering doc index
├── DOCUMENTATION-GUIDE.md       # This file
│
├── decisions/                   # Layer 1: ADRs (simple files)
│   ├── README.md               # ADR index
│   ├── 0000-template.md        # Template
│   └── 0001-*.md ... NNNN-*.md # ADR files
│
├── product/                     # Layer 2: Vision
│   ├── README.md
│   ├── vision.md
│   ├── glossary.md
│   ├── comparison.md
│   └── roadmap.md
│
├── architecture/                # Layer 3: Architecture
│   ├── README.md
│   └── overview.md
│
├── specs/                       # Layer 4: Specifications
│   ├── README.md
│   ├── {feature}.md            # Main spec files
│   └── appendices/
│       └── {feature}/          # Per-spec appendices
│
├── reference/                   # Layer 5: Reference (exhaustive)
│   ├── README.md
│   ├── cli.md
│   ├── configuration.md
│   ├── build-provenance.md
│   ├── devcontainers.md
│   └── appendices/
│
├── behaviors/                   # Layer 6: Behaviors
│   ├── README.md
│   └── {domain}/
│       └── {feature}.feature
│
├── implementation/              # Layer 7: Implementation
│   ├── README.md
│   ├── tech-stack.md
│   └── project-layout.md
│
├── maintenance/                 # Maintenance workflows
│   ├── audit.md
│   ├── refine.md
│   ├── sync.md
│   ├── update.md
│   └── releasing.md             # Release process
│
└── archive/                     # Historical documents (PRDs, research, dated audits)
```

---

## Appendix Guidelines

### When to Use Appendices

Move content to appendices when it exceeds these thresholds:
- Code blocks >= 50 lines
- Step lists >= 10 items
- Tables >= 20 rows
- Complete file examples (always)
- Error catalogs (always)
- Shell scripts (always)

**Exception**: ADRs never use appendices — all content stays inline.

### Appendix Directory Structure

```
specs/
├── shell-integration.md          # Main document
└── appendices/
    └── shell-integration/        # Named after main document
        ├── bash-setup.sh
        └── zsh-setup.zsh
```

### Linking to Appendices

From main document:
```markdown
For complete shell scripts, see:
- [Bash Setup](./appendices/shell-integration/bash-setup.sh)
```

From appendix (back-link):
```markdown
> **Parent**: [Shell Integration](../../shell-integration.md)
```

---

## Single Source of Truth (SSOT)

Every fact should be mastered in exactly one place:

| Information Type | Canonical Source | Referenced From |
|------------------|------------------|-----------------|
| Why we chose X over Y | ADR | Vision, Specs, Architecture |
| Configuration variables | Reference docs | Specs |
| Command syntax | CLI Reference | Specs |
| Feature behavior | Specification | Gherkin tests |
| Naming conventions | Specification | ADR (for rationale) |

**Key Principle**: When you find yourself copying information, create a reference instead.

---

## Tooling

| Tool | Purpose | Setup |
|------|---------|-------|
| **shfmt** | Shell formatting | `brew install shfmt` or via Nix |
| **shellcheck** | Shell linting | `brew install shellcheck` or via Nix |
| **markdownlint** | Markdown linting | `npm install --save-dev markdownlint-cli` |

---

## Maintenance Workflows

Four workflows are available in `maintenance/`:

| Workflow | Purpose | When to Use |
|----------|---------|-------------|
| `audit.md` | Verify documentation completeness | Periodically |
| `refine.md` | Improve quality without code changes | Documentation reviews |
| `sync.md` | Verify docs match implementation | Pre-release, after refactoring |
| `update.md` | Update docs after code changes | When implementation changes |
