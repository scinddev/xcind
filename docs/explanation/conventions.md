# Conventions

Why Xcind's defaults are the way they are. Most of these are deliberate choices documented in ADRs — links inline.

## Why a per-app `.xcind.sh`?

A bash script (not YAML/TOML) means:

- File patterns can use shell expansion (`'compose.${APP_ENV}.yaml'`).
- You can compute values, source other files, define helpers.
- Zero parsing dependency.

Trade-off: sourcing arbitrary shell from another developer's repo is dangerous. Xcind only walks upward from your current directory and only sources files you can already see and review. Workflows that auto-discover external apps (`xcind-application list`, `status`) say so up-front in their `--help` output.

## Why is the proxy domain `localhost`?

RFC 6761 reserves `.localhost` for loopback. No DNS, no `/etc/hosts`, no certificates — `https://myapp.localhost` works on every developer's machine out of the box. (You can change it via `XCIND_PROXY_DOMAIN`, but you almost never need to.)

See [ADR-0008: Traefik reverse proxy](../../engineering/decisions/0008-traefik-reverse-proxy.md).

## Why `{app}-{export}.{domain}` and not `{app}.{domain}`?

A typical app exposes more than one thing — web UI, an API, sometimes a worker dashboard. Including `{export}` keeps them distinguishable while staying predictable.

If you have a single export and want the shorter form, set an apex template (see [`engineering/reference/configuration.md`](../../engineering/reference/configuration.md) — the `*_APEX_URL_TEMPLATE` family).

## Why generate compose overlays instead of editing the user's compose file?

- Your file stays under your control. You can read it, diff it, commit it.
- `docker compose` works with or without Xcind. Anyone on the team can fall back to plain `docker compose` and everything still works.
- Overlays are inspectable: every generated file lives at `.xcind/generated/` and `xcind-config --preview` shows the full command line.

See [ADR-0003: Pure overlay design](../../engineering/decisions/0003-pure-overlay-design.md).

## Why is workspace mode opt-in?

Most projects are a single app. Workspace mode is for the (smaller) population running 3+ apps that need to talk to each other. Making it explicit (via `XCIND_IS_WORKSPACE=1` in a parent `.xcind.sh`) means every app's behavior is locally explainable from its own files plus, at most, one parent.

## Why `xcind-compose` instead of just `docker compose`?

`xcind-compose` is `docker compose` plus argument assembly. Anything you can do with `docker compose` you can do with `xcind-compose`. The reverse is not true — Xcind needs to inject `-f` and `--env-file` flags before forwarding.

Tab completion is delegated to Docker's own completion, so you get the same UX.

## Where to go next

- [Architecture](./architecture.md) — the overlay model and resolution pipeline.
- [`engineering/decisions/`](../../engineering/decisions/) — every design decision, immutable.
