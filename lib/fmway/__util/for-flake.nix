{ lib, self', ... }: let
  inherit (self'.fmway)
    toCamelCase
    withImport'
  ;
in {
  genModules' = shareds: moduleDir: args: let
    modulesPath = builtins.toPath moduleDir;
    re = lib.pipe modulesPath [
      builtins.readDir
      (lib.filterAttrs (_: v: v == "directory"))
      (lib.attrNames)
      (map (dir: let
        scope = "${toCamelCase dir}Modules";
      in {
        name = scope;
        value = let
          res = args: lib.pipe "${modulesPath}/${dir}" [
            (builtins.readDir)
            (lib.filterAttrs (name: type:
              (! isNull (builtins.match ".+[.]nix" name) && type == "regular") ||
              (
                type == "directory" &&
                lib.pathIsRegularFile "${modulesPath}/${dir}/${name}/default.nix"
              )
            ))
            (lib.attrNames)
            (map (name: let
              _file = let
                path = /. + "${modulesPath}/${dir}/${name}";
              in path + lib.optionalString (lib.pathIsDirectory path) "/default.nix";
              module = lib.removeSuffix ".nix" name;
            in {
              name = module;
              value = let
                r = exc: withImport' _file (lib.optionalAttrs (scope != "SharedModules") {
                  allModules = map (x: final.${scope}.${x}) (
                    lib.filter (x:
                      x != module &&
                      lib.all (y: x != y) (exc ++ [ "defaultWithout" "default" "all" "allWithout" ])
                    ) (lib.attrNames final.${scope}));
                } // { inherit _file; } // args);
              in if module == "default" then r else r [];
            }))
            (lib.listToAttrs)
          ];
        in if scope == "SharedModules" then
          res
        else res (final // args);
      }))
      (lib.listToAttrs)
    ];
    gen = lib.listToAttrs (map (name: {
      inherit name;
      value = re.SharedModules (final // args // { inherit name; }) // (re.${name} or {});
    }) shareds);
    final = let
      r = removeAttrs re [ "SharedModules" ] // lib.optionalAttrs (re ? SharedModules) gen;
    in lib.mapAttrs (k: v: v // {
      allWithout = exc: { imports = map (x: final.${k}.${x}) (lib.filter (x: lib.all (y: x != y) exc) (lib.attrNames v)); };
      all = final.${k}.allWithout [];
    } // lib.optionalAttrs (v ? default) {
      defaultWithout = v.default;
      default = final.${k}.defaultWithout [];
    }) r // {
      inherit modulesPath;
    };
  in final;

  genModules = self'.fmway.genModules' [ "nixosModules" "nixDarwinModules" "homeManagerModules" ];
}
