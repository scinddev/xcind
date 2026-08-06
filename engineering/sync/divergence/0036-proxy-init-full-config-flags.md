# Divergence 0036: Full proxy configuration through `proxy init` flags

**Status**: Active
**Scind canon**: `docs/reference/cli.md`, `docs/specs/configuration-schemas.md` (minimal `proxy init`; typed `proxy.yaml` plus `config get/set/edit`)
**Xcind reality**: `bin/xcind-proxy`, `engineering/specs/proxy-infrastructure.md` (`xcind-proxy init` exposes the full proxy configuration as flags and merges values on re-init)
**Category**: Structural
**Origin**: P4 XA-0026

## What differs
Scind keeps `proxy init` minimal (`--force`, `--domain`, and `--path`) and changes
other proxy settings through typed `proxy.yaml` or `scind config`. Xcind exposes the
full proxy configuration as `xcind-proxy init` flags and merges flag overrides with
the current sourced-shell configuration on re-init.

## Why Xcind diverges
Xcind has no structured `config set` command. Its sourceable shell configuration
therefore needs a safe scripted writer, and `proxy init` provides that writer.

## Why Scind should NOT simply adopt Xcind's approach
Scind already supports interactive and scripted configuration through a typed YAML
file and `config get/set/edit`. Mirroring every schema key as an init flag would add
a second write surface that must stay synchronized with the proxy schema without
adding a configuration capability.

## Canon-change test (required)
**Strongest canon-change argument:** one-shot provisioning with all values on one
`proxy init` command is more convenient, and Xcind's idempotent merge is easier to
repeat than Scind's error-or-`--force` behavior. **Why rejected (2026-08 escalation
decision brief):** `scind config set` already provides the scripted path, so the
flag surface would duplicate the typed schema. Re-init merge semantics are a
separate recovery-policy question and do not justify duplicating every config key.
Verdict: **SURVIVES-AS-DIVERGENCE.**

## Revisit conditions
Reopen if Scind users need atomic one-shot provisioning that a sequence of
`config set` commands cannot provide.

## Links
- Origin finding: P4 XA-0026
- Related ADR(s): Xcind ADR-0022 (external proxy mode); Scind proxy configuration schema
- Correspondence-map row(s): `specs/configuration-schemas.md` (PARTIAL), `reference/cli.md` (PARTIAL)
- Reconciliation-ledger ID(s): RL-108
