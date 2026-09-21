{ pkgs }:

pkgs.writeShellApplication {
  name = "mar-format";
  runtimeInputs = [
    pkgs.fourmolu
    pkgs.nixfmt-rfc-style
  ];
  text = ''
    find . -type f -name '*.hs' -print0 | xargs -0 -r fourmolu --config .haskell-format -i
    find . -type f -name '*.nix' -print0 | xargs -0 -r nixfmt
  '';
}
