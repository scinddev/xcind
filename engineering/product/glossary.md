# Glossary

| Term | Definition |
|------|------------|
| **Alias** | A DNS name on the workspace-internal network, following the pattern `{application}-{service}` |
| **Application** | A Docker Compose-based project with a `.xcind.sh` configuration file |
| **App Root** | The directory containing `.xcind.sh`, discovered by walking upward from the current directory |
| **Context Detection** | Automatic discovery of app root (and optional workspace) from the current directory |
| **Export** | A named service declared in `XCIND_PROXY_EXPORTS`, mapped to a compose service and port |
| **Hook** | A Bash function that generates additional compose files after file resolution |
| **Internal Network** | Per-workspace Docker network (`{workspace}-internal`) enabling communication between applications within a workspace. See [ADR-0002](../decisions/0002-two-layer-networking.md). |
| **Overlay** | The architectural approach where workspace integration is achieved entirely through generated Docker Compose override files, without modifying application source files. See [ADR-0003](../decisions/0003-pure-overlay-design.md). |
| **Override File** | A variant of a compose or env file with `.override` inserted before the extension (e.g., `compose.override.yaml`) |
| **Primary Export** | The first entry in `XCIND_PROXY_EXPORTS`, which receives an apex hostname |
| **Project** | Docker Compose project name, formatted as `{workspace}-{application}` in workspace mode, providing namespace isolation for containers. See [ADR-0001](../decisions/0001-docker-compose-project-name-isolation.md). |
| **Proxy Network** | Host-level Docker network (`xcind-proxy`) connecting the Traefik reverse proxy to services requiring external access. See [ADR-0002](../decisions/0002-two-layer-networking.md). |
| **Service** | A container defined in a Docker Compose file. Distinct from "Export" which is an Xcind abstraction for services exposed beyond their application's network. |
| **Variable Expansion** | Shell variable substitution in file patterns (e.g., `compose.${APP_ENV}.yaml`), evaluated at runtime |
| **Workspace** | A parent directory with `.xcind.sh` containing `XCIND_IS_WORKSPACE=1`, grouping multiple applications under shared configuration |
| **xcind-compose** | The main command that resolves configuration and passes everything through to `docker compose` |
