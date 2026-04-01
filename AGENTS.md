# AGENTS.md

Xcind: slim Docker Compose wrapper with per-application config. Bash 3.2+, shell throughout.

## Commands
```bash
make test      # Run tests
make format    # Fix shell formatting (shfmt --write)
make lint      # Check formatting + shellcheck
make check     # lint + test (REQUIRED before completing code tasks)
```

## If: Running Tests, Linting, or Type Checking

**Do:** Use make targets.
```bash
make test      # not: test/test-xcind.sh
make check     # not: pre-commit
```

**Don't:** Invoke tooling or scripts directly unless it relates to one specific
issue or concern.

## If: You Added a New bin/ or lib/xcind/ File

The `add-installed-file` skill will trigger automatically. Follow its instructions
to register the file in all manifests.

## If: You Changed Code

Run `make check` and confirm it passes before marking the task complete.

**This is required for every code change.**

## If: Lint or Format Errors

Run `make format` to auto-fix, then re-run `make check`.

## Before Committing

Always follow the pre-commit check procedure in
`.claude/skills/pre-commit-check/SKILL.md`. Do not commit until `make check`
passes with zero errors.
