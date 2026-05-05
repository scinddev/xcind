# IDE and tool integration

How to wire Xcind into your shell, editor, and dev container.

## Tab completion

Xcind ships completions for `xcind-compose`, `xcind-config`, `xcind-proxy`, `xcind-application`, and `xcind-workspace`.

```bash
# Bash (~/.bashrc)
. <(xcind-config completion bash)

# Zsh (~/.zshrc)
. <(xcind-config completion zsh)
```

`xcind-compose` delegates to Docker's own completion, so you get the full `docker compose` UX.

## JetBrains plugin

The JetBrains plugin reads `xcind-config --json` to discover compose files, env files, and tools per app. Point the plugin's "xcind config" path at your installed `xcind-config` binary (`which xcind-config`).

```bash
xcind-config --json
```

The output is a stable contract — see [`engineering/reference/cli.md`](../../engineering/reference/cli.md) for the JSON schema.

## Declaring tools for IDEs

`XCIND_TOOLS` in `.xcind.sh` declares per-service runtimes that IDE and plugin integrations can pick up:

```bash
XCIND_TOOLS=(
    "node:app"
    "npm:app"
    "composer:app;path=/usr/bin/composer"
    "phpunit:app;use=run;path=vendor/bin/phpunit"
)
```

Format: `name:service[;key=value[;key=value…]]`. `use=exec` (default) attaches to a running container; `use=run` starts a fresh one. `path=` points at the binary inside the container.

## Devcontainers

Xcind works inside a devcontainer the same way it works on the host. See [`engineering/reference/devcontainers.md`](../../engineering/reference/devcontainers.md) for the recommended setup, socket mounting, and known caveats.

## direnv

Xcind does not depend on direnv, but the two compose well. If you want the variables from `.xcind.sh` available in your shell:

```bash
# .envrc
source_env .xcind.sh
```

## Where to go next

- [`xcind-config` reference](../reference/cli.md#xcind-config) — `--json`, `--preview`, `doctor`, completion targets.
