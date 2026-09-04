# IDE and tool integration

How to wire Xcind into your shell, editor, and dev container.

## Tab completion

Xcind ships completions for `xcind-compose`, `xcind-config`, `xcind-proxy`, `xcind-run`, `xcind-application`, and `xcind-workspace`.

```bash
# Bash (~/.bashrc)
. <(xcind-config completion bash)

# Zsh (~/.zshrc)
. <(xcind-config completion zsh)
```

`xcind-compose` delegates to Docker's own completion, so you get the full `docker compose` UX.

### Short names

A hand-written `x-config() { xcind-config "$@"; }` loses completion: nothing is
registered for `x-config`, so it falls back to filenames.
`xcind-shell-aliases` defines the same wrappers and registers each one's
completion:

```bash
. <(xcind-config completion bash)
xcind-shell-aliases            # x-compose x-config x-proxy x-run x-workspace x-app x-application
xcind-shell-aliases acme-      # acme-compose, acme-config, …
```

`x-compose <TAB>` then completes services and compose flags exactly as
`xcind-compose <TAB>` does.

The command set comes from the completion script, not from an app's
`.xcind.sh`, so one call per shell covers every directory. Reach an app's
bins and scripts through `xcind-run <TAB>`, which re-reads the current app on
every request — see [Bins and scripts](./bins-and-scripts.md).

## Starship prompt

Xcind can show your current workspace/app (and optionally the apex hostname) right in your [Starship](https://starship.rs) prompt. See [Starship prompt](./starship.md) for the `[custom.xcind]` snippet and setup.

## JetBrains plugin

The JetBrains plugin reads `xcind-config --json` to discover compose files, env files, and tools per app. Point the plugin's "xcind config" path at your installed `xcind-config` binary (`which xcind-config`).

```bash
xcind-config --json
```

The output is a stable contract — see [`engineering/reference/cli.md`](../../engineering/reference/cli.md) for the JSON schema.

## Declaring bins for IDEs

`XCIND_BINS` in `.xcind.sh` declares per-service runtimes. IDE and plugin integrations can pick them up, and `xcind-run` executes them:

```bash
XCIND_BINS=(
    "node:app"
    "npm:app"
    "composer:app;cmd=/usr/bin/composer"
    "phpunit:app;use=run;cmd=vendor/bin/phpunit;desc=Run the test suite"
)
```

Format: `name:service[;key=value[;key=value…]]`. `use=exec` (default) attaches to a running container; `use=run` starts a fresh one. `cmd=` is the command inside the container (default: the bin's name). `desc=` labels the entry in `xcind-run --list`. See [`bins-and-scripts.md`](./bins-and-scripts.md) for running bins and composing them into scripts.

## Devcontainers

Xcind works inside a devcontainer the same way it works on the host. See [`engineering/reference/devcontainers.md`](../../engineering/reference/devcontainers.md) for the recommended setup, socket mounting, and known caveats.

## direnv

Xcind does not depend on direnv, but the two compose well. If you want the variables from `.xcind.sh` available in your shell:

```bash
# .envrc
source_env .xcind.sh
```

## Where to go next

- [Starship prompt](./starship.md) — show your workspace/app context in your prompt.
- [`xcind-config` reference](../reference/cli.md#xcind-config) — `--json`, `--preview`, `doctor`, completion targets.
