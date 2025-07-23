{ self', lib, allFunc ? self'.fmway, ... }: let
  inherit (builtins)
    length
    head
    isPath
    typeOf
    attrNames
    tail
    all
    isAttrs
    filter
    foldl'
  ;
  inherit (lib)
    recursiveUpdate
    splitString
    take
    last
    optionals
    getAttrFromPath
  ;

  inherit (self'.fmway)
    tree-path
    excludeItems
    hasPrefix'
    doImport
    matchers
    removePrefix'
    removeExtension
  ;

  getAlias = alias: path: let
    filtered = filter (x: x.match.isMatchedIn path && x ? alias) alias;
  in if length filtered >= 1 then (last filtered).alias else null; 

  getMatcher = matchers: path: let
    filtered = filter (x: x.isMatchedIn path) matchers;
  in if length filtered >= 1 then last filtered else null;

  toImport = self: super: root: includes: variables: alias: get: 
  if isPath self then
    let
      matcher = getMatcher includes self;
      aliased = getAlias alias self;
      res = 
        if ! isNull matcher then
          matcher.read self ({
            inherit root super;
            self = getAttrFromPath get root;
          } // variables)
        else throw "error boss";
    in if isNull aliased then res else aliased res
  else if ! isAttrs self then
    self
  else let
    var = allFunc // variables // (
      if self ? ".var" then
        toImport self.".var" (getAttrFromPath get root) root includes variables alias (get ++ [".var"])
      else {}
    );
    ali = (
      if self ? ".alias" then
        doImport self.".alias" (allFunc // var)
      else []
    ) ++ alias;
    obj = excludeItems [ ".var" ".alias" ] self;
    result = foldl' (acc: name: let
      val = obj.${name};
      isDefault = name == "default" && isPath val;
      gett = if isDefault then get else get ++ [name];
      sup = if isDefault then super else getAttrFromPath get root;
      res = toImport val ({ inherit super; } // sup) root includes var ali gett;
    in recursiveUpdate acc (if isDefault then res else { "${name}" = res; })) {} (attrNames obj);
  in result;

  treeImport' = { enable ? true, folder, variables ? {}, depth ? 1, max ? 0, excludes ? [], includes ? [] }: let
    includess = includes ++
      optionals (all (x: x._type != "matcher-by-nix") includes) [ matchers.nix ];
    # ext = [ "nix" ] ++ (getExt includes);
    ext = matchers.getExt includess;
    toObj = arr: path:
      if length arr < 1 then
        path
      else let
        first = if length arr == 1 then removeExtension ext (head arr) else head arr;
        res = toObj (tail arr) path;
      in 
      if hasPrefix' "__" first then {
        ".var" = {
          "${removePrefix' "__" first}" = res;
        };
      } else { 
        "${first}" = res;
      };

    lists = tree-path { dir = folder; prefix = ""; };

    filteredByMax =
      if max <= 0 then
        lists
      else filter (x: let
        res = splitString "/" x;
        is-a-var = lib.any (x: hasPrefix' "__" x) (lib.genList (x: lib.elemAt res x) max);
        less-than-max = lib.length res <= max;
      in is-a-var || less-than-max) lists;

    filteredByDepth = filter (x: let
      split' = let
        res = splitString "/" x;
      in if last res == "default.nix" then take (length res - 1) res else res;
    in length split' >= depth) filteredByMax;
    
    filteredByExcludes = filter (x: ! lib.any (y: let path = toString y; in
      if isNull (lib.match "^/.*" path) then
        (hasPrefix' path x)
      else
        ("${folder}/${x}" == path)
    ) excludes) filteredByDepth;

    filteredByIncludes = filter (path: let
      filtered = filter (match:
        match.isMatchedIn path) includess;
    in
      length filtered >= 1) filteredByExcludes;

    res = foldl' (acc: curr: let
      split' = splitString "/" curr;
      path = folder + "/${curr}";
    in recursiveUpdate acc (toObj split' path)) {} filteredByIncludes;
    result = toImport res null result includess variables [] [];
  # in toImport res null res variables [];
  in if enable then result else {};

  treeImport = obj: if isPath obj then
    treeImport { folder = obj; }
  else if isAttrs obj then
    if obj ? folder then
      excludeItems ["__functor"] (treeImport' obj)
    else
      recursiveUpdate obj { __functor = self: args: recursiveUpdate (excludeItems ["__functor"] self) (treeImport args); }
  else throw "treeImport only support path and attrs, not ${typeOf obj}";

in treeImport
