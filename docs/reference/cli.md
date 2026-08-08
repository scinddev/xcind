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
xcind-application dispose [DIR] [--volumes] [--rm] [--yes]
xcind-application status [DIR] [--json]       # status of one app
xcind-application list [DIR] [--json]         # list apps in the enclosing workspace
xcind-application ports [DIR] [--json]        # port bindings for one app
xcind-application urls [DIR] [--json]         # proxy URLs for one app
xcind-application exports [DIR]               # shell exports for assigned ports
```

## `xcind-config`

Inspect what Xcind resolved.

```bash
xcind-config --json                     # machine-readable resolved config (used by JetBrains plugin)
xcind-config resolve metadata.app       # read one resolved xcind value
xcind-config resolve compose.project.name  # read one resolved Compose value
xcind-config resolve --help             # list the resolvable keys and path syntax
xcind-config --preview                  # show the resolved docker compose command line
xcind-config doctor                     # diagnose discovery / config issues
xcind-config --check                    # check system dependencies (yq, docker, ...)
xcind-config --version                  # version + build provenance
xcind-config completion bash            # bash completions
xcind-config completion zsh             # zsh completions
```

`resolve` accepts dotted keys and array indexes such as `configFiles[0]`.
One leading dot is optional. Scalar values are raw, and objects or arrays are
compact JSON. Use `--cached` to prohibit Docker and hook execution. Use
`--hooks-ttl=N` or `XCIND_HOOKS_TTL` to change the five-second refresh
window; a value of `0` disables the window. An explicit `--hooks-ttl=N`
value overrides `XCIND_HOOKS_TTL` from the app configuration.

To read a key that itself contains a dot, put the key in double quotes:

```bash
xcind-config resolve 'compose.services.web.labels."traefik.http.routers.web.rule"'
```

The `compose.project.name`, `compose.volumes.<key>.name`, and
`compose.networks.<key>.name` paths provide stable name lookups. Docker
Compose resolves these names, so they show the container, volume, and network
names that Docker actually uses. Project-scoped volumes read as
`{project}_{key}`, and external volumes keep their own name.
Compose-backed lookups require Docker Compose 2.6 or newer.

Exit status is `0` for a value, `1` when the path has no value, `2` when the
resolved state is unavailable, and `64` for a usage error. Only `compose.*`
paths need the cache. Other paths still resolve when an app sets
`XCIND_HOOKS_GENERATE=()`, unless `--cached` is present. `--cached` requires
current-SHA artifacts for every path and exits `2` when they are unavailable.
The exact `compose` path and the trailing-dot `compose.` path are invalid;
use a path below the `compose.*` namespace.

Code generators:

```bash
xcind-config --generate-docker-wrapper                 # POSIX docker wrapper
xcind-config --generate-docker-compose-wrapper         # POSIX docker-compose wrapper
xcind-config --generate-docker-compose-configuration[=FILE]   # resolved compose config
xcind-config --generate-starship                       # starship prompt module config
```

## `xcind-proxy`

Manage the shared Traefik proxy infrastructure.

```bash
xcind-proxy init                  # one-time setup
xcind-proxy init --mode external  # use an existing host Traefik instead of a managed one
xcind-proxy up                    # start the proxy
xcind-proxy up --force            # recreate proxy container + network
xcind-proxy down                  # stop the proxy
xcind-proxy dispose [--purge] [--yes]  # remove generated state; keep config by default
xcind-proxy status [--json]       # is it running?
xcind-proxy logs [-f]             # tail Traefik logs
xcind-proxy release PORT          # release one assigned port binding
xcind-proxy prune                 # drop assigned-port entries for removed apps
xcind-proxy --version
```

In external mode, `up` only verifies the external proxy; `down`, `logs`, and
`up --force` refuse because Xcind does not own the proxy container. External
mode adds `init` flags for the entrypoints and certresolver of the host
Traefik.

Walkthrough: [Set up the Traefik proxy](../guides/proxy-setup.md).

## `xcind-workspace`

Manage workspace-level operations. `xcind-workspace up` runs `xcind-compose up -d` in every application directory of the workspace; `xcind-workspace down` runs `xcind-compose down` the same way (it confirms first — pass `--yes` to skip). `xcind-workspace restart` is `down` followed by `up` across every application (it confirms first too, since it starts with a down pass — pass `--yes` to skip); volumes are never removed. All three continue past a failing application within each pass and report the failures at the end. Pass `-a NAME` (repeatable) to `up`, `down`, or `restart` to limit the pass loop to specific applications instead of every application in the workspace; an unrecognized name errors out before anything runs. `xcind-workspace down --volumes` also forwards `-v` to each application's `xcind-compose down` call, removing its volumes (the confirmation prompt calls this out); `restart` and `up` reject `--volumes` since restart always preserves volumes. `xcind-workspace dispose DIR --rm --volumes --yes` tears down every application, removes the workspace network and registry entry, then removes the directory. See `xcind-workspace --help` for subcommands; the workspace concept itself is in [Workspaces vs single apps](../guides/workspaces-vs-apps.md).

## Environment overrides

| Variable | Effect |
|----------|--------|
| `XCIND_APP_ROOT` | Skip the upward walk for `.xcind.sh`; treat this as the app root |
| `XCIND_DEBUG=1` | Verbose tracing of file resolution and hook execution |
| `XCIND_ASSIGNED_LISTENERS_OVERRIDE` | Treat this whitespace-separated port list as the in-use set instead of probing the host when allocating `type=assigned` ports (empty = none). Pins allocation deterministically; primarily for tests and reserving ports |

---

**Full detail**: [`engineering/reference/cli.md`](../../engineering/reference/cli.md) — every flag, every JSON field, exit codes, internal flags reserved for the JetBrains plugin.
