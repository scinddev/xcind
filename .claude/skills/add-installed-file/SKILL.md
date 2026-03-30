---
name: add-installed-file
description: Register new bin/* or lib/xcind/*.bash files in all installation/packaging manifests. TRIGGER when a new executable or library file is created under bin/ or lib/xcind/.
---

# Add Installed File

Register a new file in all installation/packaging manifests so it is included in
every release channel (shell install, npm, Nix, Docker, CI).

## Arguments

$ARGUMENTS — path(s) to the new file(s) relative to the project root (e.g. `bin/xcind-foo` or `lib/xcind/xcind-foo-lib.bash`).

## Instructions

For **each** file path provided in $ARGUMENTS, update the manifests listed below.
Determine the file type from the path prefix:

- `bin/*` — an executable (applies to all 7 manifests)
- `lib/xcind/*.bash` — a library (applies to manifests 1-4 only; add to 5-7 only for shell scripts)

### 1. `install.sh`

Add an `install` line in the appropriate section (bin or lib), following the
existing pattern:

- Executables: `install -m 755 "$XCIND_ROOT/<path>" "$PREFIX/<path>"`
- Libraries:   `install -m 644 "$XCIND_ROOT/<path>" "$PREFIX/<path>"`

Keep lines ordered consistently with the existing entries (bin section first,
then lib).

### 2. `uninstall.sh`

Add a corresponding `rm -f "$PREFIX/<path>"` line, placed to mirror the
matching entry in `install.sh`.

### 3. `package.json`

- For `bin/*` files: add an entry to the `"bin"` object mapping the basename
  (without `bin/` prefix) to the relative path. Example:
  `"xcind-foo": "bin/xcind-foo"`
- For `lib/xcind/*` files: no change needed (the `"files"` array already
  includes `"lib"` as a directory glob).

### 4. `flake.nix`

- For `bin/*` files: add a `wrapProgram "$out/bin/<name>"` block in the
  `postInstall` section. You will need to determine what PATH dependencies
  the new executable needs — read the script to find out. Use the same
  `--prefix PATH : ${pkgs.lib.makeBinPath [ ... ]}` pattern.
- For `lib/xcind/*` files: no change needed (install.sh handles it).

### 5. `contrib/test-all`

Add the file path to the `SHELL_FILES` array (sorted alphabetically,
bin/ entries first, then lib/xcind/, then test/, then top-level scripts).

### 6. `.github/workflows/tests.yml`

Add the file path to the `shellcheck` step's file list in the `shellcheck` job
(sorted the same way as contrib/test-all).

### 7. `Makefile`

Add the file path to the `SHELL_FILES` variable (sorted the same way as
contrib/test-all).

## Verification

After making all changes, run `contrib/check-file-manifest` to verify
consistency. If it reports mismatches, fix them before finishing.
