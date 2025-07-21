let
  res = import ./flake-module.nix {
    nixpkgs.lib = import <nixpkgs/lib>;
  };
in res.fmway // {
  inherit (res) fmway infuse readTree;
  finalLib = res.lib;
}
