# Build Provenance

Every xcind install reports its version via `xcind-<command> --version`. The
*declared* version (`XCIND_VERSION`, bumped by `contrib/release` at tag time)
is the single source of truth for "which release is this". But the same
declared version can reach a user through several channels — a tagged npm
tarball, a Nix flake pointing at `main`, a dirty local checkout installed
with `install.sh` — and those need to be distinguishable.

Xcind separates the two concerns:

- **`XCIND_VERSION`** in `lib/xcind/xcind-lib.bash` — committed, bumped only
  at release tag, always reflects the next/current release number.
- **`lib/xcind/xcind-build-info.bash`** — optional, *never committed*. Written
  at install/build time by the distribution channel. Declares a small set of
  `XCIND_BUILD_*` variables describing how *this particular copy* was built.

`xcind-lib.bash` sources the build-info file if present, then formats the
`--version` output with the combined information.

## Version String Format

```
<XCIND_VERSION>[+<SOURCE>[.<SHORT_REV>][.dirty][.<DATE>]]
```

The `+…` suffix follows SemVer's *build metadata* rules: each dot-separated
identifier matches `[0-9A-Za-z-]+`, and the suffix is ignored for version
comparison.

| Context | Output |
|---|---|
| Tagged release (npm, docker `:0.5.0`) | `0.5.0` |
| Nix flake from `main`, clean | `0.5.0+nix.1a2b3c4.20260420` |
| Nix flake from `main`, dirty tree | `0.5.0+nix.1a2b3c4.dirty.20260420` |
| `install.sh` from a git clone, clean | `0.5.0+install.1a2b3c4.20260420` |
| `install.sh` from a git clone, dirty | `0.5.0+install.1a2b3c4.dirty.20260420` |
| `install.sh` from a tarball (no `.git`) | `0.5.0` |
| Docker `:latest` (untagged build) | `0.5.0+docker.1a2b3c4.20260420` |

`<SOURCE>` is one of: `nix`, `install`, `docker`, `npm`.
`<DATE>` is compact `YYYYMMDD` (no separators) derived from
`XCIND_BUILD_DATE`'s ISO 8601 prefix.
`<SHORT_REV>` is 7 hex chars.

## `xcind-build-info.bash` Schema

Plain bash assignments, sourced by `xcind-lib.bash` under
`set -euo pipefail`. All fields are mandatory but may be empty strings when
the channel cannot determine them.

```bash
#!/usr/bin/env bash
# xcind-build-info.bash — Build provenance for this install.

XCIND_BUILD_SOURCE="nix"                 # nix | install | docker | npm
XCIND_BUILD_SHORT_REV="1a2b3c4"          # 7-char git short hash, or ""
XCIND_BUILD_LONG_REV="1a2b3c4d5e6f…"     # 40-char git hash, or ""
XCIND_BUILD_REF="main"                   # branch or tag name, or ""
XCIND_BUILD_DATE="2026-04-20T12:15:30Z"  # ISO 8601 UTC, or ""
XCIND_BUILD_DIRTY="0"                    # "1" if tree was dirty, else "0"
```

The file is safe to source multiple times (no side effects beyond variable
assignment) and is removed by `uninstall.sh`.

## Per-Channel Behavior

### Nix flake

`flake.nix` writes `xcind-build-info.bash` in `postInstall`, reading
`self.rev` / `self.dirtyRev` / `self.shortRev` / `self.dirtyShortRev` /
`self.lastModifiedDate`. `XCIND_BUILD_REF` is left empty — the flake cannot
reliably know the ref it was fetched under (`github:scinddev/xcind/main` is
input-side information, not derivation-side), and the short rev is
unambiguous on its own.

### `install.sh`

When the source tree is a git checkout, `install.sh` captures the current
HEAD, branch, commit date, and dirty state and writes the file into
`$PREFIX/lib/xcind/`. Tarballs without a `.git` directory skip the step, so
`--version` falls back to the plain declared version — correct for release
tarballs.

### Dockerfile

`Dockerfile` takes the provenance as build args
(`XCIND_BUILD_SHORT_REV`, `XCIND_BUILD_LONG_REV`, `XCIND_BUILD_REF`,
`XCIND_BUILD_DATE`, `XCIND_BUILD_DIRTY`). The release workflow
(`.github/workflows/release-docker.yml`) passes these from
`github.sha` / `github.ref_name` and a captured UTC timestamp. Local
`docker build .` without build-args produces an image where
`XCIND_BUILD_SHORT_REV` is empty — the suffix degrades to just `+docker`.

### npm

The npm tarball is always published from a tagged release. `XCIND_VERSION`
inside the tarball is authoritative on its own, so no `xcind-build-info.bash`
is written. This is a deliberate skip, not an oversight.
