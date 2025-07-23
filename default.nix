let
  self = import ./flake-module.nix {
    nixpkgs.lib = import <nixpkgs/lib>;
    inherit self;
  };
in self.fmway // removeAttrs self [ "lib" "overlays" ] // {
  finalLib = self.lib;
}
