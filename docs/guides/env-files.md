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

## Where to go next

- [Override files](./override-files.md) — the analogous mechanism for compose files.
- [Configuration reference](../reference/configuration.md) — full set of file-discovery variables.
