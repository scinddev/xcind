# Directory Structure

> Rewritten from the [Scind specification](https://github.com/scinddev/scind). Xcind's layout is flat (`.xcind.sh` + compose files) with no `.scind/` directory structure.

---

## Global Configuration

```
~/.config/xcind/
└── proxy/
    └── config.sh                     # User-editable proxy configuration

~/.local/state/xcind/
└── proxy/
    ├── compose.yaml                  # Generated Traefik service definition
    ├── traefik.yaml                  # Generated Traefik static configuration
    ├── assigned-ports.tsv            # Host-port assignment ledger (type=assigned entries)
    └── assigned-ports.lock           # flock(1) serialization file
```

Created by `xcind-proxy init`. Config values are preserved on re-init; `compose.yaml` and `traefik.yaml` are regenerated on each init. `assigned-ports.tsv` is written lazily by `xcind-assigned-hook` whenever an application declares a `type=assigned` entry in `XCIND_PROXY_EXPORTS`.

---

## Workspaceless Application

A standalone application with no workspace:

```
myapp/
├── .xcind.sh                         # Application configuration
├── compose.yaml                      # Docker Compose file
├── .env                              # Environment file (optional)
├── .xcind/                           # Generated files (gitignored)
│   ├── cache/{sha}/                  # Cached resolved config
│   │   └── resolved-config.yaml
│   └── generated/{sha}/             # Hook-generated compose files
│       ├── compose.naming.yaml
│       ├── compose.app.yaml
│       ├── compose.app-env.yaml
│       ├── compose.host-gateway.yaml
│       ├── compose.proxy.yaml
│       ├── compose.assigned.yaml
│       └── compose.workspace.yaml
└── src/                              # Application source code
```

## Multi-Application Workspace

```
dev/                                  # Workspace root
├── .xcind.sh                         # XCIND_IS_WORKSPACE=1, domain, hooks
│
├── frontend/                         # Application
│   ├── .xcind.sh                     # App config + XCIND_PROXY_EXPORTS
│   ├── compose.yaml
│   └── .xcind/                       # Generated files (gitignored)
│       ├── cache/{sha}/
│       └── generated/{sha}/
│
├── backend/                          # Application
│   ├── .xcind.sh
│   ├── compose.yaml
│   ├── compose.worker.yaml
│   └── .xcind/
│
└── shared-db/                        # Application
    ├── .xcind.sh
    ├── compose.yaml
    └── .xcind/
```

## Compose Files in a Subdirectory

When `XCIND_COMPOSE_DIR` is set, compose files are resolved from that subdirectory:

```
myapp/
├── .xcind.sh                         # XCIND_COMPOSE_DIR="docker"
├── docker/                           # Compose file subdirectory
│   ├── compose.yaml
│   └── compose.override.yaml
├── .env
└── .xcind/
```

---

## Generated Files

The `.xcind/` directory contains all generated and cached files:

| Path | Purpose |
|------|---------|
| `.xcind/cache/{sha}/resolved-config.yaml` | Merged compose config used by hooks for port inference and service validation |
| `.xcind/generated/{sha}/compose.naming.yaml` | Docker Compose project name |
| `.xcind/generated/{sha}/compose.app.yaml` | App identity labels |
| `.xcind/generated/{sha}/compose.app-env.yaml` | App env file injection |
| `.xcind/generated/{sha}/compose.host-gateway.yaml` | `host.docker.internal` mapping |
| `.xcind/generated/{sha}/compose.proxy.yaml` | Traefik labels and proxy network |
| `.xcind/generated/{sha}/compose.assigned.yaml` | Stable host port bindings |
| `.xcind/generated/{sha}/compose.workspace.yaml` | Workspace network aliases |

The `{sha}` is a SHA-256 hash of the configuration inputs. When inputs change, a new SHA directory is created and hooks re-run.

---

## Recommended `.gitignore`

```
.xcind/
```

---

## Related Documents

- [Context Detection](./context-detection.md) — How xcind locates `.xcind.sh` files
- [Generated Override Files](./generated-override-files.md) — What hooks generate
- [Configuration Schemas](./configuration-schemas.md) — Configuration levels
