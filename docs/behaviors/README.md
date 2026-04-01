# Behaviors

Executable behavior specifications for Xcind.

## Contents

This directory contains Gherkin feature files that verify expected system behaviors. These serve as **living documentation** --- if the tests pass, the documentation is accurate.

### The Living Documentation Advantage

Gherkin feature files serve triple duty:

1. **Specification** --- Defines expected behavior before implementation
2. **Documentation** --- Always accurate because it's tested
3. **Tests** --- Executable validation that prevents regression

If a Gherkin test passes, the documentation is accurate. If behavior changes, the test fails, forcing documentation updates.

### What Belongs Here

- Critical user journeys
- Integration scenarios
- Edge case behaviors
- Regression-prevention tests

### When to Use

Use executable specs for:
- **Behaviors that have historically broken** --- prevent regressions
- **Complex multi-step workflows** --- document the expected sequence
- **Integration points between components** --- verify contracts
- **Critical user journeys** --- ensure key paths always work
- **Behaviors described in specifications that must not regress**

## Directory Structure

Feature files are organized by domain:

```
behaviors/
├── README.md
├── config-resolution/           # Config loading and file resolution
│   ├── xcind-sh-discovery.feature
│   ├── override-files.feature
│   ├── variable-expansion.feature
│   ├── compose-file-defaults.feature
│   ├── project-naming.feature
│   └── app-env-injection.feature
├── proxy/                       # Reverse proxy integration
│   ├── hostname-generation.feature
│   ├── apex-routing.feature
│   └── traefik-labels.feature
└── workspace/                   # Workspace mode
    ├── workspace-mode.feature
    ├── network-aliases.feature
    └── self-declaration.feature
```

## Template

```gherkin
# This feature verifies behaviors from:
# See: ../../specs/{feature}.md

Feature: [Feature Name]
  As a [role]
  I want [capability]
  So that [benefit]

  Background:
    Given [common precondition]

  Scenario: [Scenario Name]
    Given [initial context]
    When [action is taken]
    Then [expected outcome]

  Scenario: [Edge Case Name]
    Given [edge case context]
    When [action is taken]
    Then [expected outcome]
```

## Linking to Specifications

Every behavior file should reference the specification it verifies. Add a comment at the top:

```gherkin
# This feature verifies behaviors from:
# See: ../../specs/context-detection.md
```

This creates traceability between the executable test and the specification it validates.

## Running Tests

Behavior scenarios are derived from the shell test suites:

```bash
# Run all tests
make test

# Run full check (lint + test)
make check
```

## Related Documents

- [DOCUMENTATION-GUIDE.md](../DOCUMENTATION-GUIDE.md) --- Full LDS reference with classification heuristics
- [Specifications](../specs/README.md) --- Specifications being verified
