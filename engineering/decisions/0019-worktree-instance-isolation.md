# ADR-0019: Per-Worktree Instance Isolation (`XCIND_INSTANCE`)

**Status**: Accepted

## Context

[ADR-0001](0001-docker-compose-project-name-isolation.md) isolates environments
by deriving a Docker Compose **project name** from the workspace/application
identity (`{workspace}-{application}`). That decision implicitly assumes **one
working copy per project**: the same repository checked out once, in one place.

Building on top of a real Git workflow broke that assumption. When the *same*
repository is checked out into multiple **linked git worktrees** (e.g. to run a
feature branch alongside `main`), every worktree derives the **same** compose
project name and the **same** workspace-internal network name. The result is
collision, not isolation: `up` in one worktree adopts or disrupts the other's
containers and shares its network, defeating the entire point of ADR-0001 for a
workflow the design never modeled.

This is not a Bash artifact — the collision would occur in **any** implementation
of ADR-0001 as written, including a Go implementation of Scind. It is a genuine
gap in the *design assumption*, surfaced by building the Xcind POC. See
["Relationship to Scind canon"](#relationship-to-scind-canon-p6) below.

## Decision

Introduce a single per-worktree isolation token, **`XCIND_INSTANCE`**, and fold
it into exactly two derived names:

1. the Docker Compose **project name** (extends ADR-0001), and
2. the **workspace-internal network name** (`{workspace}-{instance}-internal`).

Nothing else changes shape. The token is a scalpel, not a new isolation layer.

### Resolution order

`__xcind-resolve-instance` (`xcind-lib.bash`) resolves the token once per run:

1. **Explicit wins.** A non-empty `XCIND_INSTANCE` (from the environment or
   `.xcind.override.sh`) is sanitized and used verbatim.
2. **Opt-out.** `XCIND_INSTANCE_AUTO=0` forces an empty instance (no
   auto-detection), for users who deliberately want worktrees to share state.
3. **Auto-detect.** Otherwise, derive the token from a linked git worktree via
   `__xcind-detect-worktree-instance`.

### Worktree detection

A **linked** worktree has `git rev-parse --absolute-git-dir` ≠
`--git-common-dir` (its `.git` is a file pointing into
`.../.git/worktrees/<name>`); the **main** worktree has them equal. When they
differ, the token is the **sanitized basename of the worktree directory** —
stable for the life of the worktree, unlike the branch (which can be switched or
detached). The main worktree resolves to an **empty** instance.

### Empty instance is a no-op by construction

An empty `XCIND_INSTANCE` contributes nothing to any derived name, and is
**excluded from the generation cache SHA** (`xcind-lib.bash`), so the main
checkout's SHA stays **byte-identical to pre-instance builds**. Existing users
see zero change — no migration, no cache bust. Each **linked** worktree with a
distinct token gets its own project name, workspace network, and
cache/generated directories.

## Relationship to Scind canon (P6)

Per the [sync operating model](../sync/00-global-context.md) (§2, and the
Example B calibration case), this is a **canon-change learning**, *not* an Xcind
divergence. Scind's project-name isolation (its ADR-0001 analog) should be
amended to account for multiple concurrent working copies of one project. This
ADR is recorded here so the learning is captured at the source; the
corresponding Scind change is tracked by
[P6 reconciliation](../sync/06-reconciliation-and-sync-procedure.md). It must
**not** be filed as a divergence — doing so would pave over the learning.

## Consequences

### Positive

- The core promise of ADR-0001 — real isolation between environments — now holds
  for the common "multiple worktrees of one repo" workflow.
- Zero-friction for existing users: the main checkout is unchanged bit-for-bit,
  and auto-detection means no configuration is required to benefit.
- One token, two fold points — small, auditable surface.

### Negative

- Auto-detection reads git state (`rev-parse`) on each resolution; cheap, but a
  new dependency on git layout semantics (canonicalized paths, macOS
  `/var`→`/private/var` symlink handling).
- The token is the worktree **directory basename**, so two worktrees with the
  same basename in different parents would still collide. Acceptable; an explicit
  `XCIND_INSTANCE` overrides.

### Neutral

- `XCIND_INSTANCE` participates in the cache SHA only when non-empty, so linked
  worktrees correctly get distinct generated directories while the main checkout
  does not churn.

### Known follow-up

- `xcind-workspace status` (`bin/xcind-workspace`) currently computes the
  workspace network name **without** folding `XCIND_INSTANCE`, so inside a linked
  worktree it inspects the un-instanced name and can report an existing network
  as absent. Tracked as an implementation bug in the
  [P1 self-sync report](../sync/artifacts/p1-self-sync-report.md); fix is to
  reuse `__xcind-workspace-network-name`.

## Related Documents

- [ADR-0001: Docker Compose Project Name Isolation](0001-docker-compose-project-name-isolation.md) — the assumption this extends
- [Naming Conventions](../specs/naming-conventions.md) — instance fold in project/network names
- [Generated Override Files](../specs/generated-override-files.md) — instance in the cache-key inputs
- [Sync: Global Context](../sync/00-global-context.md) — canon-change vs divergence (Example B)
