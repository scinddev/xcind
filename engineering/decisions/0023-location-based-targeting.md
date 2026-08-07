# ADR-0023: Location-Based Targeting (No `--workspace` / `--app` Flags)

**Status**: Accepted

## Context

Scind's [ADR-0011 (options-based targeting)](https://github.com/scinddev/scind)
lets a user target a workspace or an application **by name from anywhere**:
`--workspace foo` / `--app bar`, resolved against the roster in
`workspace.yaml`, paired with context auto-detection for the common case.

Xcind ships no targeting flags at all. Every `bin/xcind-*` command resolves its
target by **location**:

1. `XCIND_APP_ROOT`, when set, is used directly.
2. Otherwise a positional `[DIR]` argument, when given.
3. Otherwise an upward walk from the current directory to the first `.xcind.sh`
   that does not set `XCIND_IS_WORKSPACE=1`.

The workspace is then the parent directory, when that parent declares itself a
workspace. So the user must be in, or point at, the directory.

This deviation was flagged during the 2026-08 Scind↔Xcind reconciliation
(finding SA-0001) as unrecorded: the divergence was real and deliberate, but no
Xcind ADR stated it. This ADR is that record.

The forces:

- **Xcind has no name→location index for applications.** Scind's targeting flags
  resolve a bare name against `workspace.yaml`, which enumerates each
  application. Xcind has no such roster — applications are discovered by walking
  the filesystem, never read from a registry (see
  [application-lifecycle](../specs/application-lifecycle.md)). A `--app bar`
  flag would have nothing to resolve against.
- **The workspace registry is not a targeting index.** Xcind does keep
  `workspaces.tsv` (see [workspace-lifecycle](../specs/workspace-lifecycle.md)),
  but it exists so `xcind-workspace list` can avoid a filesystem scan. It records
  paths, is written opportunistically during discovery, and is not authoritative:
  an unregistered workspace still works, and a registered one may be gone. Naming
  a target through it would make command behavior depend on shared mutable state
  that Xcind otherwise treats as a cache — against
  [ADR-0005](./0005-structure-vs-state-separation.md).
- **Location targeting matches neighboring tools.** `git` and `docker compose`
  both act on the directory you are in, with a flag to point elsewhere. The
  upward walk plus `[DIR]` is the same shape, and it costs no state.

## Decision

**Xcind targets by location only. It does not accept `--workspace NAME` or
`--app NAME`, and it will not add them while it has no authoritative
application roster.**

The three resolution paths above are the complete targeting surface. Scripts
that need to act on a specific application set `XCIND_APP_ROOT` or pass `[DIR]`.

This is a **subset** of Scind's model, not a contradiction of it: Scind's flags
are additive over the same context auto-detection Xcind implements. Scind should
keep them — its registry makes name targeting a coherent superset capability
that Xcind genuinely lacks.

## Consequences

### Positive

- No persisted name→location state to write, invalidate, or repair; targeting
  behaves identically on a fresh checkout and a long-lived one.
- Command behavior is a pure function of the invocation: same cwd and arguments,
  same target, regardless of what other commands have run before.
- The registry stays a discovery cache, so losing or deleting it degrades
  `xcind-workspace list` and nothing else.

### Negative

- A user cannot act on an application from an unrelated directory without
  naming its path.
- Shell aliases and scripts carry paths where Scind would carry names, so they
  break when a checkout moves.
- Anyone reading both projects' CLI references meets two different targeting
  models for the same conceptual operation.

### Neutral

- The gap closes on its own if Xcind ever gains an authoritative roster: name
  targeting becomes buildable, and this ADR should then be revisited rather than
  worked around.

## Related Documents

- [ADR-0005: Structure vs State Separation](./0005-structure-vs-state-separation.md) — why the registry is a cache, not authority
- [ADR-0021: Cross-Repo ADR Numbering & Cross-Referencing](./0021-cross-repo-adr-cross-referencing.md) — how this ADR relates to Scind's ADR-0011
- [Context Detection](../specs/context-detection.md) — the resolution algorithm
- [Workspace Lifecycle](../specs/workspace-lifecycle.md) — what `workspaces.tsv` is for
- [Divergence 0021: Options-based targeting by name](../sync/divergence/0021-options-based-targeting-by-name.md) — the sync entry this ADR discharges
- [Divergence 0017: Stateless identity registry](../sync/divergence/0017-stateless-identity-registry.md) — the state decision underneath it
