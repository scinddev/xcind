# ADR-0025: App-Defined Names for Discovery Variables (`XCIND_ENV_MAP`)

**Status**: Accepted

## Context

[ADR-0018](0018-service-discovery-env-injection.md) injects
`XCIND_{APP}_{EXPORT}_*` discovery variables into containers, and
[ADR-0020](0020-host-env-symmetry.md) writes the host-view set to an opt-in env
file. [ADR-0024](0024-internal-external-discovery-and-unpublished-exports.md)
added internal and external pairs. Applications still want their own names:
`DATABASE_HOST`, `DATABASE_URL`, `MAILER_HOST`.

Today an app maps names in a dotenv file that its framework expands at runtime:

```dotenv
DATABASE_HOST=${XCIND_SHOP_DATABASE_HOST}
```

That works only in a process that loads the dotenv file with expansion. Other
tools in the same container (a database CLI, a Node service, a shell script)
see the literal text or nothing. Compose cannot do the mapping either: it
interpolates `environment:` and `env_file:` values from the shell that runs
`docker compose`, not from the container environment that Xcind injects.

## Decision

### `XCIND_ENV_MAP`

An app declares its names as templates over discovery variables:

```bash
XCIND_ENV_MAP+=(
  'DATABASE_HOST=${XCIND_SHOP_DATABASE_HOST}'
  'DATABASE_URL=mysql://root@${XCIND_SHOP_DATABASE_HOST}:${XCIND_SHOP_DATABASE_PORT}/shop'
  'MAILER_DSN=smtp://${XCIND_SHOP_SMTP_HOST}:${XCIND_SHOP_SMTP_PORT}'
)
```

Use single quotes, so the shell that sources the config file does not expand the
references.

Xcind expands each template from the pair set of each view and renders the
result:

- **Container view:** appended to the `environment:` block of every service in
  `compose.discovery.yaml`, after the `XCIND_*` variables.
- **Host view:** appended to the `XCIND_HOST_ENV_FILE` body, after the `XCIND_*`
  variables.

The same template gives each view its own value. With the configuration above,
`DATABASE_HOST` is `shop-database` inside a container and `127.0.0.1` (or the
assigned hostname) in the host env file.

### Template syntax

- A template is literal text plus references of the form `${XCIND_NAME}`, where
  `NAME` matches `[A-Z0-9_]+`.
- A reference resolves against the pair set of the view being rendered: the
  same `XCIND_*` variables that Xcind emits for that view (own app only, plus
  `XCIND_WORKSPACE_NAME` in a workspace).
- Any other `$` is an error: `$NAME`, `${OTHER}`, `${XCIND_X:-default}`, `$(...)`,
  and a lone `$`. Xcind does no shell evaluation, and expansion is not
  recursive: a template cannot reference another mapped key.
- A backslash, a backtick, or any control character (including a newline) in an
  entry is an error. A newline would split one entry into several env entries,
  and a backslash or backtick is read differently by different dotenv loaders
  and by a shell that sources the file.
- Because no rendered value contains `$`, Compose interpolation and dotenv
  expansion cannot change a mapped value.
- A template with no reference is allowed and renders as a constant in both
  views.

### Keys

- A key must match `[A-Za-z_][A-Za-z0-9_]*`.
- A key that starts with `XCIND_` is an error, so a mapping never shadows a
  discovery variable.
- Byte-identical repeated entries (the same entry from two config files) are
  emitted once. The same key with two different templates is an error.

### Missing references

- When a reference is missing from one view, Xcind drops that entry from that
  view only. Example: a template that uses an `unpublished` export or an
  `_INTERNAL_*` variable is absent from the host env file.
- When a reference is missing from both views, generation fails with an error
  that names the entry and the reference. Example: a typo, or another app's
  variable (discovery is own-app only).

Both callers (the discovery GENERATE hook and the host env EXECUTE hook) use
one shared builder that computes both views, so they apply the same rules.

### Precedence

The discovery overlay is merged after the app's compose files, so a mapped key
overrides the same key in the app's own `environment:` or `env_file:`. This is
the intent: the mapping is an explicit Xcind setting. Xcind does not warn about
the overlap. In the host env file's `block` mode, keep mapped keys out of the
rest of the file.

### Cache

The discovery hook is already registered in `XCIND_HOOKS_ALWAYS`, and the host
env hook is an EXECUTE hook that runs on every invocation. So mapped values
that use `_HOST_PORT` or `_EXTERNAL_PORT` follow live assigned-port state with
no extra work.

### No shorthand

There is no own-app shorthand such as `${DATABASE_HOST}` for
`${XCIND_SHOP_DATABASE_HOST}`. A full name is unambiguous, can be found with
grep, and cannot collide with a mapped key.

### Introspection

`xcind-config --json` reports the declared templates, unexpanded, in a new
top-level `envMap` object (`{KEY: template}`). It shows what is declared and
does not validate: for a key declared twice with different templates it shows
the last one, and generation reports the conflict.

### Validation timing

The discovery hook validates the map syntax (keys, templates, repeats) on
every run, before it checks for `yq`, so a syntax error fails generation even
where the discovery overlay is skipped. Reference resolution needs the pair
sets and runs whenever either hook renders.

## Relationship to Scind canon (P6)

**PROMOTE candidate**, recorded as
[`XA-0046`](../sync/artifacts/xcind-ahead.md). Scind has no way for an
application to name discovery values. The proposed shape is an `env_map:` block
in `application.yaml` with `${SCIND_*}` references and the same rules:

```yaml
env_map:
  DATABASE_HOST: ${SCIND_SHOP_DATABASE_HOST}
  DATABASE_URL: mysql://root@${SCIND_SHOP_DATABASE_HOST}:${SCIND_SHOP_DATABASE_PORT}/shop
```

The name `env_map` avoids confusion with the generated `environment:` block in
Scind state. Not a divergence: nothing here narrows Scind's behavior.

## Consequences

### Positive

- Every process in a container reads the app's own names, with no dotenv
  expansion.
- One declaration serves the container and the host env file, each with the
  right value.
- Typos and references to other apps fail generation instead of rendering an
  empty value.

### Negative

- The mapped keys are added to every service of the app, as the discovery
  variables are.
- A mapped key silently overrides the same key in the app's compose
  `environment:`.

### Neutral

- Literal `$` cannot appear in a mapped value. An escape (`$$`) can be added
  later without breaking existing templates.

## Related Documents

- [ADR-0018: Service-Discovery Environment Variable Injection](0018-service-discovery-env-injection.md)
- [ADR-0020: Host/Container Environment Symmetry](0020-host-env-symmetry.md)
- [ADR-0024: Internal/External Discovery Variables and Unpublished Exports](0024-internal-external-discovery-and-unpublished-exports.md)
- [Environment Variables](../specs/environment-variables.md)
