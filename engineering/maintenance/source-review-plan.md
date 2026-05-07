# Source Review Plan

This plan coordinates source-review follow-up work across implementation rounds.
The source review documents are the durable source of truth for findings,
status, resolution notes, and validation commands:

- `engineering/maintenance/source-review-cli-entrypoints.md`
- `engineering/maintenance/source-review-core-runtime.md`
- `engineering/maintenance/source-review-proxy-routing.md`
- `engineering/maintenance/source-review-workspace-app-identity.md`

Use Solo scratchpads for active round coordination and Solo todos for individual
findings. Archive each round scratchpad after its PR is opened and all round
items are complete.

## General Round Workflow

### Step 1: Start the Round

Create a Solo scratchpad for the round with:

- round name and scope
- source review document path
- backlog order
- grouping/parallelization notes
- validation requirement
- coordination rules

Create Solo todos for every finding and documentation-drift item included in the
round. Each todo should name the source-review ID in the title and include:

- what to change
- likely files
- expected tests or docs validation
- instruction to update the source review document before closing the todo

Prompt:

```text
We are starting Source Review Round N for <area>.

Use <source-review-doc> as the source of truth. Create or refresh a Solo
scratchpad for the round with backlog order, grouping, blocking notes, and
validation requirements. Create one Solo todo per included finding or doc drift
item. Each todo must require updating <source-review-doc> with status,
resolution notes, and validation before it is closed.
```

### Step 2: Assign Work

Assign high-risk or shared-file items first. Parallelize only when write scopes
are independent. If multiple agents touch the same source-review document, they
must coordinate before editing it.

Prompt:

```text
Use the active Round N scratchpad to pick the next unblocked todo. Lock the todo,
read the relevant source-review section, implement the fix or doc update, add
focused tests when behavior changes, run the required validation, update the
source-review document with a resolution note, update the scratchpad checkbox,
then close the todo.
```

### Step 3: Mid-Round Coordination

Check progress after each group or when agents become idle. Reconcile overlaps,
especially where one review area found an issue already fixed by another round.

Prompt:

```text
Review the active Round N scratchpad and all open todos for this round. Summarize
which items are complete, which are blocked, which have overlapping fixes from
other rounds, and what should be assigned next. Do not close a todo unless its
source-review document has a resolution note and validation result.
```

### Step 4: Round Validation

For code changes, run:

```bash
make check
```

For docs-only changes, use the repo-appropriate validation; if unsure, run
`make check`.

Prompt:

```text
Round N appears complete. Verify every included source-review item is closed in
the source-review document, every matching Solo todo is closed, and validation
has passed. Run final validation for the accumulated branch. Report any
remaining untracked or unrelated work before commit.
```

### Step 5: Branch, Commit, PR

Use a dedicated branch for each round unless the user asks for a combined
series. Commit only files relevant to the round.

Prompt:

```text
Create a branch for Source Review Round N, commit the completed round changes,
push the branch, open a PR, subscribe to PR review and CI events, and monitor for
failures or review findings. If a Copilot finding is questionable, ask for a
decision before changing code.
```

### Step 6: Close the Round

After PR creation and final coordination, archive the Solo scratchpad.

Prompt:

```text
Archive the Round N scratchpad now that the round is complete and represented by
PR <number>. Leave any out-of-round follow-up as separate Solo todos.
```

## Round 1: CLI Entrypoints

Status: complete. Scratchpad `Source Review CLI Entrypoints Round 1` was
archived after PR #64.

Source review document:

- `engineering/maintenance/source-review-cli-entrypoints.md`

Scope:

- `bin/xcind-compose`
- `bin/xcind-config`
- `bin/xcind-proxy`
- `bin/xcind-workspace`
- `bin/xcind-application`
- related CLI docs, specs, and tests

Backlog:

- `CLI-ENTRY-003`: preserve unrelated workspace config on flagged re-init
- `CLI-ENTRY-001`: missing values for init flags
- `CLI-ENTRY-002`: unexpected trailing arguments
- `CLI-ENTRY-004`: proxy init help filename drift
- `CLI-ENTRY-DOC-001`: proxy init config overwrite semantics
- `CLI-ENTRY-DOC-002`: project layout current entrypoints/libraries
- `CLI-ENTRY-DOC-003`: configuration schema runtime state wording
- `CLI-ENTRY-DOC-004`: context detection `xcind-config` no-arg behavior

Grouping:

- Group 1: `CLI-ENTRY-003`; run alone because it touches workspace init behavior
  and shared tests/docs.
- Group 2: `CLI-ENTRY-001`, `CLI-ENTRY-002`; can run in parallel if agents
  coordinate around CLI parser edits and `test/test-xcind.sh` /
  `test/test-xcind-proxy.sh`.
- Group 3: `CLI-ENTRY-004` and all `CLI-ENTRY-DOC-*` items; mostly parallel,
  but coordinate edits to the source-review document.

Start prompt:

```text
Start Source Review Round 1 for CLI entrypoints. Use
engineering/maintenance/source-review-cli-entrypoints.md as the source of truth.
Create a scratchpad named "Source Review CLI Entrypoints Round 1" with the
backlog order and groups from this plan. Create Solo todos for each CLI-ENTRY
finding and documentation drift item. Each todo must update the source-review
document and run the required validation before closing.
```

Keep-moving prompts:

```text
Pick the next open Round 1 todo from the scratchpad, lock it, implement or
document the fix, update tests if behavior changes, run validation, update
engineering/maintenance/source-review-cli-entrypoints.md with a resolution note,
check off the scratchpad item, and close the todo.
```

```text
Round 1 Group 1 is done. Re-read the scratchpad and source-review document,
confirm `CLI-ENTRY-003` is closed with validation, then start Group 2. Coordinate
before editing shared parser tests.
```

```text
Round 1 implementation items are done. Start Group 3 doc/help items. Keep docs
changes scoped to the listed drift IDs and update the source-review document for
each one.
```

Completion prompt:

```text
Round 1 appears complete. Confirm all `CLI-ENTRY-*` and `CLI-ENTRY-DOC-*` items
are closed in Solo and in the source-review document, run `make check`, create a
branch, commit the Round 1 changes, open a PR, and archive the scratchpad.
```

## Round 2: Core Runtime

Status: complete. Scratchpad `Source Review Core Runtime Round 2` was
archived after PR #TBD.

Source review document:

- `engineering/maintenance/source-review-core-runtime.md`

Scope:

- `lib/xcind/xcind-lib.bash`
- `lib/xcind/xcind-bootstrap.bash`
- generated cache behavior
- hook replay behavior
- assigned-port interaction with generation cache
- core runtime docs and specs

Backlog:

- `CORE-RUNTIME-001`: partial generated directories are trusted as cache hits
- `CORE-RUNTIME-002`: assigned-port generation is cached despite live state
- `CORE-RUNTIME-003`: cache `config.json` is written before post-hook assigned
  port state exists
- `CORE-RUNTIME-004`: bootstrap source comment still says there are four callers
- `CORE-RUNTIME-DOC-001`: state/config wording in configuration schemas
- `CORE-RUNTIME-DOC-002`: generated cache-key documentation gaps
- `CORE-RUNTIME-DOC-003`: source-order documentation gaps
- `CORE-RUNTIME-DOC-004`: project layout omits bootstrap/new libraries
- Todo `289`: transient assigned-ports temp-file `mv` diagnostics during
  `make check`

Grouping:

- Group 1: `CORE-RUNTIME-001`; run alone because it changes cache validity and
  hook replay semantics.
- Group 2: `CORE-RUNTIME-002`, `CORE-RUNTIME-003`, todo `289`; coordinate
  closely because all involve assigned-port state and generated/cache freshness.
- Group 3: `CORE-RUNTIME-004` and `CORE-RUNTIME-DOC-*`; docs/comment follow-up
  after runtime behavior is settled.

Start prompt:

```text
Start Source Review Round 2 for Core Runtime. Use
engineering/maintenance/source-review-core-runtime.md as the source of truth.
Create a scratchpad named "Source Review Core Runtime Round 2" with backlog
order, groups, blockers, and validation. Create Solo todos for each included
CORE-RUNTIME finding and documentation drift item unless one already exists.
Include todo 289 in Group 2 and coordinate with any active worker on it.
```

Keep-moving prompts:

```text
Pick the next unblocked Round 2 Group 1 todo. Focus on generated directory cache
validity and hook replay completeness. Add deterministic regression coverage,
run `make check`, update the source-review document with the final behavior and
validation, then close the todo.
```

```text
Round 2 Group 1 is complete. Start Group 2. Before editing assigned-port code,
check todo 289 and any active worker output. Keep changes coordinated across
`lib/xcind/xcind-assigned-lib.bash`, `lib/xcind/xcind-lib.bash`, and tests.
```

```text
Round 2 runtime fixes are complete. Reconcile the docs drift list against the
actual implemented behavior, then update only the affected docs and source-review
resolution notes.
```

Completion prompt:

```text
Round 2 appears complete. Verify every included CORE-RUNTIME item and todo 289
has a resolution or explicit carry-forward decision, run `make check`, create a
Round 2 branch, commit scoped changes, open a PR, subscribe to PR events, and
archive the scratchpad.
```

## Round 3: Proxy and Routing

Status: complete. Source review ledger marks all findings and documentation
drift closed, with `make check` passing after implementation follow-up.

Source review document:

- `engineering/maintenance/source-review-proxy-routing.md`

Scope:

- `lib/xcind/xcind-proxy-lib.bash`
- `bin/xcind-proxy`
- proxy generated overlays
- proxy config serialization
- proxy CLI lifecycle behavior
- proxy specs, behavior files, and appendices

Backlog:

- `PROXY-ROUTING-001`: explicit `xcind-proxy up` can exit successfully when
  Traefik fails to start
- `PROXY-ROUTING-002`: proxy init writes unescaped CLI values into sourceable
  Bash config
- `PROXY-ROUTING-003`: proxy init accepts invalid port and boolean values
- `PROXY-ROUTING-004`: proxy export ports are not validated before Traefik
  labels are emitted
- `PROXY-ROUTING-DOC-001` through `PROXY-ROUTING-DOC-008`

Grouping:

- Group 1: `PROXY-ROUTING-002`; run early because config serialization affects
  all proxy init persistence.
- Group 2: `PROXY-ROUTING-001`; strict CLI startup behavior, separate from
  non-fatal execute-hook behavior.
- Group 3: `PROXY-ROUTING-003`, `PROXY-ROUTING-004`; validation and error
  handling for user inputs and exports.
- Group 4: `PROXY-ROUTING-DOC-*`; update specs, behavior files, appendices, and
  architecture after implementation behavior is settled.

Start prompt:

```text
Start Source Review Round 3 for Proxy and Routing. Use
engineering/maintenance/source-review-proxy-routing.md as the source of truth.
Create a scratchpad named "Source Review Proxy and Routing Round 3" with the
backlog and groups from the plan. Create Solo todos for each included finding and
documentation drift item. Require `make check` for code changes.
```

Keep-moving prompts:

```text
Pick the next Round 3 todo. Lock it, read the matching section in
source-review-proxy-routing.md, implement the focused fix, add proxy tests for
the specific failure mode, run validation, update the source-review document,
then close the todo.
```

```text
Before starting Round 3 docs drift, summarize which proxy behavior changed in
Groups 1-3. Use that summary to update specs, behavior files, appendices, and
architecture without preserving stale pre-TLS or pre-hook-split wording.
```

Completion prompt:

```text
Round 3 appears complete. Confirm all `PROXY-ROUTING-*` and
`PROXY-ROUTING-DOC-*` items are closed or explicitly deferred, run `make check`,
commit the scoped branch, open a PR, subscribe to events, and archive the
scratchpad.
```

## Round 4: Workspace and App Identity

Status: complete. Scratchpad `Source Review Workspace App Identity Round 4` was archived. All findings (WAI-001 through WAI-004, WAI-DOC-001 through WAI-DOC-006) are closed. PR #66 merged 2026-05-07.

Source review document:

- `engineering/maintenance/source-review-workspace-app-identity.md`

Scope:

- `lib/xcind/xcind-workspace-lib.bash`
- `lib/xcind/xcind-app-lib.bash`
- `bin/xcind-workspace`
- `bin/xcind-application`
- workspace/app identity overlays
- workspace registry and status/list behavior
- workspace/app lifecycle docs

Backlog:

- `WAI-001`: workspace/application init flags without values
- `WAI-002`: repeated or extra positional arguments
- `WAI-003`: workspace init drops unrelated config on flagged re-init
- `WAI-004`: workspace network creation failures are fully suppressed
- `WAI-DOC-001` through `WAI-DOC-006`

Round 1 overlap:

- `WAI-001`, `WAI-002`, and `WAI-003` overlap with Round 1 CLI entrypoint fixes.
  Start this round by verifying whether those findings are already resolved by
  PR #64. If yes, update `source-review-workspace-app-identity.md` with
  resolution notes instead of re-implementing them.

Grouping:

- Group 1: overlap reconciliation for `WAI-001`, `WAI-002`, `WAI-003`.
- Group 2: `WAI-004`; workspace network failure diagnostics/behavior.
- Group 3: `WAI-DOC-*`; update documentation after behavior is settled.

Start prompt:

```text
Start Source Review Round 4 for Workspace and App Identity. Use
engineering/maintenance/source-review-workspace-app-identity.md as the source of
truth. Create a scratchpad named "Source Review Workspace App Identity Round 4".
First reconcile `WAI-001`, `WAI-002`, and `WAI-003` against the Round 1 PR before
creating implementation todos for them. Create todos for unresolved WAI findings
and doc drift items.
```

Keep-moving prompts:

```text
Begin Round 4 Group 1. Compare each overlapping WAI finding with the current
implementation and Round 1 resolution notes. If already fixed, update
source-review-workspace-app-identity.md with the resolution and validation. If
not fixed, create or update the todo with the remaining work.
```

```text
Start Round 4 Group 2 for `WAI-004`. Preserve the documented non-fatal behavior
only if it is still intentional; otherwise add visible diagnostics or stricter
failure behavior with tests. Run `make check` and update the source-review
document before closing.
```

```text
Round 4 implementation findings are resolved. Update WAI documentation drift
items to match current state/config, project layout, hook ownership, and
`xcind-config` behavior. Avoid duplicating docs already corrected in earlier
rounds; link or mark resolved where appropriate.
```

Completion prompt:

```text
Round 4 appears complete. Confirm the WAI source-review document is reconciled
with Round 1 and current behavior, run final validation, commit a scoped branch,
open a PR, subscribe to events, and archive the scratchpad.
```

## Round 5: Cross-Document Drift Sweep

Status: complete. Cross-document consistency verified 2026-05-07. Added link to source-review-plan.md in engineering/maintenance/README.md. All checked areas (terminology, hook ownership, cache-key docs, project layout, xcind-config examples, proxy appendices, cross-doc links) are accurate.

Purpose:

Earlier rounds touch overlapping docs: configuration schemas, project layout,
architecture, hook lifecycle, generated override files, context detection, and
proxy appendices. Round 5 is a final consistency pass after implementation
behavior has settled.

Scope:

- any remaining open `*-DOC-*` items from prior source-review documents
- cross-document terminology and links
- duplicated or conflicting state/config wording
- behavior files that no longer match implemented ownership
- source review documents themselves, if statuses drifted

Backlog:

- Carry forward any unresolved documentation drift from Rounds 2-4.
- Verify Round 1 documentation changes still hold after later rounds.
- Verify source-review docs have accurate open/closed statuses.
- Verify `engineering/maintenance/README.md` links this plan if desired.

Grouping:

- Group 1: inventory unresolved doc drift across all source-review documents.
- Group 2: apply cross-document consistency updates.
- Group 3: final validation and status reconciliation.

Start prompt:

```text
Start Source Review Round 5 for the cross-document drift sweep. Inventory all
remaining open `*-DOC-*` items across the source-review documents. Create a
scratchpad named "Source Review Documentation Drift Round 5" and group the work
by document, not by original review area, to avoid conflicting edits.
```

Keep-moving prompts:

```text
Pick the next Round 5 document group. Update the document so it matches current
implementation and the resolved source-review findings. Then update every source
review document whose drift item was closed by that edit.
```

```text
Round 5 docs edits are mostly complete. Run a consistency pass across
configuration/state terminology, hook ownership, generated cache behavior,
project layout, and proxy TLS examples. Record any intentionally deferred drift
as new Solo todos.
```

Completion prompt:

```text
Round 5 appears complete. Verify all documentation drift items are closed or
intentionally deferred, run final validation, commit a scoped docs branch, open a
PR, subscribe to events, and archive the scratchpad.
```

## Operating Rules

- The source-review document for an area is the authoritative status ledger.
- Solo todos are execution units; they are not complete until the source-review
  document is updated.
- Scratchpads coordinate active rounds only; archive them after the round PR is
  opened.
- Do not close overlapping findings by assumption. Verify current code and cite
  the resolving PR or validation command in the source-review document.
- Use `make check` for every code change before commit.
- Use focused branches and commit only files relevant to the round.
- Preserve unrelated user or worker changes in the worktree.
