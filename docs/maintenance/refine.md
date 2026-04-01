# Layered Documentation System (LDS) --- Refine

**For AI Agents**: This document contains instructions for improving documentation quality without implementation changes. Use this for documentation review cycles, clarity improvements, and structural enhancements.

**Terminology**: See the [Glossary](../DOCUMENTATION-GUIDE.md#glossary) for definitions of key terms.

---

## When to Use This Guide

Use this guide for:
- Documentation quality reviews
- Improving clarity and readability
- Fixing structural issues (wrong layer, duplication)
- Enhancing cross-linking
- Filling gaps in existing documentation
- Consolidating scattered information

**Do NOT use this guide for**:
- Updating after code changes (use `update.md`)
- Auditing against implementation (use `sync.md`)

---

## Refinement Categories

1. **Layer Placement** --- Is content in the correct layer?
2. **Appendix Structure** --- Is large content properly in appendices?
3. **Duplication** --- Is information mastered in one place only?
4. **Cross-Linking** --- Are related documents properly connected?
5. **ADR Coverage** --- Are major decisions documented?
6. **Completeness** --- Are all features/options documented?
7. **Template Compliance** --- Do documents follow templates?
8. **Clarity** --- Is content clear and unambiguous?

---

## Refinement Process

### Step 1: Select Refinement Scope

Determine the scope of this refinement session:

> **Refinement Scope**
>
> What would you like to refine?
> 1. **Full audit** --- Review all documentation
> 2. **Single layer** --- Focus on one layer (specify which)
> 3. **Single document** --- Focus on one document (specify which)
> 4. **Specific category** --- Focus on one refinement category
>
> Selection: {1/2/3/4}

Store as `REFINEMENT_SCOPE`.

---

### Step 2: Layer Placement Review

For each document (or scoped subset), verify content is in the correct layer.

#### 2a: Read Each Document

For each section of content, apply the classification decision tree from the [DOCUMENTATION-GUIDE.md](../DOCUMENTATION-GUIDE.md#classification-decision-tree).

#### 2b: Record Misplacements

> **Layer Placement Issues**
>
> | Document | Section | Current Layer | Should Be |
> |----------|---------|---------------|-----------|
> | `specs/foo.md` | "Why we chose X" | Specifications | Decisions (ADR) |

#### 2c: Resolve Misplacements

For each misplacement:
1. Extract the content from current location
2. Create or update document in correct layer
3. Replace original content with a link to new location
4. Update cross-references

---

### Step 3: Appendix Structure Review

Check that large content is properly placed in appendices per `DOCUMENTATION-GUIDE.md` thresholds:
- Code blocks >= 50 lines
- Step lists >= 10 items
- Tables >= 20 rows
- Complete file examples (always)
- Error catalogs (always)
- Shell scripts (always)

**Exception**: ADRs never use appendices --- all content stays inline.

---

### Step 4: Duplication Review

Check for information that appears in multiple places (SSOT violations).

| Pattern | Example | Resolution |
|---------|---------|------------|
| Decision rationale in specs | "We chose X because Y" in spec | Move to ADR, link from spec |
| Config details in specs | Full schema in specification | Move to reference, link from spec |
| Behavior details in reference | "When X happens" in CLI docs | Keep in spec, simplify reference |

---

### Step 5: Cross-Linking Review

Ensure documents are properly interconnected per the [Cross-Layer Linking](../DOCUMENTATION-GUIDE.md#cross-layer-linking) guidelines.

| From | To | Link Purpose |
|------|----|--------------|
| Specification | ADR | Explain "why" for design choices |
| Specification | Reference | Point to detailed syntax/options |
| Architecture | ADR | Justify architectural patterns |
| Behavior | Specification | Reference the spec being tested |
| Implementation | ADR | Explain technology choices |

---

### Step 6: ADR Coverage Review

Scan specifications and architecture docs for decision signals:
- "We chose X..."
- "We decided to..."
- "Unlike typical approaches, we..."
- Trade-off discussions

For each potential decision, ask:
- Is this a significant architectural decision?
- Would it be expensive to reverse?
- Is it already documented as an ADR?

---

### Step 7: Completeness Review

For each feature in Xcind:
- [ ] Has a specification document
- [ ] CLI commands documented in reference (`docs/reference/cli.md`)
- [ ] Configuration options documented (`docs/reference/configuration.md`)
- [ ] Has Gherkin behavior tests (for critical features, in `docs/behaviors/`)

---

### Step 8: Apply Refinements

Execute all identified improvements:

1. **Layer relocations**: Move content, add links
2. **Appendix restructuring**: Move large content to appendices
3. **Deduplication**: Consolidate, add links
4. **Cross-links**: Add missing links
5. **ADRs**: Create missing decision records in `docs/decisions/`
6. **Gaps**: Create stub documents or sections
7. **Templates**: Add missing sections
8. **Clarity**: Improve wording

After changes, run `make check` to confirm no code was accidentally modified.

---

## Quick Reference

### Refinement Priority Order

1. **Layer placement** --- Foundation for other fixes
2. **Appendix structure** --- Ensures thresholds respected
3. **Duplication** --- Prevents conflicting information
4. **ADR coverage** --- Preserves decision rationale
5. **Cross-links** --- Enables navigation
6. **Completeness** --- Fills gaps
7. **Template compliance** --- Consistency
8. **Clarity** --- Polish

### Layer Authority (for deduplication)

When content appears in multiple layers, keep it in the higher-authority layer:

1. ADRs (highest)
2. Vision
3. Architecture
4. Specifications
5. Reference
6. Behaviors
7. Implementation (lowest)
