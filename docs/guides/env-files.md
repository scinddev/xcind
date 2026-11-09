# Environment files: compose-level vs app-level

Docker Compose has two distinct uses for env files, and Xcind exposes both. Knowing which is which is the difference between "my variable is undefined inside the container" and "my variable doesn't substitute in the compose file."

## The two roles

| Variable | Role | Available for `${VAR}` in compose? | Available **inside** containers? |
|----------|------|----|----|
| `XCIND_COMPOSE_ENV_FILES` | Compose-level (`--env-file`) | yes | no |
| `XCIND_APP_ENV_FILES` | App-level (`env_file:` per service) | no | yes |

It is **valid and common** to list `.env` in both — that's how you make `.env` work the way most people expect: usable in `${VAR}` substitution AND visible inside containers.

## Defaults

```bash
XCIND_COMPOSE_ENV_FILES=(".env")    # built-in default
XCIND_APP_ENV_FILES=()              # nothing injected unless you opt in
```

## Common patterns

### "I want `.env` to behave like `dotenv` everywhere"

```bash
XCIND_COMPOSE_ENV_FILES=(".env")
XCIND_APP_ENV_FILES=(".env")
```

### "I have a layered config (`.env` + `.env.local`)"

```bash
XCIND_COMPOSE_ENV_FILES=(".env" ".env.local")
XCIND_APP_ENV_FILES=(".env" ".env.local")
```

Later entries override earlier ones, matching Compose's own behavior.

### "I want environment-specific files"

```bash
XCIND_COMPOSE_ENV_FILES=(".env" '.env.${APP_ENV}')
```

Single quotes prevent premature expansion — `${APP_ENV}` is resolved at runtime.

## Override variants

For each env file, Xcind also looks for a `.override` sibling and includes it if present:

| Base | Override |
|------|----------|
| `.env` | `.env.override` |
| `.env.local` | `.env.local.override` |

Useful for local-only secrets — add `.env.override` to `.gitignore`.

## Host-view env file (`XCIND_HOST_ENV_FILE`)

The two roles above are about what containers see. But a Xcind app's dependencies are reachable at **different endpoints depending on who is asking**:

- **Inside a container:** the compose service name (or workspace alias) + the container port — e.g. `db:5432`.
- **On the host** (a `php bin/console`, `phpunit`, or Node script run under mise/direnv): `127.0.0.1` + the Xcind-**assigned host port** — e.g. `127.0.0.1:54320`.

Xcind's service discovery already injects the **container view** into every container as `XCIND_{APP}_{EXPORT}_*` variables. `XCIND_HOST_ENV_FILE` writes the **host view** of that same variable set to a dotenv file in your working tree, so host-run processes get host-flavored values.

Because the **same variable names** carry different values in each context, one committed expression resolves correctly in both:

```dotenv
# committed .env — one expression, both worlds
DATABASE_URL="postgresql://app@${XCIND_MYAPP_DB_HOST}:${XCIND_MYAPP_DB_PORT}/app"
```

- In a container, discovery's injected `environment:` block sets `XCIND_MYAPP_DB_HOST=db`, `…_PORT=5432` → `db:5432`.
- On the host, the host-view file sets `XCIND_MYAPP_DB_HOST=127.0.0.1`, `…_PORT=54320` → `127.0.0.1:54320`.

This works because of two precedence rules that point the same way: Compose `environment:` **beats** `env_file:` inside containers, and dotenv loaders (Symfony Dotenv, Node `dotenv`) **never override** a real OS env var on the host. Each context wins with its own value.

Only **assigned** exports change by view — their `_HOST` becomes `127.0.0.1` and `_PORT` becomes the assigned host port. **Proxied** and **apex** exports keep their routable hostname (e.g. `myapp-web.localhost.scind.io`) in both views: Traefik routes by hostname/SNI, so an IP would break TLS and routing, and the hostname already resolves to `127.0.0.1` on the host.

The host file never contains `_INTERNAL_*` variables (a host process cannot use an in-network address), and it never contains **unpublished** exports (`type=unpublished`), which exist only for containers.

### Explicit internal and external variables

When you need a specific side regardless of where the code runs, use the explicit pairs instead of the base `_HOST`/`_PORT`:

- `XCIND_{APP}_{EXPORT}_INTERNAL_HOST` / `_INTERNAL_PORT` — the address inside Docker (the `{app}-{service}` alias in a workspace, else the compose service name, + the container port). Containers only.
- `XCIND_{APP}_{EXPORT}_EXTERNAL_HOST` / `_EXTERNAL_PORT` — the address outside Docker. The same value in containers and in the host file, so a container can tell a browser or a developer how to reach a service.

### App-defined names (`XCIND_ENV_MAP`)

The dotenv expression above works only in a process that loads the dotenv file with expansion. A database CLI, a Node service, or a shell script in the same container sees the literal text. `XCIND_ENV_MAP` replaces it: Xcind does the expansion and injects plain values, so every process reads your names.

```bash
# .xcind.sh
XCIND_ENV_MAP+=(
    'DATABASE_HOST=${XCIND_SHOP_DATABASE_HOST}'
    'DATABASE_URL=mysql://root@${XCIND_SHOP_DATABASE_HOST}:${XCIND_SHOP_DATABASE_PORT}/shop'
)
```

- **Single quotes are required.** Without them the shell that sources `.xcind.sh` expands the `${...}` first.
- Each entry is expanded once per view. `DATABASE_HOST` is `database` in a container and `127.0.0.1` in the host env file (with `XCIND_HOST_ENV_FILE` set).
- Only `${XCIND_NAME}` references are allowed. Any other `$` is an error, and so is a reference that exists in neither view (a typo, or another app's variable).
- A backslash, a backtick, or a control character (including a newline) in an entry is an error.
- A mapping that uses an unpublished export or an `_INTERNAL_*` variable is left out of the host file.
- A key cannot start with `XCIND_`. A mapped key overrides the same key in your compose `environment:` or `env_file:`, so remove the old dotenv line.

### Use a hostname instead of 127.0.0.1

If your proxy domain resolves to the Docker host — for example a wildcard DNS record that points at the machine running Docker — you can write hostnames for assigned exports instead of `127.0.0.1`:

```bash
XCIND_HOST_ENV_ASSIGNED_HOST="hostname"   # loopback (default) | hostname
```

The assigned `_HOST` in the host file then becomes the export's proxy-domain hostname (e.g. `dev-shop-db.example.test`), and `_PORT` stays the assigned host port. Assigned ports listen on all interfaces, so the same address also works from other machines that resolve the domain. `_EXTERNAL_HOST` inside containers follows the same setting.

### Enabling it

Set the path in `.xcind.sh` (unset means the file is never written — no change for existing projects):

```bash
XCIND_HOST_ENV_FILE=".env.xcind"   # opt-in; relative to the app root
XCIND_HOST_ENV_MODE="own"          # own (default) | block
```

The file is rewritten on `xcind-compose` runs, after host ports are allocated. Writes are idempotent — unchanged content is left untouched, so editors and file watchers don't churn.

**Two write modes** (explicit — never inferred from the filename):

| Mode | Behavior |
|------|----------|
| `own` (default) | Xcind **owns the whole file** and rewrites it atomically. Pair it with a dedicated path like `.env.xcind`. |
| `block` | Xcind rewrites **only** the region between `# >>> xcind >>>` and `# <<< xcind <<<`, preserving every other line (e.g. to fold into an existing `.env.local`). The block is appended once if the markers are absent. |

### Wiring it into your host tooling

Xcind only writes the file — you point your tool at it:

- **direnv** — in `.envrc`: `dotenv_if_exists .env.xcind`
- **mise** — in `mise.toml` under `[env]`: `_.file = ".env.xcind"`
- **Symfony** (no direnv/mise): `(new Dotenv())->load(__DIR__.'/.env.xcind');`
- **Node** (no direnv/mise): `node --env-file=.env.xcind your-script.js`

### Guidance

- **Keep the host file out of `XCIND_APP_ENV_FILES`.** It carries host endpoints; injecting it into containers would feed them `127.0.0.1` for assigned services. (Discovery's `environment:` block still overrides it if you do, but don't rely on that.)
- **`.gitignore` the file** — the assigned host ports are machine-specific.

## Where to go next

- [Override files](./override-files.md) — the analogous mechanism for compose files.
- [Configuration reference](../reference/configuration.md) — full set of file-discovery variables.
