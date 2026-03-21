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
      depth = 0;
      inherit variables;
    };
  in res // {
    fmway = res.fmway // res.fmway.parser;
  };
  variables = {
    inherit lib sources final;
    self' = self;
  };
  overlay = self: super: final;
  finalLib = lib.extend overlay;
in final // {
  lib = finalLib;
  overlays.default = overlay;
  _input = variables;

  apps = lib.genAttrs [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ] (system: let
    pkgs = import inputs.nixpkgs { inherit system; overlays = [ self.overlays.updater ]; };
  in {
    fetch-sources = {
      type = "app";
      program = "${pkgs.fetch-sources}/bin/fetch-sources";
    };
  });
  
  # wrap mkShell to handle lorri shellHook problems
  overlays.updater = self: super: {
    fetch-sources = let
      get-hash = self.writeScript "get-hash.fish" ''
        #!${lib.getExe self.fish}

        ${lib.fileContents ./scripts/get-hash.fish}
      '';
    in self.writeScriptBin "fetch-sources" ''
      #!${lib.getExe self.nushell}
      alias get-hash = ${get-hash}

      ${lib.fileContents ./scripts/fetch-sources.nu}
    '';
  };
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
