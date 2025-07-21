{ nixpkgs, ... } @ inputs: let
  inherit (nixpkgs) lib;
  sources = import ./sources;
  readTree = import sources.read-tree {};
  fmway = let
    var = { inherit lib root; };
    small = import ./lib/fmway/__util/small-functions.nix var;
    for-import = import ./lib/fmway/__util/for-import.nix var;
    tree-path = import ./lib/fmway/tree-path.nix var;
    matchers = import ./lib/fmway/matchers.nix var;
    root = small // for-import // {
      inherit tree-path matchers;
    };
    result = import ./lib/fmway/treeImport.nix var {
      folder = ./lib/fmway;
      variables = { inherit lib final; };
      depth = 0;
    };
  in result // result.parser;
  prevInfuse = import sources.infuse-nix;
  defaultInfuse = prevInfuse { inherit lib; };
  mkInfuse = sugars: {
    _sugars = sugars;
    __functor = self': (prevInfuse { inherit lib; sugars = self'._sugars; }).v1.infuse;
    sugarify = { ... } @ sugars': mkInfuse (fmway.uniqLastBy (x: x.name) (sugars ++ lib.attrsToList sugars'));
  };
  infuse = mkInfuse defaultInfuse.v1.default-sugars;
  final = {
    inherit fmway infuse readTree mapListToAttrs;
    inherit (fmway) mkFlake;
  };
  overlay = self: super: final;
  finalLib = lib.extend overlay;
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
in {
  inherit fmway infuse readTree;
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
