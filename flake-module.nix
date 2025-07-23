{ nixpkgs, self, ... } @ inputs: let
  inherit (nixpkgs) lib;
  sources = import ./sources;
  final = let
    var = { inherit lib self'; };
    small = import ./lib/fmway/__util/small-functions.nix var;
    for-import = import ./lib/fmway/__util/for-import.nix var;
    tree-path = import ./lib/fmway/tree-path.nix var;
    matchers = import ./lib/fmway/matchers.nix var;
    self'.fmway = small // for-import // {
      inherit tree-path matchers;
    };
    res = import ./lib/fmway/treeImport.nix var {
      folder = ./lib;
      variables = {
        inherit lib sources final;
        self' = self;
      };
      depth = 0;
    };
  in res // {
    fmway = res.fmway // res.fmway.parser;
  };
  overlay = self: super: final;
  finalLib = lib.extend overlay;
in final // {
  lib = finalLib;
  overlays.default = overlay;
  
  # wrap mkShell to handle lorri shellHook problems
  overlays.devshell-lorri-fix = self: super: {
    mkShell = rec {
      override = { ... } @ a: { shellHook ? "", ... } @ v: let
        args = removeAttrs v [ "shellHook" ] // lib.optionalAttrs (shellHook != "") {
          shellHook = ''
            # if not inside lorri env
            if [[ "$0" =~ bash$ ]]; then
              . "${shellHook'}"
            else
              cat "${shellHook'}"
            fi
          '';
        };
        shellHook' = self.writeScript "shellHook.sh" shellHook;
      in super.mkShell.override a args;
      inherit (super.mkShell) __functionArgs;
      __functor = s: override {};
    };
    mkShellNoCC = self.mkShell.override { stdenv = self.stdenvNoCC; };
  };
}
