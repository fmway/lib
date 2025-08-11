{ final, self', ... }:
/* Hierarchy flake project
   /.
   /modules => collections of modules
   /lib => collections of functions
   /top-level => auto-imports for flake modules
   /...
 */
{ inputs, src ? null, infuseLib ? false, ... } @ v1: let
  inherit (inputs) flake-parts;
  inherit (inputs.nixpkgs) lib;
  fixSrc = builtins.toPath src;
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
  ] ++ lib.optionals (!isNull src && lib.pathIsDirectory (/. + "${fixSrc}/lib")) [
    (self: super: let
      res = self'.fmway.treeImport {
        folder = (/. + "${fixSrc}/lib");
        depth = 0;
        variables = specialArgs // { inherit self super; };
      };
      fn =
        if lib.isBool infuseLib && infuseLib then
          self'.infuse
        else if lib.isAttrs infuseLib || lib.isList infuseLib then
          self'.infuse.sugarify infuseLib
        else _: x: x;
    in fn super res)
  ] ++ self'.fmway.flat default;
  specialArgs = (v1.specialArgs or {}) // {
    lib = overlay lib overlay-lib;
  };
  arg1 = removeAttrs v1 [ "src" "infuseLib" ] // {
    inherit specialArgs;
  };
  top-levels =
    self'.fmway.genImports (/. + "${fixSrc}/top-level")
  ++lib.optionals (lib.pathIsRegularFile "${fixSrc}/top-level/default.nix") [
    "${fixSrc}/top-level/default.nix"
  ];
in lib.throwIf (!isNull src && !lib.pathIsDirectory src) "src must be a directory"
(arg2: flake-parts.lib.mkFlake arg1 ({ lib, ... }: {
  debug = lib.mkDefault true;
  imports = lib.optionals (inputs ? systems) [
    { systems = lib.mkDefault (import inputs.systems); }
  ] ++ lib.optionals (inputs ? fmway-modules) [
    inputs.fmway-modules.flakeModules.nixpkgs
    {
      perSystem = { ... }: {
        nixpkgs.overlays = [
          self'.overlays.devshell-lorri-fix
          (self: super: {
            lib = overlay super.lib overlay-lib;
          })
        ];
      };
    }
  ] ++ lib.optionals (!isNull src && lib.pathIsDirectory "${fixSrc}/top-level") top-levels
    ++ lib.optionals (!isNull src && lib.pathIsDirectory "${fixSrc}/modules") [
    ({ self, config, lib, ... } @ v: {
      flake = self'.fmway.genModules "${fixSrc}/modules" v;
    })
  ] ++ [
    {
      perSystem = { pkgs, lib, ... }: {
        legacyPackages = lib.mkDefault pkgs;
      };
    }
    arg2
  ];
}))
