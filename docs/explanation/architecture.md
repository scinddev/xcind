# Architecture (user-level)

A high-level mental model of how Xcind works under the hood. For the engineering view (component diagrams, Bash internals, ADR rationale) see [`engineering/architecture/overview.md`](../../engineering/architecture/overview.md).

## The overlay model

Xcind never edits your `compose.yaml`. It produces additional `-f` and `--env-file` arguments and lets `docker compose` do the rest:

```
your compose files  +  generated overlays  ─►  docker compose -f ... -f ...
```

A typical invocation builds up to:

```
docker compose \
    --env-file .env \
    -f compose.yaml \
    -f compose.override.yaml \
    -f .xcind/generated/<sha>/compose.naming.yaml \
    -f .xcind/generated/<sha>/compose.host-gateway.yaml \
    -f .xcind/generated/<sha>/compose.proxy.yaml \
    up -d
```

`<sha>` is a content hash over your config and compose files. Each unique config produces its own subdirectory, and stale ones are reused or invalidated automatically.

You can see the full resolved command at any time:

```bash
xcind-config --preview
```

## Resolution pipeline

1. **Find the app.** Walk upward from `$PWD` for a `.xcind.sh`. (Or use `$XCIND_APP_ROOT`.)
2. **Detect workspace.** If the parent directory has `XCIND_IS_WORKSPACE=1`, source it first.
3. **Source `.xcind.sh`.** Apply app-level config; load `XCIND_ADDITIONAL_CONFIG_FILES`.
4. **Resolve files.** For each compose / env / config pattern, expand variables, check disk, include `.override` siblings.
5. **Run generation hooks.** Each hook emits an overlay file under `.xcind/generated/<sha>/`. Output is cached by content SHA.
6. **Run execute hooks.** Side-effect hooks (e.g. ensure the proxy network exists). These run every invocation, no cache.
7. **Invoke `docker compose`.** With assembled `--env-file` and `-f` flags, plus your forwarded arguments.

## Two-layer networking (workspace mode)

In workspace mode, every app runs on:

- its own per-app project network (Compose default), AND
- a shared `{workspace}-internal` network created by the workspace hook.

The workspace hook adds aliases on the shared network so cross-app DNS works (`backend-app`, `frontend-web`). This lets the frontend reach the backend without going through the proxy.

## Project isolation

The naming hook gives each app a stable, collision-free Compose project name (`{workspace}-{app}` or just `{app}`). This is what keeps two apps named `app` in two different workspaces from clobbering each other's containers, networks, and volumes.

A second axis of isolation covers the same app in two places at once: the **instance** token (`XCIND_INSTANCE`). A linked git worktree is auto-assigned a token from its directory name, folded into the project name (`{workspace}-{instance}-{app}` / `{app}-{instance}`) and the workspace network (`{workspace}-{instance}-internal`) — never the app name or aliases, so cross-app DNS stays stable. The token is empty on the main checkout, so names are unchanged there; it also joins the config cache key so each instance caches separately. See [Workspaces vs single apps](../guides/workspaces-vs-apps.md#git-worktrees).

## The proxy

A separate, **shared** Traefik runs once per host. Each app declares `XCIND_PROXY_EXPORTS` and the proxy hook generates Traefik labels — Traefik does the routing. The proxy is a normal `docker compose` project that lives at `~/.local/state/xcind/proxy/` and is started via `xcind-proxy up`.

## Where to go next

- [Conventions](./conventions.md) — naming and structure rationale.
- [`engineering/architecture/overview.md`](../../engineering/architecture/overview.md) — component-level architecture.
- [`engineering/decisions/`](../../engineering/decisions/) — why the design is what it is.
