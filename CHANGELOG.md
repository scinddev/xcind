# Changelog

All notable changes to this project will be documented in this file.

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
