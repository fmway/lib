{ final, ... }:
{
  mkFlake = { inputs, strict-packages ? true, ... } @ v1: let
    inherit (inputs) flake-parts;
    inherit (inputs.nixpkgs) lib;
    overlay = lib: x:
      if lib.isAttrs x then
        lib.extend (_: _: x)
      else if lib.isFunction x then
        lib.extend x
      else if lib.isList x then
        lib.foldl' overlay lib x
      else throw "lib overlay doesn't support ${builtins.typeOf x}"
    ;
    overlay-lib = let
      default = v1.specialArgs.lib or {};
    in [
      final
      {
        flake-parts = flake-parts.lib;
      }
    ] ++ lib.flatten [ default ];
    arg1 = removeAttrs v1 [ "strict-packages" ] // {
      specialArgs = (v1.specialArgs or {}) // {
        lib = overlay lib overlay-lib;
      };
    };
  in arg2: flake-parts.lib.mkFlake arg1 ({ lib, ... }: {
    debug = lib.mkDefault true;
    imports = lib.optionals (inputs ? systems) [
      { systems = lib.mkDefault (import inputs.systems); }
    ] ++ lib.optionals (!strict-packages) [
      # don't strict packages
      ({ lib, flake-parts-lib, ... }: {
        disabledModules = [ "${flake-parts}/modules/packages.nix" ];
      } // flake-parts-lib.mkTransposedPerSystemModule {
        name = "packages";
        option = lib.mkOption {
          type = with lib.types; lazyAttrsOf anything;
          default = { };
        };
        file = ./packages.nix;
      })
    ] ++ lib.optionals (inputs ? fmway-modules) [
      inputs.fmway-modules.flakeModules.nixpkgs
      {
        perSystem = { ... }: {
          nixpkgs.overlays = [
            (self: super: {
              lib = overlay super.lib overlay-lib;
            })
          ];
        };
      }
    ] ++ [
      arg2
    ];
  });
}
