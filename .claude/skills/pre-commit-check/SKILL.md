---
name: pre-commit-check
description: Run make check until it passes cleanly before committing any code changes
---

# Pre-Commit Check

TRIGGER when: the user asks to commit, or you are about to create a git commit after code changes.

## Instructions

Before creating any git commit, you MUST run `make check` and ensure it exits cleanly (zero errors). Do not commit until it does.

### Steps

1. **Run `make check`.**
2. **If lint or format errors:**
   - Run `make format` to auto-fix.
   - Re-run `make check`.
   - If errors remain, fix them manually and re-run `make check`.
3. **If test failures:**
   - Fix the failing tests or the code they exercise.
   - Re-run `make check`.
4. **Repeat** until `make check` passes with zero errors across all stages (lint, test).
5. **Only then** proceed with the git commit.

### Important

- Never skip or bypass this procedure.
- Never pass `--no-verify` to git commit.
- If `make check` keeps failing after multiple attempts, stop and report the issue to the user instead of committing broken code.
