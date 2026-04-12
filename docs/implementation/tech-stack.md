# Technology Stack

Technologies and tools used to build and distribute Xcind.

## Core

| Technology | Purpose | Version/Notes |
|-----------|---------|---------------|
| Bash | Core language | 3.2+ compatibility target |
| Docker Compose | Underlying tool being wrapped | v2 |
| yq | YAML manipulation for hook-generated compose files | Required dependency: `xcind-config --check` fails if missing. Default-registered hooks that depend on it either soft-skip or hard-fail at runtime when absent — see [Hook Lifecycle](../specs/hook-lifecycle.md#generate). |
| jq | JSON output for `xcind-config` | Used in config dump |

## Development

| Technology | Purpose | Version/Notes |
|-----------|---------|---------------|
| shfmt | Shell formatting | `make format` / `make lint` |
| shellcheck | Shell linting | `make lint` |
| git-cliff | Changelog generation | Release tooling |

## Distribution

| Technology | Purpose | Version/Notes |
|-----------|---------|---------------|
| npm | Package distribution (`@scinddev/xcind`) | Primary distribution channel |
| Nix | Package definition (flake) | Alternative distribution |
| Docker | Testing container + distribution image | Multi-version Bash testing |

## Key Rationale

### Why Bash 3.2+?

macOS ships with Bash 3.2 (due to GPLv3 licensing). Targeting 3.2+ ensures Xcind works on macOS out of the box without requiring users to install a newer Bash via Homebrew or Nix. This is the single most important portability constraint.

### Why yq over other YAML tools?

yq is POSIX-friendly, handles Docker Compose YAML well, and is widely available across package managers. Several default-registered hooks (proxy, app-env, host-gateway, workspace, assigned-ports, app identity) generate compose overlay files by constructing YAML programmatically --- yq provides reliable YAML merging and construction without pulling in heavyweight dependencies. Because the default hook set is broad enough that every real xcind install needs yq, it is promoted to a required dependency rather than an optional one.

### Why shell scripts over a compiled binary?

- **Zero runtime dependencies** --- only Bash, Docker, and standard Unix tools
- **Instant startup** --- no compilation step, no runtime to load
- **Transparent to users** --- developers can read and debug the wrapper scripts directly
- **Simple installation** --- copy files into PATH; no build toolchain needed

## Related Documents

- [ADR-0003: Pure Overlay Design](../decisions/0003-pure-overlay-design.md) --- Why Xcind wraps rather than replaces Docker Compose
- [Project Layout](./project-layout.md) --- Where these technologies are used in the codebase
