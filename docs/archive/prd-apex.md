# PRD: Apex URLs

**Status:** Draft
**Author:** —
**Date:** 2026-03-24
**Depends on:** [PRD: xcind-proxy](prd-proxy.md)

---

## 1. Problem Statement

When an application exports services through the proxy, each exported service gets a hostname that includes the export name — e.g., `myapp-web.localhost` or `dev-myapp-web.localhost`. For applications with a clear primary service (the common case), this export suffix adds verbosity without value. Users expect to reach their app at `myapp.localhost` or `dev-myapp.localhost` — a shorter, app-level "apex" URL.

Today, neither xcind nor Scind support an app-level hostname without the export suffix. This PRD adds apex URL support to xcind's proxy system.

---

## 2. Goals

1. Provide a shorter, app-level hostname (apex URL) for the primary exported service.
2. The apex URL is an **additional** route — the primary export keeps its export-specific URL too.
3. Follow the existing workspaceless/workspace template pattern for consistency.
4. Make the feature automatic (zero config for the common case) with an opt-out mechanism.

## 3. Non-Goals

- Apex URLs for non-primary exports (each app gets at most one apex URL).
- Replacing or suppressing the export-specific URL for the primary export (both always coexist).
- Apex URLs for internal workspace aliases (this is proxy-layer only).

---

## 4. Design

### 4.1 Primary Export Selection

The **first entry** in `XCIND_PROXY_EXPORTS` is the primary export. It receives both:

- Its export-specific hostname (from `XCIND_APP_URL_TEMPLATE`, e.g., `myapp-web.localhost`)
- The apex hostname (from `XCIND_APP_APEX_URL_TEMPLATE`, e.g., `myapp.localhost`)

All other exports receive only their export-specific hostname.

This convention requires no new syntax or configuration. The user controls priority by ordering their exports array.

### 4.2 Apex URL Templates

Apex URL templates follow the same workspaceless/workspace pattern established in [prd-proxy.md Section 4.7](prd-proxy.md#47-url-template-system).

#### Source templates (user-configurable)

| Variable | Default |
|----------|---------|
| `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` | `{app}.{domain}` |
| `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` | `{workspace}-{app}.{domain}` |
| `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` | `{app}-{protocol}` |
| `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` | `{workspace}-{app}-{protocol}` |

#### Resolved templates (computed by pipeline)

| Variable | Set from |
|----------|----------|
| `XCIND_APP_APEX_URL_TEMPLATE` | `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` or `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` based on `XCIND_WORKSPACELESS` |
| `XCIND_APEX_ROUTER_TEMPLATE` | `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` or `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` based on `XCIND_WORKSPACELESS` |

Template variables available for apex templates:

- `{app}` = `XCIND_APP`
- `{workspace}` = `XCIND_WORKSPACE` (absent from workspaceless templates)
- `{domain}` = `XCIND_PROXY_DOMAIN`
- `{protocol}` = protocol suffix (always `http` for v1)

Note: `{export}` is intentionally absent from apex templates — the whole point is an app-level URL without the export suffix.

### 4.3 Opting Out

Set the apex URL template to an empty string to disable apex URLs:

```bash
# In .xcind.sh — disable apex URLs for this app
XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=""
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""
```

When `XCIND_APP_APEX_URL_TEMPLATE` resolves to an empty string, the proxy hook skips apex route generation entirely. The primary export still gets its export-specific URL as normal.

---

## 5. Impact on Existing PRD Sections

### 5.1 Pipeline (prd-proxy.md Section 4.4, step 6)

`__xcind-resolve-url-templates` additionally resolves:

- `XCIND_APP_APEX_URL_TEMPLATE` from the workspaceless/workspace apex URL variant
- `XCIND_APEX_ROUTER_TEMPLATE` from the workspaceless/workspace apex router variant

Both are exported as environment variables alongside the existing `XCIND_APP_URL_TEMPLATE` and `XCIND_ROUTER_TEMPLATE`.

### 5.2 URL Template System (prd-proxy.md Section 4.7)

Add the 4 source templates and 2 resolved templates from Section 4.2 above to the source and resolved template tables.

### 5.3 Proxy Hook (prd-proxy.md Section 5.5)

Step 1 additionally reads `XCIND_APP_APEX_URL_TEMPLATE` and `XCIND_APEX_ROUTER_TEMPLATE` from the environment.

The hook identifies the first entry in `XCIND_PROXY_EXPORTS` as the primary export. When generating labels for the primary export's compose service, and `XCIND_APP_APEX_URL_TEMPLATE` is non-empty, the hook generates additional Traefik router labels and xcind apex labels (see Section 6).

### 5.4 Hostname Generation (prd-proxy.md Section 8)

Add apex hostname and router generation:

```bash
# Apex hostname — only for primary export, only if template is non-empty
if [[ -n "$XCIND_APP_APEX_URL_TEMPLATE" ]]; then
  apex_hostname=$(__xcind-render-template "$XCIND_APP_APEX_URL_TEMPLATE" \
    workspace "$XCIND_WORKSPACE" app "$XCIND_APP" \
    domain "$XCIND_PROXY_DOMAIN")

  apex_router=$(__xcind-render-template "$XCIND_APEX_ROUTER_TEMPLATE" \
    workspace "$XCIND_WORKSPACE" app "$XCIND_APP" \
    protocol "http")
fi
```

Add to the default templates and examples table:

| Mode | Template | Example |
|------|----------|---------|
| Workspaceless apex hostname | `{app}.{domain}` | `myapp.localhost` |
| Workspace apex hostname | `{workspace}-{app}.{domain}` | `dev-myapp.localhost` |
| Workspaceless apex router | `{app}-{protocol}` | `myapp-http` |
| Workspace apex router | `{workspace}-{app}-{protocol}` | `dev-myapp-http` |

### 5.5 Context Labels (prd-proxy.md Section 11)

Add apex labels (only present on the primary export's compose service):

| Label | Source | Example |
|-------|--------|---------|
| `xcind.apex.host` | Apex hostname | `myapp.localhost` |
| `xcind.apex.url` | `http://{apex hostname}` | `http://myapp.localhost` |

### 5.6 Variable Reference (prd-proxy.md Section 7.1c)

Add to the variable reference table:

| Variable | Set By | Default | Description |
|----------|--------|---------|-------------|
| `XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE` | user | `{app}.{domain}` | Apex hostname template (no workspace) |
| `XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE` | user | `{workspace}-{app}.{domain}` | Apex hostname template (with workspace) |
| `XCIND_WORKSPACELESS_APEX_ROUTER_TEMPLATE` | user | `{app}-{protocol}` | Apex router name template (no workspace) |
| `XCIND_WORKSPACE_APEX_ROUTER_TEMPLATE` | user | `{workspace}-{app}-{protocol}` | Apex router name template (with workspace) |
| `XCIND_APP_APEX_URL_TEMPLATE` | computed | — | Resolved apex hostname template |
| `XCIND_APEX_ROUTER_TEMPLATE` | computed | — | Resolved apex router name template |

---

## 6. Override Generation

### 6.1 Service Template (primary export with apex)

When the primary export has an apex URL, the service snippet template includes additional Traefik router labels and xcind apex labels. The hook uses this extended template only for the primary export.

**Per-service template for primary export (without workspace):**

```bash
XCIND_PROXY_SERVICE_TEMPLATE_APEX='  {compose_service}:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "traefik.http.routers.{apex_router}.rule=Host(`{apex_hostname}`)"
      - "traefik.http.routers.{apex_router}.entrypoints=web"
      - "traefik.http.services.{apex_router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"
      - "xcind.apex.host={apex_hostname}"
      - "xcind.apex.url=http://{apex_hostname}"'
```

**Per-service template for primary export (with workspace):**

```bash
XCIND_PROXY_SERVICE_TEMPLATE_APEX_WORKSPACE='  {compose_service}:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.{router}.rule=Host(`{hostname}`)"
      - "traefik.http.routers.{router}.entrypoints=web"
      - "traefik.http.services.{router}.loadbalancer.server.port={port}"
      - "traefik.http.routers.{apex_router}.rule=Host(`{apex_hostname}`)"
      - "traefik.http.routers.{apex_router}.entrypoints=web"
      - "traefik.http.services.{apex_router}.loadbalancer.server.port={port}"
      - "xcind.app.name={app}"
      - "xcind.app.path={app_path}"
      - "xcind.workspace.name={workspace}"
      - "xcind.workspace.path={workspace_path}"
      - "xcind.export.{export}.host={hostname}"
      - "xcind.export.{export}.url=http://{hostname}"
      - "xcind.apex.host={apex_hostname}"
      - "xcind.apex.url=http://{apex_hostname}"'
```

**Rendering:**

```bash
__xcind-render-template "$apex_service_template" \
  compose_service "$compose_svc" \
  router "$router" \
  hostname "$hostname" \
  apex_router "$apex_router" \
  apex_hostname "$apex_hostname" \
  port "$port" \
  app "$XCIND_APP" \
  app_path "$app_root" \
  workspace "$XCIND_WORKSPACE" \
  workspace_path "$XCIND_WORKSPACE_ROOT" \
  export "$export_name"
```

### 6.2 Algorithm Update (prd-proxy.md Section 12.2)

The step-by-step flow in Section 12.2 is modified:

- **After step 2**, add: Read `XCIND_APP_APEX_URL_TEMPLATE` and `XCIND_APEX_ROUTER_TEMPLATE` from the environment.
- **Step 5** (template selection) becomes: Select base service template (workspace or workspaceless). Additionally, if this is the first export AND `XCIND_APP_APEX_URL_TEMPLATE` is non-empty, select the apex variant of the service template.
- **Step 7** (for each export), for the **first export only**:
  - d2. **Generate apex hostname** via `__xcind-render-template` using `XCIND_APP_APEX_URL_TEMPLATE`.
  - e2. **Generate apex router name** via `__xcind-render-template` using `XCIND_APEX_ROUTER_TEMPLATE`.
  - f. **Record** includes apex_hostname and apex_router for the primary export.

### 6.3 Grouping Consideration

When the primary export shares a compose service with another export (e.g., `XCIND_PROXY_EXPORTS=("web=nginx" "api=nginx:3000")`), the apex labels are included in the merged label list for that compose service. The apex Traefik router and xcind apex labels appear alongside all export-specific labels in the single YAML service block.

---

## 7. Examples

### 7.1 Workspaceless — Multiple Exports

```bash
# .xcind.sh
XCIND_PROXY_EXPORTS=("web" "api:3000")
XCIND_APP="myapp"
```

Generated `compose.proxy.yaml`:

```yaml
services:
  web:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-web-http.rule=Host(`myapp-web.localhost`)"
      - "traefik.http.routers.myapp-web-http.entrypoints=web"
      - "traefik.http.services.myapp-web-http.loadbalancer.server.port=80"
      - "traefik.http.routers.myapp-http.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.myapp-http.entrypoints=web"
      - "traefik.http.services.myapp-http.loadbalancer.server.port=80"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"
      - "xcind.export.web.host=myapp-web.localhost"
      - "xcind.export.web.url=http://myapp-web.localhost"
      - "xcind.apex.host=myapp.localhost"
      - "xcind.apex.url=http://myapp.localhost"

  api:
    networks:
      xcind-proxy: {}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-api-http.rule=Host(`myapp-api.localhost`)"
      - "traefik.http.routers.myapp-api-http.entrypoints=web"
      - "traefik.http.services.myapp-api-http.loadbalancer.server.port=3000"
      - "xcind.app.name=myapp"
      - "xcind.app.path=/path/to/myapp"
      - "xcind.export.api.host=myapp-api.localhost"
      - "xcind.export.api.url=http://myapp-api.localhost"

networks:
  xcind-proxy:
    external: true
```

The `web` service (first export) gets three Traefik routers: export-specific (`myapp-web-http`) and apex (`myapp-http`). The `api` service gets only its export-specific router.

### 7.2 Workspace — Multiple Exports

```bash
# workspace .xcind.sh (in parent directory)
XCIND_IS_WORKSPACE=1

# app .xcind.sh
XCIND_PROXY_EXPORTS=("web" "api:3000")
XCIND_APP="myapp"
```

With workspace "dev", generated hostnames:

| Service | Export-specific URL | Apex URL |
|---------|-------------------|----------|
| web (primary) | `http://dev-myapp-web.localhost` | `http://dev-myapp.localhost` |
| api | `http://dev-myapp-api.localhost` | — |

### 7.3 Single Export

```bash
XCIND_PROXY_EXPORTS=("web")
XCIND_APP="myapp"
```

The single export gets both URLs:
- `http://myapp-web.localhost` (export-specific)
- `http://myapp.localhost` (apex)

### 7.4 Apex Disabled

```bash
XCIND_PROXY_EXPORTS=("web" "api:3000")
XCIND_APP="myapp"
XCIND_WORKSPACELESS_APP_APEX_URL_TEMPLATE=""
XCIND_WORKSPACE_APP_APEX_URL_TEMPLATE=""
```

No apex route is generated. All exports get only their export-specific URLs, matching the behavior before this feature.

---

## 8. Discovery via Labels

The apex labels enable tooling to find the app's primary URL:

```bash
# Find the apex URL for a specific app
docker inspect --format '{{index .Config.Labels "xcind.apex.url"}}' <container>

# Find all containers with apex URLs
docker ps --filter "label=xcind.apex.host"
```

---

## 9. Open Questions

1. **Explicit primary override:** Should there be an `XCIND_APEX_EXPORT` variable to override the first-entry convention? This would let users set `XCIND_APEX_EXPORT="api"` to make a non-first export the primary.

2. **Single-export suppression:** For apps with exactly one export, should the export-specific URL be suppressible (leaving only the apex)? This would avoid the redundancy of `myapp.localhost` and `myapp-web.localhost` both pointing to the same service.

---

## 10. Success Criteria

- [ ] First entry in `XCIND_PROXY_EXPORTS` gets both apex and export-specific Traefik routes.
- [ ] Non-primary exports get only export-specific routes.
- [ ] Apex hostnames resolve correctly via `.localhost` with zero DNS configuration.
- [ ] Workspace mode produces workspace-prefixed apex hostnames (e.g., `dev-myapp.localhost`).
- [ ] Workspaceless mode produces plain apex hostnames (e.g., `myapp.localhost`).
- [ ] Custom apex URL templates override defaults.
- [ ] Empty apex URL template disables apex route generation.
- [ ] `xcind.apex.host` and `xcind.apex.url` labels present on primary export container.
- [ ] Apex labels absent from non-primary export containers.
- [ ] Grouped exports (multiple exports on same compose service) include apex labels in merged label list.
- [ ] Existing workflows without apex customization continue to work (apex is automatic).
