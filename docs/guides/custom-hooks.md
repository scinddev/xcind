# Author custom hooks

Hooks let Xcind generate additional compose files dynamically (or run preconditions) every time you invoke `xcind-compose`. Most users never write custom hooks — the built-ins (proxy, workspace, naming, app-env, host-gateway) cover the common cases. Reach for a custom hook when you need to inject compose configuration that depends on runtime context.

## Built-in hooks (already enabled)

| Hook | Generates | Purpose | Without `yq` |
|------|-----------|---------|--------------|
| `xcind-naming-hook` | `compose.naming.yaml` | Per-app project name to avoid collisions across workspaces | works |
| `xcind-app-hook` | `compose.app.yaml` | Adds `xcind.app.*` labels to every service | soft-skip |
| `xcind-app-env-hook` | env_file overrides | Inject `XCIND_APP_ENV_FILES` into every service | **hard-fail** |
| `xcind-host-gateway-hook` | `compose.host-gateway.yaml` | Map `host.docker.internal` for every service | soft-skip |
| `xcind-proxy-hook` | `compose.proxy.yaml` | Traefik labels from `XCIND_PROXY_EXPORTS` | **hard-fail** |
| `xcind-assigned-hook` | host-port bindings | Stable host ports for `type=assigned` exports | **hard-fail** |
| `xcind-workspace-hook` | `compose.workspace.yaml` | Cross-app aliases on the `{workspace}-internal` network | soft-skip |

The "hard-fail" hooks abort the run with an error if `yq` is missing — their output is load-bearing. "Soft-skip" hooks emit a consolidated warning at the end of the run and let the rest of the pipeline proceed.

Disable any of them by overriding in your `.xcind.sh`:

```bash
XCIND_HOOKS_GENERATE=("xcind-naming-hook" "xcind-proxy-hook")    # drop the others
```

## How a hook works

1. A hook is a bash function that takes the app root as its first argument.
2. It writes a generated compose file to `$XCIND_GENERATED_DIR`.
3. It prints compose flags (e.g. `-f /path/to/file.yaml`) to stdout.
4. Xcind appends those flags to the `docker compose` invocation.
5. Output is cached by SHA over compose-file content + `.xcind.sh` content (+ workspace/global config). The hook re-runs only when inputs change.

## Minimal custom hook

In a file you source from `.xcind.sh` (e.g. via `XCIND_ADDITIONAL_CONFIG_FILES`):

```bash
my-extra-labels-hook() {
    local app_root="$1"
    local out="$XCIND_GENERATED_DIR/compose.extra-labels.yaml"

    cat > "$out" <<'YAML'
services:
  app:
    labels:
      com.example.team: "platform"
YAML

    printf -- '-f %s\n' "$out"
}
```

Then register it in `.xcind.sh`:

```bash
XCIND_HOOKS_GENERATE+=("my-extra-labels-hook")
```

## Execute hooks (no compose output)

`XCIND_HOOKS_EXECUTE` runs functions for their side effects (e.g. ensuring a network exists, prompting for a secret). They run on **every** invocation — they are not cached. Only `xcind-compose` triggers them.

```bash
XCIND_HOOKS_EXECUTE+=("my-precondition-hook")
```

## Notes

- Most generation hooks rely on `yq`. Behavior when `yq` is missing varies by hook (see the table above): load-bearing hooks (proxy, app-env, assigned) abort the run; the others emit a warning and continue.
- Hook output lives at `$XCIND_APP_ROOT/.xcind/generated/<sha>/` (one subdirectory per content hash). Add `.xcind/` to `.gitignore`.
- Custom hooks see all `XCIND_*` variables that the rest of Xcind sees.

## Where to go next

- [`engineering/specs/hook-lifecycle.md`](../../engineering/specs/hook-lifecycle.md) — full lifecycle, ordering, caching semantics.
- [`engineering/architecture/overview.md`](../../engineering/architecture/overview.md) — where hooks fit in the resolution pipeline.
