# Layered Documentation System (LDS) --- Update

**For AI Agents**: This document contains instructions for updating documentation after implementation changes. Follow this process when code changes require documentation updates.

**Terminology**: See the [Glossary](../DOCUMENTATION-GUIDE.md#glossary) for definitions of key terms.

---

## When to Use This Guide

Use this guide when:
- Code implementation has changed
- A bug fix affects documented behavior
- A feature has been modified or extended
- Configuration options have changed
- CLI commands have been added or modified

**Do NOT use this guide for**:
- Quality improvements without code changes (use `refine.md`)
- Periodic audits (use `sync.md`)

---

## Update Process

### Step 1: Identify the Change Scope

Determine what changed in the implementation:

> **Implementation Change Summary**
>
> What changed?
> - [ ] New feature added
> - [ ] Existing feature modified
> - [ ] Feature removed
> - [ ] Bug fix that changes behavior
> - [ ] Configuration options changed
> - [ ] CLI commands changed
> - [ ] Dependencies or tech stack changed
>
> Describe the change: {brief description}

---

### Step 2: Identify Affected Documents

Based on the change type, identify which documents need updating:

| Change Type | Documents to Check |
|-------------|-------------------|
| New feature | `docs/specs/`, `docs/reference/` (+ appendices) |
| Feature modified | `docs/specs/`, `docs/reference/`, `docs/behaviors/` |
| Feature removed | All layers (remove references) |
| Bug fix (behavior change) | `docs/specs/`, `docs/behaviors/` |
| Config changed | `docs/reference/configuration.md`, `docs/specs/` if behavior affected |
| CLI changed | `docs/reference/cli.md`, `docs/specs/` if behavior affected |
| Dependencies changed | `docs/implementation/tech-stack.md`, possibly new ADR |

**Note**: Remember to check both main `{topic}.md` files and `appendices/{topic}/` directories.

---

### Step 3: Check Document Hierarchy

Determine the **authoritative source** for the changed information:

1. ADRs --- If the change contradicts an ADR, update or supersede the ADR first
2. Specifications --- Primary target for behavior changes
3. Reference --- Primary target for CLI/config changes
4. Behaviors --- Update Gherkin scenarios to match new behavior
5. Implementation --- Update if tech stack changed

---

### Step 4: Check for Decision Changes

Does this implementation change imply a new architectural decision?

Signals that an ADR is needed:
- "We changed from X to Y because..."
- "We're now using a different pattern..."
- "This breaks backward compatibility because..."

If yes, create a new ADR in `docs/decisions/` before proceeding.

---

### Step 5: Update Authoritative Document

#### For Specification Updates

1. Read the current specification (`docs/specs/{feature}.md`)
2. Also read any appendices in `docs/specs/appendices/{feature}/`
3. Update behavior descriptions to match new implementation
4. Update examples that are now incorrect
5. Increment the patch version
6. Add entry to Revision History table

#### For Reference Updates

1. Read the current reference document (`docs/reference/{topic}.md`)
2. Update syntax, options, defaults as needed
3. Update examples
4. Check thresholds: new large content may need to go to appendix

#### For Behavior Updates

1. Read the current feature file in `docs/behaviors/`
2. Update Given/When/Then steps to match new behavior
3. Add new scenarios for new behavior
4. Remove scenarios for removed behavior

---

### Step 6: Cascade Updates

After updating the authoritative source, update derived/referencing documents:

```
ADR (if new decision)
    ↓
Specification (behavior details)
    ↓
Reference (command/config details)
    ↓
Behaviors (test scenarios)
    ↓
Architecture (if structural change)
```

---

### Step 7: Verify

1. Check all cross-links between updated documents are still valid
2. Run `make check` to confirm no unintended code changes
3. Verify examples are accurate and runnable

---

### Step 8: Final Report

> **Documentation Update Complete**
>
> **Change**: {description}
>
> **Documents Updated**:
> | Document | Changes Made |
> |----------|--------------|
> | `docs/specs/X.md` | Updated Y behavior |
> | `docs/reference/cli.md` | Added Z option |
> | `docs/behaviors/{domain}/X.feature` | Updated scenario |
>
> **Cross-Links Verified**: Yes
> **New ADR Created**: {Yes: ADR-NNNN | No}
> **`make check` Passed**: Yes

---

## Quick Reference

### Change Type → Primary Document

| Change | Update First |
|--------|--------------|
| Behavior change | Specification |
| New CLI option | Reference (CLI) |
| Config change | Reference (Config) |
| Architecture change | Architecture → new ADR if significant |
| Decision change | New ADR (supersedes old) |
