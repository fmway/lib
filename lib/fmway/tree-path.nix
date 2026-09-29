{ lib, ... }: let
  inherit (builtins)
    isAttrs
    isString
    isList
    elemAt
    attrNames
    readDir
  ;

  inherit (lib)
    flatten
  ;

  tree-path = var: let
    # if var not an object, dir = x, prefix = x; otherwise dir = x.dir, prefix x.prefix / x.dir
    dir = if isAttrs var && var ? dir then 
        var.dir 
      else var;
    prefix = if isAttrs var && var ? prefix && isString var.prefix then
        var.prefix 
      else if isList dir then elemAt dir 0 else dir;

    toList = { attr, prefix, base ? ./. }: 
      map (x: { 
        path = base + ("/" + x); 
        prefix = if prefix == "" then x else prefix + ("/" + x);
        type = attr.${x};
      }) (attrNames attr);

    condition = val: 
      let
        inherit (val) type path prefix;
      in
      if type == "directory" then
        all { dir = path; prefix = prefix; }
      else
        prefix;

    all = { dir, prefix }: map condition (toList {
      attr = readDir dir;
      prefix = prefix;
      base = dir;
    });
  in if isList dir then flatten (map (x: tree-path { dir = x; inherit prefix; }) dir) 
    else flatten (all { dir = dir; prefix = prefix; });
in {
  __functor = self: self.v2;
  v1 = tree-path;
  v2 = var: let
    dir = builtins.toPath (var.dir or var);
    s = builtins.stringLength dir + 1;
    p'= if var.prefix or "" == "" then [] else [var.prefix];
    files = lib.filesystem.listFilesRecursive dir;
  in if builtins.isAttrs var then
      map (p: builtins.concatStringsSep "/" (p' ++ [(builtins.substring s (-1) p)])) files
    else map (p: /. + p) files;
}
