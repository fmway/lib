{ self', lib, ... }: let
  inherit (builtins)
    foldl'
    isPath
  ;
  inherit (lib)
    path
    throwIfNot
  ;
  inherit (self'.fmway)
    getNixs
    getDefaultNixs
    getNixsWithDefault
    excludeItems
  ;
in rec {
  # generate array for imports keyword using getNixs
  genImports' = folder:
    throwIfNot (isPath folder)
      "genImports' required argument with type path"
  (excludes:
  let
    list = getNixs folder;
    excluded = excludeItems excludes list;
  in foldl' (acc: curr: [
    (path.append folder curr)
  ] ++ acc) [] excluded);

  genImports = folder:
    throwIfNot (isPath folder)
      "genImports required argument with type path"
    genImports' folder [];

  # generate array for imports keyword using getDefaultNixs
  genDefaultImports' = folder: 
    throwIfNot (isPath folder)
      "genDefaultImports' required argument with type path"
  (excludes: let
    list = getDefaultNixs folder;
    excluded = excludeItems excludes list;
  in foldl' (acc: curr: [
    (path.append folder curr)
  ] ++ acc) [] excluded);

  genDefaultImports = folder:
    throwIfNot (isPath folder)
      "genDefaultImports required argument with type path"
    genDefaultImports' folder [];

  # generate array for imports keyword using getNixsWithDefault
  genImportsWithDefault' = folder: 
    throwIfNot (isPath folder)
      "genImportsWithDefault required argument with type path"
  (excludes: let
    list = getNixsWithDefault folder;
    excluded = excludeItems excludes list;
  in foldl' (acc: curr: [
    (path.append folder curr)
  ] ++ acc) [] excluded);

  genImportsWithDefault = folder:
    throwIfNot (isPath folder)
      "genImportsWithDefault required argument with type path"
    genImportsWithDefault' folder [];
}
