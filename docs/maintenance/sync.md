# Layered Documentation System (LDS) --- Sync

**For AI Agents**: This document contains instructions for auditing documentation against the current implementation and synchronizing any drift. Use this for periodic maintenance or before releases.

**Terminology**: See the [Glossary](../DOCUMENTATION-GUIDE.md#glossary) for definitions of key terms.

---

## When to Use This Guide

Use this guide for:
- Periodic documentation audits (monthly, quarterly)
- Pre-release documentation verification
- After significant refactoring
- When documentation accuracy is questioned

**Do NOT use this guide for**:
- Updating after known code changes (use `update.md`)
- Quality improvements (use `refine.md`)

---

## Sync Process Overview

```
1. Audit Reference Docs  → Are CLI/config references current?
2. Verify Cross-Links    → Are all links valid?
3. Check Specifications  → Do specs match implementation?
4. Review ADRs           → Are decisions still current?
5. Resolve Drift         → Fix discrepancies
6. Report Findings       → Document audit results
```

---

## Sync Process

### Step 1: Audit Reference Docs

Reference documentation should match the current implementation exactly.

#### 1a: CLI Reference Audit

Compare `docs/reference/cli.md` against actual CLI:

```bash
# Get actual CLI help
xcind-compose --help
xcind-config --help
xcind-proxy --help
xcind-proxy init --help
xcind-proxy up --help
xcind-proxy down --help
xcind-proxy status --help
```

For each command documented:
- [ ] Command exists in CLI
- [ ] All options are documented
- [ ] All documented options exist
- [ ] Defaults match actual defaults
- [ ] Examples work as shown

Record discrepancies:

> **CLI Reference Drift**
>
> | Issue | Document Says | CLI Actually |
> |-------|---------------|--------------|
> | Missing option | --- | `--new-flag` exists |
> | Wrong default | `--port=8080` | `--port=3000` |

#### 1b: Configuration Reference Audit

Compare `docs/reference/configuration.md` against actual config handling in `lib/xcind/xcind-lib.bash`:

For each option:
- [ ] Option exists in code
- [ ] Default in docs matches code default
- [ ] Type is correct
- [ ] Environment variable mapping correct

---

### Step 2: Verify Cross-Links

Check that all internal documentation links are valid.

#### 2a: Collect All Links

Scan all Markdown files for internal links:
```markdown
[Link text](../path/to/file.md)
[Link text](./file.md#section)
```

#### 2b: Validate Each Link

For each link:
- [ ] Target file exists
- [ ] Target section exists (if anchor specified)
- [ ] Link text is still accurate

---

### Step 3: Check Specifications Against Implementation

For each specification in `docs/specs/`:

#### 3a: Read the Specification

Read `docs/specs/{topic}.md` and any `appendices/{topic}/` files. Identify key behavioral claims.

#### 3b: Verify Against Code

For each claim, verify it matches implementation in `bin/` and `lib/xcind/`:
- Check the relevant code paths
- Verify error handling matches
- Verify configuration defaults match

#### 3c: Record Discrepancies

> **Specification Drift**
>
> | Specification | Claim | Actual Behavior |
> |---------------|-------|-----------------|
> | `proxy-infrastructure.md` | "Default domain is localhost" | Verified correct |

---

### Step 4: Review ADR Currency

For each ADR in `docs/decisions/`:

- Is the decision still "Accepted"?
- Has it been superseded without marking?
- Is the decision actually implemented?

If implementation differs from ADR:
1. **If intentional**: Create new ADR to supersede
2. **If unintentional**: Flag as implementation bug

---

### Step 5: Resolve Drift

For each discrepancy found:

```
Is the documentation correct and code wrong?
├─ YES → File implementation bug
└─ NO ↓

Is the code correct and documentation wrong?
├─ YES → Update documentation (use update.md)
└─ NO ↓

Is this an intentional undocumented change?
├─ YES → Document the change, possibly new ADR
└─ NO → Investigate further
```

---

### Step 6: Execute Resolutions and Report

After resolving all drift:

1. **Re-check links**: All should resolve
2. **Run `make check`**: Confirm no code was modified
3. **Spot-check specs**: Sample verification

> **Documentation Sync Audit Report**
>
> **Date**: {date}
>
> | Category | Issues Found | Resolved | Remaining |
> |----------|--------------|----------|-----------|
> | CLI Reference | {N} | {N} | {N} |
> | Config Reference | {N} | {N} | {N} |
> | Specifications | {N} | {N} | {N} |
> | Cross-Links | {N} | {N} | {N} |
> | ADRs | {N} | {N} | {N} |

---

## Quick Reference

### Audit Frequency Recommendations

| Project Phase | Audit Frequency |
|---------------|-----------------|
| Active development | Monthly |
| Maintenance mode | Quarterly |
| Pre-release | Always |
| Post-major-refactor | Always |

### Priority Order for Fixes

1. **Reference doc drift** --- Users rely on these
2. **Broken links** --- Breaks navigation
3. **Spec drift** --- Important for developers
4. **ADR currency** --- Historical accuracy

### Drift Detection Signals

| Signal | Likely Cause |
|--------|--------------|
| CLI --help differs from docs | Docs not updated after CLI change |
| Config defaults wrong | Code changed without doc update |
| Broken links | File renamed, deleted, or moved to appendix |
| ADR not implemented | Incomplete implementation or changed plan |
