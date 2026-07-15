# Divergence 0010: `--generate-starship --format nix` output

**Status**: Active
**Scind canon**: none — Scind has no prompt segment at all (the *concept* is promoted separately as XA-0010)
**Xcind reality**: `--generate-starship --format nix` emits a Nix-packaged Starship snippet; `bin/xcind-prompt`
**Category**: Structural
**Origin**: P4 XA-0038

## What differs
Xcind's prompt generator can emit its Starship configuration in a **Nix** package
format (`--format nix`), for users who manage their shell via Nix. Scind specifies no
prompt segment and therefore no output formats.

## Why Xcind diverges
Xcind is distributed partly via Nix, so a Nix-native serialization of its Starship
block is a natural convenience for that ecosystem. It rides on Xcind's
`xcind-prompt` capability.

## Why Scind should NOT simply adopt Xcind's approach
The *prompt-segment concept itself* is a real learning and is promoted separately as
**XA-0010** (add a `scind prompt` command + Starship-snippet path to Scind). But a
**package-ecosystem-specific serialization** (Nix) is an Xcind distribution detail.
If Scind adopts a prompt segment, its output formats are its own concern, driven by
how Scind ships — not by Xcind's Nix packaging.

## Canon-change test (required)
**Strongest canon-change argument:** "The prompt segment should be canon." — agreed,
and it *is* (XA-0010, a PROMOTE). What remains here is only the Nix-format detail,
which is packaging-specific (global-context §5). The transferable insight is already
captured upstream, so nothing is lost. Impl-shape, low-risk Structural.

## Revisit conditions
None for the Nix format specifically. The parent capability (prompt segment) is
tracked as XA-0010 → P6.

## Links
- Origin finding: P4 XA-0038 (rides on XA-0010, PROMOTE)
- Related ADR(s): none (consequence of 0001 packaging)
- Correspondence-map row(s): `reference/cli.md` (PARTIAL); `shell-integration.md`
- Reconciliation-ledger ID(s): P6 keys off XA-0038; prompt concept → XA-0010
