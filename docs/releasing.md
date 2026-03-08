# Releasing xcind

## Prerequisites

The following secrets must be configured in the GitHub repository settings
(Settings → Secrets and variables → Actions):

| Secret | Purpose |
|--------|---------|
| `NPM_TOKEN` | npm access token for publishing to npmjs.org |
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password or access token |

`GITHUB_TOKEN` is provided automatically by GitHub Actions.

## Bump the version

Run `contrib/release.sh` with the desired bump type:

```bash
contrib/release.sh --patch   # 0.1.0 → 0.1.1
contrib/release.sh --minor   # 0.1.0 → 0.2.0
contrib/release.sh --major   # 0.1.0 → 1.0.0
```

This updates the version in `package.json`, `lib/xcind/xcind-lib.bash`, and
`Dockerfile`, then creates a commit and an annotated tag `v<version>`.

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

The `release: published` event triggers both `release.yml` (npm publishing) and
`release-dockerhub.yml` (Docker image publishing).

## What happens automatically

After the GitHub Release is published:

- **`release.yml`** — publishes the package to npmjs.org and GitHub Packages
- **`release-dockerhub.yml`** — builds multi-platform images (amd64 + arm64)
  and pushes to Docker Hub and GHCR

## Verification

After the workflows complete:

```bash
# Check npm
npm view xcind version

# Check Docker Hub
docker pull beausimensen/xcind:<version>

# Check GHCR
docker pull ghcr.io/beausimensen/xcind:<version>
```

You can also check the GitHub Actions tab for workflow run status.
