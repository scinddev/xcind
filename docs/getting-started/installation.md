# Installation

Xcind is a small set of shell scripts. Pick whichever channel you prefer.

## npm (recommended)

```bash
npm install -g @scinddev/xcind
```

Or run without installing:

```bash
npx -p @scinddev/xcind xcind-compose up -d
```

## Install script

```bash
# Install to /usr/local (may need sudo)
sudo ./install.sh

# Custom prefix
./install.sh ~/.local

# Uninstall
sudo ./uninstall.sh
./uninstall.sh ~/.local
```

## Nix

```bash
# Imperative install
nix profile install github:scinddev/xcind

# Run directly without installing
nix run github:scinddev/xcind -- up -d
```

To consume from another flake or via overlay, see the project [README](../../README.md#nix).

## Docker

```bash
docker pull ghcr.io/scinddev/xcind:latest

docker run --rm \
  -v "$PWD":/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/scinddev/xcind:latest up -d
```

The image's entrypoint is `xcind-compose`.

## Verify

```bash
xcind-config --version
```

Installs from non-tagged channels (Nix flake from `main`, install script run inside a git clone, locally built Docker image) append SemVer build metadata so the output identifies the exact source — e.g. `xcind-config 0.5.0+nix.1a2b3c4.20260420`. See [build provenance](../../engineering/reference/build-provenance.md) for the full format.

## Upgrade

Use the same channel you installed from:

```bash
npm install -g @scinddev/xcind@latest
sudo ./install.sh                      # re-run from a fresh clone
nix profile upgrade '.*xcind.*'
docker pull ghcr.io/scinddev/xcind:latest
```

Xcind is stateless — there is no data to migrate between versions.

## Next

- [Your first project](./first-project.md) — set up an app and run it.
