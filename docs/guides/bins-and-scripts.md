# Bins and Scripts

`xcind-run` executes commands inside your app's Compose services without
hand-written `docker compose exec` invocations. Two declarative maps in
`.xcind.sh` feed it:

- **Bins** (`XCIND_BINS`) — commands that live in a service, such as `npm`
  in the `app` container.
- **Scripts** (`XCIND_SCRIPTS`) — named step lists that chain bins, other
  scripts, compose calls, and host commands.

Both are plain data. They travel with the project, appear in the
`xcind-config --json` contract, and fold into the cache SHA.

## Bins

```bash
XCIND_BINS=(
    "node:app"
    "npm:app"
    "composer:app;cmd=/usr/bin/composer"
    "phpunit:app;use=run;cmd=vendor/bin/phpunit;desc=Run the test suite"
)
```

Format: `name:service[;key=value…]`.

| Key | Meaning |
|---|---|
| `cmd` | Command inside the service. Default: the bin's name. May contain spaces; it is tokenized at run time. |
| `use` | `exec` (default) attaches to the running container; `run` starts a fresh one with `run --rm`. |
| `desc` | Labels the entry in `xcind-run --list`. |

Run a bin with `xcind-run <name> [args…]`. Args always append:

```bash
xcind-run npm install
# → docker compose … exec app npm install
```

Validation is strict: a missing colon, an empty service, an unknown key, a
bad `use`, or a duplicate name fails resolution with a message.

## Scripts

A script is a name followed by steps, one per line:

```bash
XCIND_SCRIPTS=(
    "fresh:
        # Reinstall node modules from scratch
        -rm -rf node_modules
        @npm install"
    "psql:@exec db psql -U app"
)
```

- Steps run in order and stop at the first failure, with its exit status.
- A leading `-` on a step ignores that step's failure.
- The first `#` comment is the script's description for `--list`.
- A single-line form (`name:step`) works for one-step scripts.

### Step kinds

The first word of a step decides what runs:

| Step | Runs |
|---|---|
| `@<bin>` | The declared bin, in its service. |
| `@<script>` | Another script. Cycles are detected and fail with the call path. |
| `@exec <svc> [cmd…]` | `docker compose exec` (no cmd: `bash`). |
| `@run <svc> <cmd…>` | `docker compose run --rm`. |
| `@compose <args…>` | `docker compose`, args verbatim. |
| anything else | On the host, via `bash -c`. This is the only place shell expansion happens. |

`@`-steps are tokenized without expansion: quoting works, but variables,
globs, and command substitution stay literal. Put expansion in a host step
when you need it.

### Arguments

- A **one-step** script with no `$@` appends your args to its step.
- A **multi-step** script passes args only where the bare token `$@`
  (or `"$@"`) appears.
- Args given to a multi-step script with no `$@` fail with exit 64.

```bash
XCIND_SCRIPTS=(
    "test:
        @npm run lint
        @exec app vendor/bin/phpunit \$@"
)
xcind-run test --group fast
# lint gets no args; phpunit gets --group fast
```

## Listing what is runnable

`xcind-run --list` prints every visible bin and script. Each bin carries
the tail of the Compose command it runs, so you can see where it lands
without opening `.xcind.sh`:

```
bins:
  npm                  (… exec app)             Node package manager
  composer             (… exec app /usr/bin/composer)
  phpunit              (… run --rm app vendor/bin/phpunit) Run the test suite

scripts:
  fresh                Reinstall node modules from scratch
      -rm -rf node_modules
      @npm install
```

- `exec` attaches to the running container. `run --rm` starts a fresh one.
- The command appears only when it differs from the bin's name, so a bin
  whose `cmd` is its own name stays short.
- `-T` never appears. The runner decides that at run time from the TTY
  state (see [TTY behavior](#tty-behavior)).
- Scripts list their steps verbatim, including any leading `-`.

`--list --names` prints bare names, one per line, with no service, no
description, and no steps. That is the form to parse in scripts and
completions.

## One namespace

Bins and scripts share one namespace: the same name in both is a load-time
error. A name with a leading `_` is hidden from `--list` and
`--init-shell` but stays runnable — useful for helper scripts that other
scripts call.

## TTY behavior

`xcind-run` passes `-T` to `exec`/`run` when stdin or stdout is not a
terminal, so scripts and CI pipelines work unmodified. Force it with
`-T`/`--no-tty`.

## The step keywords as commands

The step kinds also work directly as the name argument:

```bash
xcind-run @exec app            # shell into the app service
xcind-run @run app npm ci      # one-off container
xcind-run @compose config --services
```

## Shell wrappers

`--init-shell` prints one wrapper function per visible bin and script:

```bash
eval "$(xcind-run --init-shell)"
x-npm install                  # → xcind-run npm install

eval "$(xcind-run --init-shell --prefix acme-)"
acme-fresh
```

### Migrating from personal `x-*` aliases

When your alias file holds functions like this:

```bash
x-npm() { xcind-compose exec app npm "$@"; }
x-fresh() { x-npm ci && x-npm run build; }
```

move the data into the project's `.xcind.sh` so the whole team gets it:

```bash
XCIND_BINS=("npm:app")
XCIND_SCRIPTS=(
    "fresh:
        @npm ci
        @npm run build"
)
```

and replace the alias file's body with one line:

```bash
eval "$(xcind-run --init-shell)"
```
