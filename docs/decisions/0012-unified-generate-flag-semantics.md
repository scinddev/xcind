# ADR-0012: Unified `--generate-*` Flag Semantics

**Status**: Accepted

## Context

The `xcind-config` CLI has three `--generate-*` flags:

- `--generate-docker-wrapper[=FILE]` — stdout or file
- `--generate-docker-compose-wrapper[=FILE]` — stdout or file
- `--generate-ide-configuration=DIR` — required directory, hardcoded output filename (`compose.ide.yaml`)

The IDE configuration flag was the only `--generate-*` flag that required a
directory argument, hardcoded the output filename, and did not support stdout
output. This created a special case in the argument parser, the bash/zsh
completions, the documentation, and the mental model for users.

The flag name also implied IDE-only usage, but the output (a fully-resolved
Docker Compose configuration) is useful in any context: devcontainer setups,
CI pipelines, debugging, and scripting.

## Decision

Replace `--generate-ide-configuration=DIR` with
`--generate-docker-compose-configuration[=FILE]`, matching the argument
semantics of the other two `--generate-*` flags:

- No argument: write to stdout (participates in stdout-claim mechanism)
- `=FILE` or space-separated `FILE`: atomic write to the specified file path

The caller decides the output filename and location. The library function is
renamed from `__xcind-generate-ide-configuration` to
`__xcind-dump-docker-compose-configuration` to match the `__xcind-dump-*`
naming convention used by the other generators.

Stderr from `docker compose config` is no longer suppressed.

## Consequences

### Positive

- All `--generate-*` flags follow the same pattern — one less special case
- Callers (IDE plugins, devcontainer scripts, humans) choose their own filename
- Stdout mode enables piping and scripting without temp files
- Flag name accurately describes the output regardless of consumer

### Negative

- Breaking change for any existing scripts using `--generate-ide-configuration`

### Neutral

- The output content is unchanged (`xcind-compose config` output)

## Related Documents

- [CLI Reference](../reference/cli.md) - Updated flag documentation
- [Dev Containers](../devcontainers.md) - Updated examples
