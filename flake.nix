{
  description = "mar, a fast local filesystem indexer and search CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nox.url = "github:playfairs/nox/dev";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nox,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        haskellPackages = pkgs.haskellPackages.override {
          overrides = hself: hsuper: {
            mar = hself.callCabal2nix "mar" ./. { };
          };
        };
        package = haskellPackages.mar;
        noxWrapper = pkgs.writeShellScriptBin "nox" ''
          set -eu
          real_ghc="$(command -v ghc)"
          quiet_dir="$(mktemp -d)"
          trap 'rm -rf "$quiet_dir"' EXIT
          cat > "$quiet_dir/ghc" <<EOF
          #!${pkgs.runtimeShell}
          if [ "\$1" = "--version" ]; then
            "''${real_ghc}" --version >/dev/null 2>&1
          else
            exec "''${real_ghc}" "\$@"
          fi
          EOF
          chmod +x "$quiet_dir/ghc"
          PATH="$quiet_dir:$PATH" exec ${nox.packages.${system}.default}/bin/nox "$@"
        '';
        formatter = pkgs.writeShellApplication {
          name = "mar-format";
          runtimeInputs = [
            pkgs.fourmolu
            pkgs.nixfmt-rfc-style
          ];
          text = ''
            find . -type f -name '*.hs' -print0 | xargs -0 -r fourmolu --config .haskell-format -i
            find . -type f -name '*.nix' -print0 | xargs -0 -r nixfmt
          '';
        };
      in
      {
        packages.default = package;
        apps.default = flake-utils.lib.mkApp { drv = package; };
        formatter = formatter;
        devShells.default = haskellPackages.shellFor {
          packages = p: [ p.mar ];
          buildInputs = [
            nox.packages.${system}.default
            pkgs.cabal-install
            pkgs.haskellPackages.hspec-discover
            pkgs.sqlite
          ];
          nativeBuildInputs = [
            pkgs.fourmolu
            pkgs.nixfmt-rfc-style
          ];
          shellHook = ''
            export PATH="${noxWrapper}/bin:$PATH"
            						export MAR_CONFIG_DIR="''${MAR_CONFIG_DIR:-$HOME/.config/mar}"
            					'';
        };
        checks.default = package;
      }
    );
}
