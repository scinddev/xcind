# Glossary

User-facing glossary. For maintainer-level terminology, see [`engineering/product/glossary.md`](../../engineering/product/glossary.md).

| Term | Meaning |
|------|---------|
| **`.xcind.sh`** | Per-application config script. Sourceable bash. Marks the "app root." |
| **App** | A directory containing a `.xcind.sh` and a compose file set. The unit Xcind operates on. |
| **App root** | The directory containing the closest `.xcind.sh` (walking upward from `$PWD`). |
| **Workspace** | A directory containing apps, marked with `XCIND_IS_WORKSPACE=1` in its own `.xcind.sh`. Apps in a workspace share a domain and an internal network. |
| **Workspaceless** | Single-app mode (no parent workspace). |
| **Instance** | A per-worktree isolation token (`XCIND_INSTANCE`) that disambiguates the compose project name and the workspace network — never the app name or in-network aliases. Empty on the main checkout (names unchanged); auto-derived from a linked git worktree's directory name, overridable, and disableable with `XCIND_INSTANCE_AUTO=0`. |
| **Export** | A service:port pair that gets a hostname or stable host port. Declared in `XCIND_PROXY_EXPORTS`. |
| **Proxied export** | An export whose traffic flows through Traefik by hostname (`{app}-{export}.{domain}`). The default. |
| **Assigned export** | An export pinned to a stable host port via `type=assigned`. Bypasses Traefik. |
| **Hook** | A bash function that emits a generated compose overlay (`XCIND_HOOKS_GENERATE`) or runs a precondition (`XCIND_HOOKS_EXECUTE`). |
| **Generated overlay** | A compose file produced by a hook, written to `.xcind/generated/` and passed to `docker compose -f`. Re-derived on input changes; never hand-edited. |
| **Override file** | A sibling file with `.override` in the name (e.g. `compose.override.yaml`, `.env.override`). Picked up automatically if present. |
| **Compose env file** | Env file passed via `--env-file` for `${VAR}` substitution in compose YAML. Listed in `XCIND_COMPOSE_ENV_FILES`. |
| **App env file** | Env file injected into running containers via `env_file:`. Listed in `XCIND_APP_ENV_FILES`. |
| **Host-view env file** | An opt-in dotenv file (`XCIND_HOST_ENV_FILE`) holding the service-discovery variables with host-flavored values for assigned exports (`127.0.0.1` + the assigned host port), so host-run processes resolve the same endpoints containers do. Proxied/apex hosts stay their routable hostname. |
| **Tool** | A binary inside a service container exposed to IDE integrations via `XCIND_TOOLS`. |
| **Apex template** | A URL template that omits `{export}` (e.g. `myapp.localhost.scind.io`). Used when an app has a single, headlining export. When set, `xcind-application urls`/`exports`/`status` report the apex URL for that export. |
