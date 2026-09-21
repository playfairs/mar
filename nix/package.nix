{ pkgs }:

pkgs.haskellPackages.callCabal2nix "mar" ../. { }
