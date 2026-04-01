# Comparison with Related Tools

This table compares Xcind with existing tools that developers commonly consider for local multi-application development. Each tool has different strengths — understanding these trade-offs helps determine when Xcind is the right choice.

For context on why Xcind was created, see the [Problem Statement](./vision.md#problem-statement) in the Product Vision.

| Feature | Xcind | Scind | Docker `include` | DDEV/Lando | Tilt/Garden |
|---------|-------|-------|-------------------|------------|-------------|
| Multi-app orchestration | via workspaces | native | merged model | single-app | native (K8s) |
| Parallel workspace instances | via naming | native | no | no | no |
| Apps remain agnostic | yes | yes | N/A | N/A | no |
| Docker Compose native | yes | yes | yes | yes | no (K8s) |
| Automatic file resolution | yes | N/A | no | yes | yes |
| Override variants | yes | N/A | no | no | no |
| Hostname-based routing | yes (Traefik) | yes (Traefik) | manual | yes | yes |
| Generated integration | yes (hooks) | yes | no | yes | yes |
| Technology | Bash 3.2+ | Go | Docker CLI | Go | Go |
| Configuration format | `.xcind.sh` (Bash) | YAML | YAML | YAML | Tiltfile (Starlark) |

## Xcind vs Scind

Xcind is a lightweight implementation of the [Scind specification](https://github.com/scinddev/scind). Key differences:

- **Technology**: Xcind is pure Bash; Scind is Go
- **Configuration**: Xcind uses sourceable `.xcind.sh` Bash scripts; Scind uses YAML files (`workspace.yaml`, `application.yaml`)
- **Scope**: Xcind focuses on compose file resolution + proxy + workspaces; Scind provides full workspace lifecycle management
- **Installation**: Xcind has zero compiled dependencies (just Bash + Docker); Scind requires a Go binary
- **Approach**: Xcind wraps `docker compose` transparently; Scind orchestrates above it
