# Xcind User Documentation

Welcome. Xcind is a slim wrapper around `docker compose` that resolves compose files, env files, and overrides per-application from a `.xcind.sh` config — and adds a shared Traefik proxy, host-gateway normalization, and workspace-mode networking on top.

These docs are organized by what you're trying to do.

## Getting started

Step-by-step walkthroughs for first-time users.

- [Installation](./getting-started/installation.md) — install Xcind via npm, install script, Nix, or Docker
- [Your first project](./getting-started/first-project.md) — initialize an app, run it, hit a URL

## How-to guides

Recipes for specific tasks.

- [Add Xcind to an existing Compose project](./guides/add-to-existing-project.md)
- [Set up the Traefik proxy](./guides/proxy-setup.md)
- [Local HTTPS: certificates, trust, and domains](./guides/https-tls.md)
- [Workspaces vs single apps](./guides/workspaces-vs-apps.md)
- [Author custom hooks](./guides/custom-hooks.md)
- [`host.docker.internal` and host-gateway](./guides/host-gateway.md)
- [IDE and tool integration](./guides/tools-ide-integration.md)
- [Starship prompt integration](./guides/starship.md)
- [Environment files: compose-level vs app-level](./guides/env-files.md)
- [Override files](./guides/override-files.md)

## Reference

Quick lookups. For exhaustive detail (every flag, every variable), see the [engineering reference](../engineering/reference/).

- [CLI](./reference/cli.md) — commands, common flags
- [Configuration](./reference/configuration.md) — `.xcind.sh` variables you'll actually set

## Explanation

Conceptual background.

- [Architecture](./explanation/architecture.md) — overlay model, networking, project isolation
- [Conventions](./explanation/conventions.md) — naming, ports, structure
- [Glossary](./explanation/glossary.md)

## Contributing

Building or maintaining Xcind itself? See [`engineering/`](../engineering/) — ADRs, specs, behaviors, and the full Layered Documentation System.
