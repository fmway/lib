{ self', lib, ... }: let
  inherit (builtins)
    filter
    isPath
  ;
  inherit (self'.fmway)
    tree-path
    hasSuffix'
    excludePrefix
  ;

  inherit (lib)
    throwIfNot
  ;

in rec {
  genTreeImports' = folder: 
    throwIfNot (isPath folder)
      "genTreeImports' required argument with type path"
  (excludes: let
    list = tree-path { dir = folder; prefix = ""; };
    filtered = filter (x: hasSuffix' ".nix" (toString x)) list;
    excluded = excludePrefix excludes filtered;
  in map (x: folder + "/${x}") excluded);
  
  genTreeImports = folder:
    throwIfNot (isPath folder)
      "genTreeImports required argument with type path"
    genTreeImports' folder [];
}
