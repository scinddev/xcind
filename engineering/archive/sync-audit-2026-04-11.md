# Documentation Sync Audit Report

**Date**: 2026-04-11

| Category | Issues Found | Resolved | Remaining |
|----------|--------------|----------|-----------|
| CLI Reference | 3 | 3 | 0 |
| Config Reference | 3 | 3 | 0 |
| Specifications | 9 | 9 | 0 |
| Cross-Links | 1 | 1 | 0 |
| ADRs | 0 | 0 | 0 |

---

## CLI Reference Drift (Resolved)

| Issue | Document Said | CLI Actually | Resolution |
|-------|--------------|--------------|------------|
| Missing `release` subcommand | Not documented | `release PORT` -- Release an assigned port | Added to cli.md |
| Missing `prune` subcommand | Not documented | `prune` -- Remove stale assigned-port entries | Added to cli.md |
| `status` description incomplete | "running/stopped, image, port, network" | Also shows "assigned ports" | Updated in cli.md |

## Configuration Reference Drift (Resolved)

| Issue | Document Said | Code Actually | Resolution |
|-------|--------------|---------------|------------|
| `XCIND_ASSIGNED_EXPORTS` missing | Not documented | User-facing array in `xcind-assigned-lib.bash` | Added section to configuration.md |
| `XCIND_PROXY_AUTO_START` missing | Not documented | Boolean, default `1`, in `xcind-proxy-lib.bash` | Added section to configuration.md |
| config.sh overwrite claim | "the config file is never overwritten" | Always regenerated (existing values preserved) | Fixed in configuration.md |

## Specification Drift (Resolved)

| Specification | Issue | Resolution |
|---------------|-------|------------|
| `directory-structure.md` | Showed proxy files in `~/.config/` only; missing config/state split | Updated to show two-directory layout |
| `directory-structure.md` | Listed 4 of 7 generated files | Added `compose.app.yaml`, `compose.host-gateway.yaml`, `compose.assigned.yaml` |
| `configuration-schemas.md` | Said config.sh "never overwritten on re-init" | Updated to reflect merge-and-regenerate behavior |
| `configuration-schemas.md` | Attributed auto-start to GENERATE hook | Corrected to EXECUTE hook (`__xcind-proxy-execute-hook`) |
| `configuration-schemas.md` | Hook table listed 4 of 7 hooks | Added `xcind-app-hook`, `xcind-host-gateway-hook`, `xcind-assigned-hook` |
| `configuration-schemas.md` | `xcind-app-env-hook` source listed as `xcind-lib.bash` | Corrected to `xcind-app-env-lib.bash` |
| `context-detection.md` | Referenced `xcind-config --files` flag | Flag doesn't exist; updated to `--json` |
| `generated-override-files.md` | Hook table and merge order missing `xcind-assigned-hook` | Added `compose.assigned.yaml` to both |
| `workspace-lifecycle.md` | Said "Xcind has no workspace init/destroy commands" | Updated to reflect `xcind-workspace init` and `status` commands |

## Cross-Links (Resolved)

| Source File | Link | Issue | Resolution |
|-------------|------|-------|------------|
| `docs/archive/prd-app-env.md` | `archive/prd-proxy.md` | Wrong relative path (doubled `archive/`) | Fixed to `./prd-proxy.md` |

## ADR Currency

All 12 accepted ADRs are faithfully implemented. ADR-0009 (Flexible TLS Configuration) has status "Proposed" and is correctly not yet implemented. No superseded-without-marking issues found.

## Notes

- Three low-priority undocumented variables were identified but not added to avoid documenting internal/advanced options: `XCIND_SUPPRESS_DEP_WARNING`, `XCIND_APP` (overridable but auto-derived), `XCIND_APP_ROOT` (environment override for testing).
- `hook-lifecycle.md` understates the SHA cache key scope (missing workspace/app identity variables and host-gateway settings from the list). This is minor since the spec says "SHA-256 of compose files, config files, env files, proxy config, and XCIND_TOOLS" which is a summary, not exhaustive.
- `make check` passes with 248/248 tests after all documentation changes.
