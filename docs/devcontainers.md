# Dev Containers (Experimental)

Xcind can generate the artifacts needed to open a Docker Compose application as a
[Dev Container](https://containers.dev/) in VS Code or any editor that supports
the Dev Containers specification.

> **Status:** This workflow is experimental and best-effort. It is not
> automatically kept in sync — if your `.xcind.sh` or compose files change, you
> must regenerate manually.

## How It Works

The Dev Containers specification supports
[Docker Compose](https://containers.dev/supporting#docker-compose)-based
configurations. A `devcontainer.json` file points at one or more compose files,
names the service to develop inside, and declares the workspace folder within
that container.

Xcind's `--generate-docker-compose-configuration` flag produces a fully-resolved,
flattened compose configuration (equivalent to `xcind-compose config` output). A
Dev Container configuration can reference this file directly — no plugins, no
wrappers, no runtime resolution needed.

## Setup

### 1. Generate the compose configuration into `.devcontainer/`

```bash
xcind-config --generate-docker-compose-configuration=.devcontainer/compose.xcind.yaml
```

This creates `.devcontainer/compose.xcind.yaml` containing the fully-merged
compose configuration for your application, with all xcind-resolved compose
files, environment files, and hook-generated overlays baked in.

### 2. Create `devcontainer.json`

Create `.devcontainer/devcontainer.json` alongside the generated compose file:

```jsonc
{
  "name": "My App",
  "dockerComposeFile": "compose.xcind.yaml",
  "service": "php",
  "workspaceFolder": "/var/www/html"
}
```

Adjust these values for your application:

- **`service`** — the compose service you develop inside (e.g., `php`, `app`,
  `node`). Run `xcind-compose ps --services` to see available services.
- **`workspaceFolder`** — the path *inside the container* where your source code
  is mounted. Check the `volumes:` section of your compose files to find the
  mount target.

### 3. Add to `.gitignore`

The generated compose configuration is a snapshot specific to your local
environment. It should not be committed:

```gitignore
# in .gitignore
.devcontainer/compose.xcind.yaml
```

You may choose to commit `devcontainer.json` itself if the service name and
workspace folder are consistent across the team.

### 4. Open in Dev Container

In VS Code with the
[Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
installed, open the project folder. VS Code will detect `.devcontainer/` and
offer to reopen in the container.

## Regenerating After Changes

When your xcind configuration changes — new compose files, updated environment
variables, changed hooks — regenerate the snapshot:

```bash
xcind-config --generate-docker-compose-configuration=.devcontainer/compose.xcind.yaml
```

Then rebuild the Dev Container in VS Code (command palette → **Dev Containers:
Rebuild Container**).

The underlying compose stack must be working before you generate. If
`xcind-compose up` fails, `--generate-docker-compose-configuration` will also
fail.

## Customizing the Dev Container

The `devcontainer.json` file supports additional configuration beyond the
compose file reference. Common additions:

```jsonc
{
  "name": "My App",
  "dockerComposeFile": "compose.xcind.yaml",
  "service": "php",
  "workspaceFolder": "/var/www/html",

  // VS Code extensions to install in the container
  "customizations": {
    "vscode": {
      "extensions": [
        "bmewburn.vscode-intelephense-client",
        "ms-azuretools.vscode-docker"
      ]
    }
  },

  // Commands to run after the container is created
  "postCreateCommand": "composer install",

  // Forward ports from the container to the host
  "forwardPorts": [8080, 3306],

  // Environment variables for the dev container shell
  "remoteEnv": {
    "APP_ENV": "dev"
  }
}
```

See the [Dev Containers specification](https://containers.dev/implementors/json_reference/)
for the full set of available properties.

## Limitations

- **Manual regeneration required.** Unlike the JetBrains plugin or a wrapper
  script approach, the Dev Container configuration does not automatically
  reflect changes to `.xcind.sh`. You must re-run
  `--generate-docker-compose-configuration` and rebuild the container.

- **Single service.** Dev Containers are opinionated about one service being the
  development target. If you regularly work across multiple services, the
  standard `xcind-compose exec <service> bash` workflow may be more practical.

- **Flattened configuration.** The generated compose configuration is a merged
  snapshot. Xcind's layered compose file structure, override variants, and hook
  overlays are baked in at generation time. The dynamic resolution that
  `xcind-compose` provides at runtime does not apply.

- **Host paths.** The flattened compose file contains absolute host paths
  resolved at generation time. If your project directory moves, regenerate.
