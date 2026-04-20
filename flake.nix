{
  description = "Xcind Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      xcindVersion = "0.5.0";

      # Runtime dependency sets, factored so the wrapped build and anything
      # else that needs the same PATH stays in sync.
      #
      # yq is required — the default-registered hooks (proxy, workspace,
      # app-env, app, host-gateway) all need it. We use yq-go (mikefarah) for
      # a single static binary with no jq propagation.
      #
      # jq is only needed by the JSON-emitting binaries (xcind-config --json,
      # xcind-workspace --json) and for the config.json cache side-effect
      # produced by xcind-compose.
      #
      # docker is only needed by binaries that shell out to `docker compose`.
      xcindCoreDeps = pkgs: [ pkgs.coreutils pkgs.yq-go ];
      xcindJsonDeps = pkgs: [ pkgs.jq ];
      xcindDockerDeps = pkgs: [ pkgs.docker ];

      # Base attrs shared by both the wrapped and unwrapped derivations.
      baseAttrs = {
        version = xcindVersion;
        src = ./.;
        dontBuild = true;
        installPhase = ''
          runHook preInstall
          bash ./install.sh "$out"
          runHook postInstall
        '';
      };

      # Unwrapped build: installs xcind to $out but does not inject any
      # runtime dependencies. Users must provide jq/yq/docker themselves via
      # their own environment. Useful when downstream consumers want to pin
      # different tool versions or have jq/yq already on PATH.
      mkXcindMinimal = pkgs: pkgs.stdenv.mkDerivation (baseAttrs // {
        pname = "xcind-minimal";
        meta = with pkgs.lib; {
          description = "Docker Compose environment manager (unwrapped — bring your own jq/yq/docker)";
          license = licenses.mit;
          platforms = platforms.unix;
          mainProgram = "xcind-compose";
        };
      });

      # Wrapped build: same install, but each xcind-* binary is wrapped with
      # a PATH that contains its runtime dependencies so the binaries work
      # regardless of what the user has installed.
      mkXcind = pkgs: pkgs.stdenv.mkDerivation (baseAttrs // {
        pname = "xcind";
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postInstall =
          let
            core = xcindCoreDeps pkgs;
            json = xcindJsonDeps pkgs;
            docker = xcindDockerDeps pkgs;
            # xcind-compose, xcind-config, and xcind-workspace all need the
            # full set at runtime: they either exec `docker compose` directly
            # or go through __xcind-populate-cache, which shells out to
            # `docker compose config`.
            fullPath = pkgs.lib.makeBinPath (core ++ json ++ docker);
            # xcind-proxy manages its own Traefik stack via `docker compose
            # -f <fixed file>` and never runs the xcind pipeline. It still
            # needs jq for the --json variant of `status`, which serialises
            # the assigned-ports state as a JSON array.
            proxyPath = pkgs.lib.makeBinPath (core ++ json ++ docker);
          in ''
            wrapProgram "$out/bin/xcind-application" \
              --prefix PATH : ${fullPath}
            wrapProgram "$out/bin/xcind-compose" \
              --prefix PATH : ${fullPath}
            wrapProgram "$out/bin/xcind-config" \
              --prefix PATH : ${fullPath}
            wrapProgram "$out/bin/xcind-proxy" \
              --prefix PATH : ${proxyPath}
            wrapProgram "$out/bin/xcind-workspace" \
              --prefix PATH : ${fullPath}
          '';
        meta = with pkgs.lib; {
          description = "Docker Compose environment manager";
          license = licenses.mit;
          platforms = platforms.unix;
          mainProgram = "xcind-compose";
        };
      });
    in
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
        packages = {
          default = mkXcind pkgs;
          xcind = mkXcind pkgs;
          xcind-minimal = mkXcindMinimal pkgs;
        };

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
            yq-go
            curl
            git
            git-cliff
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
    ) // {
      overlays.default = final: _prev: {
        xcind = mkXcind final;
        xcind-minimal = mkXcindMinimal final;
      };
    };
}
