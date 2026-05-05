# Xcind

Xcind is a slim shell wrapper around `docker compose` that resolves compose
files, env files, and override variants per-application from a `.xcind.sh`
config — and adds a shared Traefik proxy, `host.docker.internal` normalization,
and workspace-mode networking on top.

## Install

```bash
# npm (recommended)
npm install -g @scinddev/xcind

# Install script
sudo ./install.sh                    # /usr/local
./install.sh ~/.local                # custom prefix

# Nix
nix profile install github:scinddev/xcind

# Docker
docker pull ghcr.io/scinddev/xcind:latest
```

Full installation guide: [docs/getting-started/installation.md](./docs/getting-started/installation.md).

## Quick Start

In any project with a `compose.yaml`:

```bash
xcind-application init               # writes .xcind.sh
xcind-compose up -d                  # like `docker compose`, but resolves config
```

That's it. `xcind-compose` is a drop-in for `docker compose` and forwards every
argument straight through. From now on it works from any subdirectory of your
project, picks up `.override` siblings of your compose / env files, and runs
the built-in hooks (naming, host-gateway, etc.).

To reach your app at `https://<app>.localhost` instead of `localhost:PORT`,
set up the shared proxy once and declare an export — see
[docs/guides/proxy-setup.md](./docs/guides/proxy-setup.md).

## What you get

- **One config file per app.** `.xcind.sh` is sourceable bash; defaults match `docker compose`'s own discovery.
- **Override files for free.** `compose.override.yaml`, `.env.override`, `.env.local` — all picked up if present.
- **Shared Traefik proxy.** Hostname routing across all your Xcind apps. Stable host-port "assigned" exports for things that need a fixed port.
- **`host.docker.internal` everywhere.** Normalized across Docker Desktop, native Linux, and WSL2.
- **Workspaces.** Group multiple apps under one parent so they share a domain and an internal network.
- **Custom hooks.** Generate your own compose overlays from app context.

## Documentation

- **[User docs](./docs/)** — getting started, how-to guides, reference, explanation.
  - [Add Xcind to an existing project](./docs/guides/add-to-existing-project.md)
  - [Set up the proxy](./docs/guides/proxy-setup.md)
  - [Configuration reference](./docs/reference/configuration.md)
  - [CLI reference](./docs/reference/cli.md)
- **[Engineering docs](./engineering/)** — ADRs, specifications, architecture, behaviors. For contributors and AI agents working on Xcind itself.

## Development

```bash
make test       # run tests
make format     # auto-format shell
make lint       # shfmt + shellcheck
make check      # lint + test (run before opening a PR)
```

See [`AGENTS.md`](./AGENTS.md) for the contributor workflow and
[`engineering/maintenance/releasing.md`](./engineering/maintenance/releasing.md)
for the release process.

## License

MIT — see [LICENSE](./LICENSE).
