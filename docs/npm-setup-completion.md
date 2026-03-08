# NPM Setup — Remaining Steps

## 1. Create a Granular Access Token

1. Go to https://www.npmjs.com → Account Settings → Access Tokens
2. Click **Generate New Token** → **Granular Access Token**
3. Configure:
   - **Token name**: e.g. `xcind-github-actions`
   - **Expiration**: pick a reasonable window, set a reminder to rotate
   - **Packages and scopes**: Read and Write, all packages (can restrict to `@scinddev/xcind` after first publish)
   - **Organizations**: No access (not needed for publishing)
4. Copy the token

## 2. Add `NPM_TOKEN` to GitHub

1. Go to https://github.com/scinddev/xcind/settings/secrets/actions
2. Click **New repository secret**
3. Name: `NPM_TOKEN`
4. Value: paste the token from step 1

## 3. First publish

Create a GitHub Release (see `docs/releasing.md`) — the `release-npm.yml` workflow will publish to both npmjs and GitHub Packages.

## 4. Verify

```bash
npm view @scinddev/xcind version
npm install -g @scinddev/xcind
xcind-compose --help
```
