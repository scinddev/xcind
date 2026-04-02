---
name: update-completions
description: Update shell completion scripts when CLI flags, options, or subcommands are added, removed, or renamed in bin/xcind-config, bin/xcind-proxy, or bin/xcind-compose. TRIGGER when the interface of any xcind command changes.
---

# Update Completions

TRIGGER when: flags, options, or subcommands are added, removed, or renamed in
`bin/xcind-config`, `bin/xcind-proxy`, or `bin/xcind-compose`.

## Instructions

When any xcind command's CLI interface changes, the shell completion scripts must
be updated to match.

### Steps

1. **Identify which command changed** and what flags/subcommands were
   added, removed, or renamed.
2. **Update `lib/xcind/xcind-completion-bash.bash`** — find the corresponding
   completion function (`_xcind_config_completions`, `_xcind_proxy_completions`,
   or `_xcind_compose_completions`) and update the `compgen -W` word lists and
   any context-sensitive `case` branches.
3. **Update `lib/xcind/xcind-completion-zsh.bash`** — find the corresponding
   completion function (`_xcind-config`, `_xcind-proxy`, or `_xcind-compose`)
   and update the `_describe` arrays and any context-sensitive `case` branches.
4. **Update help text** — if `xcind-config` changed, also update
   `__xcind_config_usage()` in `bin/xcind-config`.
5. **Run `make check`** to verify lint and tests pass.

### Important

- Both bash and zsh completion files must stay in sync with each other and with
  the actual CLI interface.
- The completion files are self-contained scripts output by
  `xcind-config completion {bash|zsh}` — they must not reference internal xcind
  functions or variables.
