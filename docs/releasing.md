# Releasing xcind

## Prerequisites

The following secrets must be configured in the GitHub repository settings
(Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `NPM_TOKEN` | npm access token for publishing to npmjs.org |

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

## Bump the version

Run `contrib/release` with the desired bump type:

```bash
contrib/release --patch   # 0.1.0 → 0.1.1
contrib/release --minor   # 0.1.0 → 0.2.0
contrib/release --major   # 0.1.0 → 1.0.0
```

This updates the version in `package.json`, `lib/xcind/xcind-lib.bash`,
`Dockerfile`, and `flake.nix`, then creates a commit and an annotated tag
`v<version>`.

## Push to GitHub

```bash
git push --follow-tags
```

## Create a GitHub Release

Publishing a GitHub Release is the trigger for all automated release workflows.

Using the GitHub CLI:

```bash
gh release create v<version> --generate-notes
```

Or use the GitHub web UI at the repository's releases page.

The `release: published` event triggers both `release-npm.yml` (npm publishing) and
`release-docker.yml` (Docker image publishing).

## What happens automatically

After the GitHub Release is published:

- **`release-npm.yml`** — publishes the package to npmjs.org and GitHub Packages
- **`release-docker.yml`** — builds multi-platform images (amd64 + arm64)
  and pushes to GHCR

## Verification

After the workflows complete:

```bash
# Check npm
npm view @scinddev/xcind version

# Check GHCR
docker pull ghcr.io/scinddev/xcind:<version>
```

You can also check the GitHub Actions tab for workflow run status.

## Build provenance

The release flow does not need any additional steps for build provenance to
work. `install.sh`, the Nix flake, and the Docker image all write their own
`lib/xcind/xcind-build-info.bash` at install/build time, which
`xcind-<command> --version` appends to the output as SemVer build metadata
(`0.5.0+nix.1a2b3c4.20260420`, etc.). Tagged npm tarballs deliberately omit
the file — `XCIND_VERSION` alone is authoritative there. See
[reference/build-provenance.md](reference/build-provenance.md) for the full
schema.
