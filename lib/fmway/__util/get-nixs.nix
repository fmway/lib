{ self', lib, ... }: let
 inherit (builtins)
  pathExists
  readDir
  isPath
 ;
 inherit (lib)
  path
  throwIfNot
  filterAttrs
  mapAttrsToList
 ;

 inherit (self'.fmway)
  hasSuffix'
 ;
in rec {
  # get all directory that have default.nix
  getDefaultNixs = folder:
    throwIfNot (isPath folder)
      "getDefaultNixs required argument with type path"
  (let
    filtered = key: value:
      value == "directory" &&
      pathExists (path.append folder "${key}/default.nix");
    dir = readDir folder;
  in mapAttrsToList (name: value: "${name}") (filterAttrs filtered dir));
  
  # get all <file>.nix except default.nix
  getNixs = folder:
    throwIfNot (isPath folder)
      "getNixs required argument with type path"
  (let
    filtered = key: value:
      value == "regular" &&
      hasSuffix' ".nix" key && key != "default.nix";
    dir = readDir folder;
  in mapAttrsToList (name: value: "${name}") (filterAttrs filtered dir));

  # get all <file>.nix except default.nix also all directory that have default.nix
  getNixsWithDefault = folder:
    throwIfNot (isPath folder)
      "getNixsWithDefault required argument with type path"
  (getNixs folder) ++ (getDefaultNixs folder);
}
