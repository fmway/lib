{ self', lib, ... }: let
  inherit (builtins)
    isPath
    isAttrs
    isList
    isString
    pathExists
    foldl'
    length
  ;
  inherit (lib)
    recursiveUpdate
    hasPrefix
    filter
    any
  ;

  inherit (self'.fmway)
    getNixsWithDefault
    getDefaultNixs
    getNixs
    basename
    excludeItems
    doImport
  ;

   templateSingleImport = { folder, variables, list, excludes, initial }: let
    filtered =
      if length excludes == 0 then
        list
      else filter (x: any (y: let path = toString y; in
      if isNull (lib.match "^/.*" path) then
        (hasPrefix path x)
      else
        ("${folder}/${x}" == path)
    ) excludes) list;
  in foldl' (acc: curr: let
    var =
      if isNull variables then
        variables
      else self'.fmway // variables;
    path = folder + "/${curr}";
  in {
    "${basename curr}" = doImport path var;
  } // acc) initial filtered;

  # generate object for single import for all <file>.nix exclude default.nix
  customImport' = var: let
    folder = if isPath var then var else var.folder;
    excludes = if isAttrs var && var ? excludes && isList var.excludes then var.excludes else [];
    variables = if isAttrs var && var ? variables && isAttrs var.variables then var.variables else if isPath var then null else {};
  in if isList folder then
    foldl' (acc: curr: recursiveUpdate acc (customImport' {
      folder = curr;
      inherit excludes variables;
    })) {} folder 
  else let
    list = getNixs folder;
  in templateSingleImport { inherit folder variables list excludes; initial = {}; };

  # generate object for single import for all directory that have default.nix
  customDefaultImport' = var: let
    folder = if isPath var then var else var.folder;
    variables = if isAttrs var && var ? variables && isAttrs var.variables then var.variables else if isPath var then null else {};
    excludes = if isAttrs var && var ? excludes && isList var.excludes then var.excludes else [];
  in if isList folder then
    foldl' (acc: curr: recursiveUpdate acc (customDefaultImport' {
      folder = curr;
      inherit excludes variables;
    })) {} folder 
  else let
    list = getDefaultNixs folder;
  in templateSingleImport { inherit folder variables list excludes; initial = {}; };

  # generate object for single import for all <file>.nix except default.nix also all directory that have default.nix
  customImportWithDefault' = var: let
    folder = if isPath var then var else var.folder;
    variables = if isAttrs var && var ? variables && isAttrs var.variables then var.variables else if isPath var then null else {};
    excludes = if isAttrs var && var ? excludes && isList var.excludes then var.excludes else [];
  in if isList folder then
    foldl' (acc: curr: recursiveUpdate acc (customImportWithDefault' {
      folder = curr;
      inherit excludes variables;
    })) {} folder 
  else let
    list = getNixsWithDefault folder;
  in templateSingleImport { inherit folder variables list excludes; initial = {}; };

in rec {

  customImport = var: if (var ? folder) || isPath var || (isString var && pathExists var) then
    excludeItems ["__functor"] (customImport' var)
  else
    recursiveUpdate var { __functor = self: args: recursiveUpdate (excludeItems ["__functor"] self) (customImport args); };
  
  customDefaultImport = var: if (var ? folder) || isPath var || (isString var && pathExists var) then
    excludeItems ["__functor"] (customDefaultImport' var)
  else
    recursiveUpdate var { __functor = self: args: recursiveUpdate (excludeItems ["__functor"] self) (customDefaultImport args); };

  customImportWithDefault = var: if (var ? folder) || isPath var || (isString var && pathExists var) then
    excludeItems ["__functor"] (customImportWithDefault' var)
  else
    recursiveUpdate var { __functor = self: args: recursiveUpdate (excludeItems ["__functor"] self) (customImportWithDefault args); };
}
