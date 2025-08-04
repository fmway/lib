{ lib, self', ... }: let

  genModules' = shareds: moduleDir: args: let
    modulesPath = builtins.toPath moduleDir;
    listDir = attrNames (filterAttrs (_: v: v == "directory") (builtins.readDir modulesPath));
    re = listToAttrs (map (x: let
      scope = "${toCamelCase x}Modules";
      dir = "${modulesPath}/${x}";
    in {
      name = scope;
      value = let
        filterModule = attrNames (filterAttrs (name: type:
          (! isNull (builtins.match ".+[.]nix" name) && type == "regular") ||
          (
            type == "directory" &&
            (
              hasSuffix "-" name ||
              pathIsRegularFile "${dir}/${name}/default.nix"
            )
          )
        ) (builtins.readDir dir));
        res = args: listToAttrs (map (name: let
          path = /. + "${dir}/${name}";
          isDirectory = pathIsDirectory path;
          _file = path + optionalString isDirectory "/default.nix";
          isTree = isDirectory && hasSuffix "-" path;
          module =
            let
              r = removeSuffix ".nix" name;
              rr= removeSuffix "-" name;
            in if isTree then rr else if !isDirectory then r else name;
        in {
          name = module;
          value = let
            r = exc: let
              args' = optionalAttrs (scope != "SharedModules") {
                allModules = map (x: final.${scope}.${x}) (
                  filter (x:
                    x != module &&
                    all (y: x != y) (exc ++ [ "defaultWithout" "default" "all" "allWithout" ])
                  ) (attrNames final.${scope}));
              } // { inherit _file; } // args;
            in if isTree then { config, pkgs ? {}, lib, osConfig ? {}, specialArgs ? {}, ... } @ v: treeImport { _file = path; } {
              folder = path;
              depth = 0;
              variables = args' // v // specialArgs;
            } else withImport' _file args';
          in if module == "default" then r else r [];
        }) filterModule);
      in if scope == "SharedModules" then
        res
      else res (final // args);
    }) listDir);
    gen = listToAttrs (map (name: {
      inherit name;
      value = re.SharedModules (final // args // { inherit name; }) // (re.${name} or {});
    }) shareds);
    final = let
      r = removeAttrs re [ "SharedModules" ] // optionalAttrs (re ? SharedModules) gen;
    in mapAttrs (k: v: v // {
      allWithout = exc: { imports = map (x: final.${k}.${x}) (filter (x: all (y: x != y) exc) (attrNames v)); };
      all = final.${k}.allWithout [];
    } // optionalAttrs (v ? default) {
      defaultWithout = v.default;
      default = final.${k}.defaultWithout [];
    }) r // {
      inherit modulesPath;
    };
  in final;

  inherit (lib)
    mapAttrs
    all
    listToAttrs
    filter
    attrNames
    optionalAttrs
    optionalString
    removeSuffix
    hasSuffix
    filterAttrs
    pathIsRegularFile
    pathIsDirectory
  ;
  
  inherit (self'.fmway)
    toCamelCase
    withImport'
    treeImport
  ;
in {
  inherit genModules';
  genModules = genModules' [ "nixosModules" "nixDarwinModules" "homeManagerModules" ];
}
