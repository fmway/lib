{ self', lib, ... }: let
  inherit (builtins)
    functionArgs
    attrNames
    isFunction
    filter
    hasAttr
  ;
  inherit (lib)
    listToAttrs
  ;

  # parse args only required to function
  getRequiredArgs = function: variables: let
    args = functionArgs function;
    argNames = filter (x: ! args.${x}) (attrNames args);
    result = listToAttrs (map (name: {
      inherit name;
      value = if hasAttr name variables then variables.${name}
        else if hasAttr name self' then self'.${name}
        else if hasAttr name self'.fmway then self'.fmway.${name}
        else throw "(getRequiredArgs) argument ${name} not found :(";
    }) argNames);
  in result;
  withImports = { ... } @ vars: arr: map (lib.flip (withImport' true) vars) (lib.flatten [arr]);

  withImport = withImport' false;

  withImport' = exposePath: x: { ... } @ vars: let
    impor = x: path:
      if lib.isFunction x && (lib.functionArgs x) ? internal then
        x ({ internal = true; } // vars)
      else if exposePath && ! isNull path then
        path
      else x;
  in if (lib.isString x || lib.isPath x) && lib.pathExists x then
      impor (import x) x
    else
      impor x null;
in {
  doImport = path: variables: let
    imported = import path;
  in if isFunction imported && !isNull variables then
    imported (getRequiredArgs imported variables)
  else imported;

  inherit withImport withImports;
  withImport' = withImport' true;
}
