# CLI reference

Quick reference. For exhaustive flag semantics, JSON contract, and edge cases, see [`engineering/reference/cli.md`](../../engineering/reference/cli.md).

## `xcind-compose`

The main wrapper around `docker compose`. Resolves files, applies hooks, forwards everything else.

```bash
xcind-compose up -d
xcind-compose build --no-cache
xcind-compose exec app bash
xcind-compose ps
xcind-compose logs -f
xcind-compose down --remove-orphans
```

Anything `docker compose` accepts, `xcind-compose` accepts.

## `xcind-application`

Manage app-level metadata.

```bash
xcind-application init [DIR] [--name NAME]    # scaffold .xcind.sh
xcind-application status [DIR] [--json]       # status of one app
xcind-application list [DIR] [--json]         # list apps in the enclosing workspace
```

## `xcind-config`

Inspect what Xcind resolved.

```bash
xcind-config --json                     # machine-readable resolved config (used by JetBrains plugin)
xcind-config --preview                  # show the resolved docker compose command line
xcind-config doctor                     # diagnose discovery / config issues
xcind-config --check                    # check system dependencies (yq, docker, ...)
xcind-config --version                  # version + build provenance
xcind-config completion bash            # bash completions
xcind-config completion zsh             # zsh completions
```

Code generators:

```bash
xcind-config --generate-docker-wrapper                 # POSIX docker wrapper
xcind-config --generate-docker-compose-wrapper         # POSIX docker-compose wrapper
xcind-config --generate-docker-compose-configuration[=FILE]   # resolved compose config
```

## `xcind-proxy`

Manage the shared Traefik proxy infrastructure.

```bash
xcind-proxy init                  # one-time setup
xcind-proxy up                    # start the proxy
xcind-proxy up --force            # recreate proxy container + network
xcind-proxy down                  # stop the proxy
xcind-proxy status [--json]       # is it running?
xcind-proxy logs [-f]             # tail Traefik logs
xcind-proxy --version
```

Walkthrough: [Set up the Traefik proxy](../guides/proxy-setup.md).

## `xcind-workspace`

Manage workspace-level operations. See `xcind-workspace --help` for subcommands; the workspace concept itself is in [Workspaces vs single apps](../guides/workspaces-vs-apps.md).

## Environment overrides

| Variable | Effect |
|----------|--------|
| `XCIND_APP_ROOT` | Skip the upward walk for `.xcind.sh`; treat this as the app root |
| `XCIND_DEBUG=1` | Verbose tracing of file resolution and hook execution |

---

**Full detail**: [`engineering/reference/cli.md`](../../engineering/reference/cli.md) — every flag, every JSON field, exit codes, internal flags reserved for the JetBrains plugin.
