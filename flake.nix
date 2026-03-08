{
  description = "Xcind Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Python environment for building Sphinx docs (docs/source/)
        pythonEnv = pkgs.python3.withPackages (ps: with ps; [
          sphinx
          sphinx-rtd-theme
          myst-parser
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          name = "xcind-dev";

          buildInputs = with pkgs; [
            # -- Core runtime & testing --
            bash
            coreutils
            ncurses
            parallel

            # -- Code quality (tools used by .pre-commit-config.yaml) --
            shellcheck
            shfmt
            gitleaks
            pre-commit

            # -- npm packaging --
            nodejs

            # -- Documentation (Sphinx) --
            pythonEnv

            # -- Container builds --
            docker
            docker-compose

            # -- Utilities --
            jq
            curl
            git
          ];

          shellHook = ''
            # Let .pre-commit-config.yaml be the single source of truth
            if [ -f .pre-commit-config.yaml ] && [ -d .git ]; then
              pre-commit install --allow-missing-config > /dev/null 2>&1 || true
            fi

            export PATH="$PWD/bin:$PATH"

            echo "xcind dev shell ready"
            echo "  node      : $(node --version)"
            echo "  shellcheck: $(shellcheck --version | head -2 | tail -1)"
            echo "  sphinx    : $(sphinx-build --version)"
          '';
        };
      }
    );
}
