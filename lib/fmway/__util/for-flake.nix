{ lib, self', ... }: let

  genModules' = shareds: moduleDir: args: let
    modulesPath = builtins.toPath moduleDir;
    listDir = attrNames (filterAttrs (_: v: v == "directory") (builtins.readDir modulesPath));
    re = listToAttrs (map (x: let
      scope = "${camelize x}Modules";
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
            r = withAllModules: inc: dontEmptyAllModules: let
              allModules = map (x: final.${scope}.${x}) (filter (x: x != module) inc);
              args' = optionalAttrs (scope != "SharedModules" && withAllModules) {
                allModules = lib.optionals dontEmptyAllModules allModules; 
              } // { inherit _file; } // args;
            in if isTree then { config, pkgs ? {}, lib, osConfig ? {}, specialArgs ? {}, ... } @ v: treeImport { _file = path; } {
              folder = path;
              depth = 0;
              variables = args' // v // specialArgs // { inherit config pkgs lib osConfig; superLib = args'.lib or {}; };
            } else withImport' _file args';
          in if module == "default" then r true else r false [] false;
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
    in mapAttrs (k: v: let
      moduleDefault = v.default (attrNames (removeAttrs v [ "default" ]));
      allModules = attrNames v;
      getModule = x: if x == "default" then
        moduleDefault false
      else final.${k}.${x};
      filterExc = exc: filter (x: all (y: x != y) exc) allModules;
    in v // {
      all = final.${k}.without [];
      without = exc: { imports = map getModule (filterExc exc); };
      within = inc: { imports = map getModule inc; };
    } // optionalAttrs (v ? default) {
      defaultWithin = lib.flip v.default true;
      defaultWithout  = exc: final.${k}.defaultWithin (filterExc exc);
      default = moduleDefault true;
    }) r // {
      inherit modulesPath;
    };
  in final;

  genModules = {
    _specialKeywords = [ "defaultWithout" "defaultWithin" "all" "within" "without" ];
    sharedModules = [ "nixosModules" "nixDarwinModules" "homeManagerModules" ];
    __functor = self: args: if isList args then self // {
      sharedModules = args;
    } else if (isString args || isPath args) && pathIsDirectory args then self // {
      dir = args;
    } else if isAttrs args then
      genModules' self.sharedModules self.dir args
    else throw "(genModules): unknown type ${builtins.typeOf args}";
  };

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
    pathExists
    isString
    isAttrs
    isList
    isPath
  ;
  
  inherit (self'.fmway)
    camelize
    withImport'
    treeImport
    flat
  ;
in {
  genModules' = lib.warn "genModules' deprecated, use genModules instead" genModules';
  inherit genModules;
}
