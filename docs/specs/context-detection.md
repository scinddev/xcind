# Context Detection

> Rewritten from the [Scind specification](https://github.com/scinddev/scind). Xcind walks upward for `.xcind.sh` instead of using `workspace.yaml`/`application.yaml`, and checks the parent directory for workspace status.

---

## Detection Algorithm

When `xcind-compose` or `xcind-config` runs, it detects the application context using a simple upward walk:

### Step 1: Find App Root

Walk upward from the current working directory (`$PWD`) looking for a `.xcind.sh` file. The first one found establishes the **app root**.

If `XCIND_APP_ROOT` is set, skip the walk and use that path directly.

### Step 2: Discover Workspace

Check the **parent directory** of the app root for a `.xcind.sh` file. If found and it sets `XCIND_IS_WORKSPACE=1`, xcind enters workspace mode:

1. Sets `XCIND_WORKSPACE` to the basename of the parent directory
2. Sets `XCIND_WORKSPACE_ROOT` to the absolute path of the parent directory
3. Sets `XCIND_WORKSPACELESS=0`
4. Sources the workspace `.xcind.sh` first

### Step 3: Load App Config

Sources the application's `.xcind.sh`, which can override any workspace-level settings.

### Step 4: Late-Bind Self-Declaration

If the app's `.xcind.sh` sets `XCIND_WORKSPACE` directly (without a parent workspace `.xcind.sh`), xcind enters workspace mode using the declared workspace name.

---

## Error Cases

### No Configuration Found

If no `.xcind.sh` is found in the current directory or any parent:

```
Error: Could not find .xcind.sh in any parent directory
```

Exit code: 1

### `XCIND_APP_ROOT` Override

If `XCIND_APP_ROOT` is set but the directory does not contain `.xcind.sh`:

```
Error: No .xcind.sh found at XCIND_APP_ROOT=/path/to/dir
```

Exit code: 1

---

## Edge Cases

- **Nested directories**: The upward walk stops at the first `.xcind.sh` found. If you're in `frontend/src/components/`, it finds `frontend/.xcind.sh`.
- **Workspace self-declaration**: An app can declare itself part of a workspace by setting `XCIND_WORKSPACE` in its own `.xcind.sh`, without needing a parent workspace directory.
- **Single-app workspaces**: A directory can be both the workspace and the app — its `.xcind.sh` sets `XCIND_IS_WORKSPACE=1` and also defines `XCIND_COMPOSE_FILES`, etc. In this case, the parent-check finds no workspace, but the app can self-declare.

---

## Application Name Resolution

The application name (`XCIND_APP`) is inferred from the basename of the app root directory. For example, if the app root is `/Users/beau/dev/frontend`, the app name is `frontend`.

---

## Quick Reference

```bash
# Run from anywhere inside an application
cd /path/to/app/src/deep/directory
xcind-compose up -d          # Finds .xcind.sh in /path/to/app/

# Override detection
XCIND_APP_ROOT=/path/to/app xcind-compose up -d

# Debug what was detected
xcind-config                 # JSON output with appRoot
xcind-config --preview       # Show the full docker compose command
xcind-config --files         # Show resolved files
```

---

## Related Documents

- [Directory Structure](./directory-structure.md) — File locations for `.xcind.sh`
- [Configuration Schemas](./configuration-schemas.md) — Configuration levels and source order
- [CLI Reference](../reference/cli.md) — Command usage
