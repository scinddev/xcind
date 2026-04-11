# Audit Follow-ups — April 2026

Short-lived implementation guides for the work packages deferred from the
April 2026 audit cleanup (PR #44 — "Audit cleanups: yq hook consistency,
helper extraction, test fixes").

Each numbered file is a self-contained work package that can be tackled in
its own follow-up context (new chat, new PR). The PR that produced these
packages summarizes what was fixed and what was deferred; these files pick
up from there.

**Delete this directory once every package ships.** These docs are
intentionally short-lived and should not accumulate as historical noise. If a
package grows a larger design rationale, promote it to a proper ADR under
`docs/decisions/`.

---

## Package index

| # | Package | Scope | Risk | Can run in parallel with |
|---|---------|-------|------|--------------------------|
| [01](./01-status-json-jq-refactor.md) | `xcind-proxy status` JSON → `jq -n` | Small | Low | 02, 03, 04 |
| [02](./02-test-infrastructure-hardening.md) | Extract assert helpers, mktemp cleanup, reset helper | Medium | Low | 01, 04, 05 |
| [03](./03-test-coverage-gaps.md) | CLI / concurrency / hook-error tests | Large | Low | 01, 04, 05 |
| [04](./04-lib-safety-cleanups.md) | Small lib/ cleanups (check-deps, IFS, trust boundary doc) | Small | Low | 01, 02, 03, 05 |
| [05](./05-bin-script-polish.md) | Small bin/ fixes (empty-value parse, glob hidden dirs, etc.) | Small | Low | 02, 03, 04 |
| [06](./06-tsv-read-loop-refactor.md) | `xcind-assigned-lib.bash` TSV read-loop helper | Medium | Medium | — (do last) |

Each package's file covers: problem, evidence (file:line refs), proposed
fix with code snippets, acceptance criteria, risk, and explicit dependencies.
Read the package file before starting the work — none of them are so small
that "just do it" is faster than 5 minutes of reading.

---

## Dependency graph

```
              ┌──────────────────────────┐
              │ 02 Test infra hardening  │  ← foundation: extract helpers,
              │  (shared assert.sh,      │    add cleanup traps, factor
              │   mktemp trap, reset fn) │    duplicated reset blocks
              └────────┬─────────────────┘
                       │
       ┌───────────────┼─────────────────────────┐
       ▼               ▼                         ▼
┌─────────────┐ ┌──────────────────┐ ┌──────────────────────┐
│ 01 status   │ │ 04 lib safety    │ │ 05 bin script polish │
│    JSON→jq  │ │    cleanups      │ │                      │
└─────┬───────┘ └────────┬─────────┘ └─────────┬────────────┘
      │                  │                     │
      └──────────────────┴─────────────────────┘
                         │
                         ▼
              ┌──────────────────────────┐
              │ 03 Test coverage gaps    │  ← new tests should use the
              │  (CLI / concurrency /    │    helpers extracted in #02
              │   hook-error)            │
              └────────┬─────────────────┘
                       │
                       ▼
              ┌──────────────────────────┐
              │ 06 TSV read-loop refactor│  ← verified by concurrency
              │  (xcind-assigned-lib)    │    tests added in #03
              └──────────────────────────┘
```

---

## Recommended order of operations

1. **Do #02 first.** It extracts `test/lib/assert.sh` and introduces cleanup
   helpers. Every other test-touching package benefits from having the
   helpers in place. Delaying it means doing the same extraction later under
   merge pressure from other changes.

2. **Do #01, #04, and #05 in parallel (or any order).** They touch
   independent files and have no shared failure modes. Each is a single-sitting
   change.

   - **Coordination caveat:** #01 and #05 both touch `bin/xcind-proxy`. If
     different people/sessions take them on, the later one rebases cleanly,
     but don't split #01 between them.

3. **Do #03 after #02.** New tests should source `test/lib/assert.sh` and
   use `_register_tmp`. Doing #03 before #02 means rewriting the new tests
   during #02.

4. **Do #06 last.** The refactor is mechanical but only safe to validate once
   #03 has landed the concurrent-flock tests. Without those tests you're
   flying blind on the hot path.

---

## Conflict warnings

| If you touch... | Watch for conflicts from... |
|-----------------|-----------------------------|
| `test/test-xcind.sh` (any header change) | #02 and #03 both modify test headers; sequence them |
| `test/test-xcind-proxy.sh` (any header change) | #02 and #03 both modify test headers; sequence them |
| `bin/xcind-proxy` | #01 rewrites the status JSON block; #05 touches smaller things nearby |
| `lib/xcind/xcind-lib.bash` | #04 touches `__xcind-check-deps` (nested fns) |
| `lib/xcind/xcind-assigned-lib.bash` | #06 is the only package touching this file |

The safest parallelism split: one context does #02 → #03, another does
#01, a third does #04, a fourth does #05. #06 blocks on #03 finishing.

---

## What is *not* in this directory

Genuine style nitpicks, single-line cosmetic changes, and speculative "would
be nice" ideas from the deep Bash audit are intentionally left out. Each
package here represents work that has a real user-visible benefit — a
correctness improvement, a maintenance burden removal, or a coverage gap
closed. If you find yourself wanting to add a seventh package for "we could
also rename this variable" — don't. Put it in a follow-up commit instead.

A few items from the deep audit that were considered and rejected:

- **`xcind-lib.bash:611` empty-array loop "bug"** — the original audit
  agent was wrong; `"${arr[@]+"${arr[@]}"}"` correctly expands to zero
  args when the array is empty under Bash 3.2+. Verified.
- **`xcind-assigned-lib.bash:85` `grep -qE "[:.]${port}\$"` regex** — the
  anchor makes a practical false positive hard to construct; the current
  form is fine and "parse with awk" is a micro-optimization, not a fix.
- **`xcind-lib.bash:1022` nested functions** — promoted to package #04
  because the early-return leak *is* a real issue.
- **Completion-script duplication between bash and zsh** — not
  duplication, genuinely different languages; leave it.

---

## Acceptance for "audit follow-ups complete"

All packages shipped → delete this directory and update the audit commit
message or add a release-notes entry noting that the April 2026 audit
follow-ups are done. `make check` should be clean throughout.
