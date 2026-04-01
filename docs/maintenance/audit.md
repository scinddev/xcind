# Documentation Audit

**For AI Agents**: Use this audit process to verify documentation completeness and accuracy.

**Terminology**: See the [Glossary](../DOCUMENTATION-GUIDE.md#glossary) for definitions of `DOCS_DIR` and other terms.

---

## Audit Configuration

- **Documentation Root** (`DOCS_DIR`): `docs/`
- **Install Type**: Fresh (Xcind-native documentation)

---

## Prerequisites

- Read the [DOCUMENTATION-GUIDE.md](../DOCUMENTATION-GUIDE.md) for layer placement rules
- Ensure you can run `make check` to verify no code was modified

---

## Critical Audit Principles

**IMPORTANT**: The docs use a layered structure with sub-directories. Before claiming any content is missing, you MUST:

1. **Read ALL Markdown files** under the documentation directory --- not just README.md files, but every `.md` file in every subdirectory including `appendices/` folders
2. **Read the full content of each file** --- not just the first section or summary
3. **Search across the entire documentation directory** using grep for key terms before concluding something is missing

**Why this matters**: Content that was in one large file may now be split across:
- Main `{topic}.md` files (overview, key concepts)
- Appendix files in `appendices/{topic}/` (detailed examples, code scaffolding, complete scripts)
- Multiple specification files (one per feature instead of one monolithic doc)

---

## Audit Process

### Step 1: Inventory Documentation

Scan the documentation root (`docs/`) and categorize all content:

#### 1a: Count All Content

For the entire documentation directory:
- List all Markdown files recursively
- Count total lines per file
- Calculate total lines across all files

```
DOCS_INVENTORY = {
  total_files: N,
  total_lines: N,
  files: [
    { path: "decisions/0001-example.md", lines: N },
    { path: "specs/feature.md", lines: N },
    { path: "specs/appendices/feature/details.md", lines: N },
    ...
  ]
}
```

#### 1b: Categorize by Layer

Group files by their layer:

```
LAYER_INVENTORY = {
  "decisions": {
    documents: N,
    total_lines: N,
    files: [...]
  },
  "product": {
    documents: N,
    total_lines: N,
    files: [...]
  },
  "architecture": { ... },
  "specs": { ... },
  "reference": { ... },
  "behaviors": { ... },
  "implementation": { ... }
}
```

#### 1c: Identify Appendix Content

Separately track appendix content:

```
APPENDIX_INVENTORY = {
  total_files: N,
  total_lines: N,
  by_parent: {
    "specs/appendices/feature-name": { files: N, lines: N },
    ...
  }
}
```

---

### Step 2: Analyze Content Distribution

#### 2a: Calculate Layer Distribution

For each layer, calculate:
- Percentage of total documentation
- Main content vs appendix content ratio
- Number of cross-references to other layers

#### 2b: Check for Orphaned Content

Identify files that:
- Are not linked from any index or README
- Don't follow naming conventions
- Appear to be duplicates

---

### Step 3: Verify Against Implementation

Compare documentation against the actual codebase:

```bash
# List all executables
ls bin/

# List all libraries
ls lib/xcind/

# Run tests to confirm code health
make test

# Full check
make check
```

For each documented feature:
- [ ] Feature exists in implementation
- [ ] Behavior matches what documentation describes
- [ ] CLI flags and options match `xcind-compose --help`, `xcind-config --help`, `xcind-proxy --help`

---

### Step 4: Generate Summary Report

Create a summary of the documentation state:

```markdown
## Documentation Summary

**Total Content**: {N} files, {M} lines

### Layer Distribution

| Layer | Files | Lines | % of Total |
|-------|-------|-------|------------|
| Decisions | {N} | {M} | {X}% |
| Vision | {N} | {M} | {X}% |
| Architecture | {N} | {M} | {X}% |
| Specifications | {N} | {M} | {X}% |
| Reference | {N} | {M} | {X}% |
| Behaviors | {N} | {M} | {X}% |
| Implementation | {N} | {M} | {X}% |

### Appendix Usage

| Parent Document | Appendix Files | Appendix Lines |
|-----------------|----------------|----------------|
| {path} | {N} | {M} |
| ... | ... | ... |

**Total Appendix Content**: {N} files, {M} lines ({X}% of total)
```

---

## Verification Checklist

After completing the audit:

- [ ] All Markdown files have been read in full
- [ ] Line counts are accurate (not estimated)
- [ ] Layer categorization is complete
- [ ] Appendix content is accounted for
- [ ] Summary report is generated
- [ ] `make check` passes (no accidental code modifications)
