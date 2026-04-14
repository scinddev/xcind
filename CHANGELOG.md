# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed

- **Breaking**: Unified `XCIND_PROXY_EXPORTS` and `XCIND_ASSIGNED_EXPORTS`
  into a single `XCIND_PROXY_EXPORTS` array. Entry type is selected via a
  `;type=proxied|assigned` metadata attribute on each entry (default:
  `proxied`). Old `XCIND_ASSIGNED_EXPORTS` values are silently ignored —
  apps using assigned ports must migrate their entries into
  `XCIND_PROXY_EXPORTS` with `;type=assigned`.
- **Breaking**: Moved the assigned-ports state file from
  `${XDG_CONFIG_HOME:-~/.config}/xcind/assigned-ports.tsv` to
  `${XDG_STATE_HOME:-~/.local/state}/xcind/proxy/assigned-ports.tsv`
  (runtime state belongs under `XDG_STATE_HOME`, and it is now nested
  under `proxy/` alongside the other proxy-component files). No migration
  is performed; stale entries can be re-created on next run.
- **Breaking**: Rewrote the assigned-ports TSV schema to
  `port, workspace, application, service, container_port, app_path,
  assigned_at` (Scind vocabulary). `xcind-proxy status --json` output
  fields `app`/`export` were renamed to `application`/`service`, and a
  `workspace` field was added.
- `xcind-proxy status` assigned-port rows now display
  `workspace/application/service` (falling back to `application/service`
  when no workspace is in play).
- `__xcind-proxy-execute-hook` no longer starts Traefik when
  `XCIND_PROXY_EXPORTS` contains only `type=assigned` entries.

## [0.5.0] - 2026-04-07

### Added

- Add xcind-host-gateway-hook for host.docker.internal normalization (#35) by @simensen in [#35](https://github.com/scinddev/xcind/pull/35)

### Fixed

- Fix host-gateway hook: graceful yq handling, extra_hosts merging, cache invalidation (#36) by @simensen in [#36](https://github.com/scinddev/xcind/pull/36)
- fix: use LAN IP instead of host-gateway for WSL2 mirrored mode (#37) by @simensen in [#37](https://github.com/scinddev/xcind/pull/37)

### Maintenance

- chore: Update .gitignore
## [0.4.0] - 2026-04-03

### Added

- Improve xcind-proxy UX: no-args help, status --json, consistent messages (#33) by @simensen in [#33](https://github.com/scinddev/xcind/pull/33)

### Changed

- Replace --generate-ide-configuration with --generate-docker-compose-configuration (#32) by @simensen in [#32](https://github.com/scinddev/xcind/pull/32)

### Fixed

- docs: update README with missing features and fix outdated content (#31) by @simensen in [#31](https://github.com/scinddev/xcind/pull/31)
- Fix proxy not auto-starting on hook cache hit by @simensen

### Maintenance

- Introduce hook lifecycle system with GENERATE and EXECUTE phases (#34) by @simensen in [#34](https://github.com/scinddev/xcind/pull/34)
## [0.3.0] - 2026-04-02

### Added

- Refactor xcind-config CLI interface (#25) by @simensen in [#25](https://github.com/scinddev/xcind/pull/25)
- docs: Add layered documentation system (LDS) (#24) by @simensen in [#24](https://github.com/scinddev/xcind/pull/24)
- docs: Sync documentation with implementation audit by @simensen
- Fix bugs and inconsistencies from code review (#29) by @simensen in [#29](https://github.com/scinddev/xcind/pull/29)
- Add shell completion support for all xcind commands (#28) by @simensen in [#28](https://github.com/scinddev/xcind/pull/28)

### Changed

- docs: Sync reference docs with xcind-config implementation (#27) by @simensen in [#27](https://github.com/scinddev/xcind/pull/27)

### Maintenance

- Add IDE docker-compose config generation support (#22) by @simensen in [#22](https://github.com/scinddev/xcind/pull/22)
- docs: Add pre-commit-check skill and update AGENTS.md (#23) by @simensen in [#23](https://github.com/scinddev/xcind/pull/23)
- Add XCIND_TOOLS support for tool declarations and JSON output (#26) by @simensen in [#26](https://github.com/scinddev/xcind/pull/26)
- Separate proxy config and state directories per XDG spec (#30) by @simensen in [#30](https://github.com/scinddev/xcind/pull/30)

### Other

- docs: Instructions for integrating with devcontainers by @simensen
## [0.2.0] - 2026-03-30

### Added

- Add xcind-naming-hook for automatic Docker Compose project naming (#20) by @simensen in [#20](https://github.com/scinddev/xcind/pull/20)

### Changed

- Auto-start proxy when xcind-compose runs with XCIND_PROXY_EXPORTS (#19) by @simensen in [#19](https://github.com/scinddev/xcind/pull/19)

### Infrastructure

- Lazy-create proxy network instead of blocking on missing init (#16) by @simensen in [#16](https://github.com/scinddev/xcind/pull/16)

### Maintenance

- Add dependency check command to xcind-config (#17) by @simensen in [#17](https://github.com/scinddev/xcind/pull/17)
- Add Makefile, CLAUDE.md, and convert add-installed-file to skill (#18) by @simensen in [#18](https://github.com/scinddev/xcind/pull/18)
- maint: Include `gh release create ...` release output
## [0.1.2] - 2026-03-27

### Maintenance

- Add manifest consistency checker and update file registrations (#14) by @simensen in [#14](https://github.com/scinddev/xcind/pull/14)
- Fix shellcheck SC2034 warnings in test-xcind.sh (#15) by @simensen in [#15](https://github.com/scinddev/xcind/pull/15)
## [0.1.1] - 2026-03-27

### Added

- feat: rename XCIND_ENV_FILES and add XCIND_APP_ENV_FILES (#11) by @simensen in [#11](https://github.com/scinddev/xcind/pull/11)

### Maintenance

- feat: implement XCIND_ADDITIONAL_CONFIG_FILES (#10) by @simensen in [#10](https://github.com/scinddev/xcind/pull/10)
- Fix unbound variable error in __xcind-source-additional-configs (#12) by @simensen in [#12](https://github.com/scinddev/xcind/pull/12)
## [0.1.0] - 2026-03-26

### Added

- docs: add Upgrading section to README (#7) by @simensen in [#7](https://github.com/scinddev/xcind/pull/7)
- fix: preserve changelog attribution by using --unreleased-only (#9) by @simensen in [#9](https://github.com/scinddev/xcind/pull/9)

### Changed

- docs: update File Structure section in README for accuracy (#6) by @Copilot in [#6](https://github.com/scinddev/xcind/pull/6)

### Infrastructure

- release: added git-cliff and CHANGELOG.md

### Maintenance

- Add xcind-proxy, workspace mode, and hook system (#3) by @simensen in [#3](https://github.com/scinddev/xcind/pull/3)
- chore: update GitHub Actions to Node.js 24-compatible versions (#8) by @Copilot in [#8](https://github.com/scinddev/xcind/pull/8)
## [0.0.3] - 2026-03-12

### Added

- Add docker and docker-compose wrapper generation to xcind-config by @claude
- Add MIT license file and OCI license label to Dockerfile by @claude
- Add license section and LICENSE entry to README by @claude

### Infrastructure

- Better fallback handling to regular Docker
## [0.0.2] - 2026-03-10

### Changed

- Update Nix docs and file system by @simensen

### Fixed

- Fix version updates by @simensen

### Infrastructure

- Removed temporary documentation, updated docs to show Docker usage by @simensen
- Include nix instructions by @simensen

### Other

- Enable OIDC for npmjs publishing by @simensen
- Normalize Project <-> Application by @simensen

### Testing

- Nix installable, test all, and use Docker Compose defaults by @simensen
## [0.0.1] - 2026-03-08

### Added

- Support older versions of Bash by @simensen

### Changed

- Update pinned tag hash by @simensen
- Update pinned tag hash by @simensen
- Update pinned tag hash by @simensen

### Maintenance

- Use a newer version of shellcheck by @simensen
- Cleanup .sh -> .bash by @simensen

### Other

- Initialize project by @simensen
- Make installer run from any directory by @simensen

### Removed

- Remove Docker Hub, renamed according to proper org names by @simensen
