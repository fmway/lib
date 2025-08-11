{ lib, ... }: let
  inherit (builtins)
    replaceStrings
    isAttrs
    attrNames
    foldl'
    head
    tail
    isList
    filter
    any
    length
    isString
    genList
    removeAttrs
    elemAt
    split
    ;
  inherit (lib)
    hasSuffix
    splitString
    hasPrefix
    fileContents
    listToAttrs
    flatten
    removePrefix
    removeSuffix
    reverseList
    imap1
    ;
  addIndent = with-first: indent: str:
    lib.concatStringsSep "\n" (
      imap1 (i: x:
        lib.optionalString ((i != 1 || with-first) && lib.trim x != "") indent + x
      ) (lib.splitString "\n" str)
    );

  doMatch = matches: str: res:
    if ! isList matches then
      doMatch [matches] str { index = 0; }
    else if matches == [] then
      { isMatch = false; data = null; index = -1; }
    else let
      r = builtins.match (head matches) str;
    in if isNull r then
      doMatch (tail matches) str (res // { index = res.index + 1; })
    else (res // { isMatch = true; data = r; })
  ;

  # FIXME
  listNeedFixed = [ "$" "{" "}" "." "(" ")" "[" "|" ];

  fixedInMatch = str:
    lib.foldl' (acc: curr: acc + (if lib.any (x: curr == x) listNeedFixed then "[${curr}]" else curr)) "" (lib.splitString "" str);

  # FIXME can't nested groups
  # ?: for no name
  # ?<..> for named
  reMatchGroup = /* regex */ "(^|.*[^[])([(]([?](:|<([^<>()]+)>))([^()]+)[)]|[(]([^()]+)[)])(.*)";

  fnMatch = str: let
    matched = builtins.match reMatchGroup str;
  in if isNull matched then
    null
  else let
    preB   = builtins.elemAt matched 0;
    prefix = builtins.elemAt matched 2; # null || ?: || ?<..>
    named  = builtins.elemAt matched 4; # string if prefix == ?<..>, else null
    body   = builtins.elemAt matched (if isNull prefix then 6 else 5);
    postB  = builtins.elemAt matched 7;
    getPreMatch = let
      r = fnMatch preB;
    in if lib.trim preB == "" || isNull r then { str = preB; data = []; } else r; 
    getPostMatch = let
      r = fnMatch postB;
    in if lib.trim postB == "" || isNull r then { str = postB; data = []; } else r;
  in {
    str = getPreMatch.str + "(${body})" + getPostMatch.str;
    data = getPreMatch.data ++ (if isString prefix && prefix != "?:" then [named] else [(isNull prefix)]) ++ getPostMatch.data;
  };

  # Experimental matching with groups support
  match2 = regex: str: let
    parseMatch = fnMatch regex;
    matched = builtins.match (if isNull parseMatch then regex else parseMatch.str) str;
  in
    if isNull matched then
      null
    else if isNull parseMatch then
      { groups = {}; data = matched; }
    else removeAttrs (foldl' (acc: curr: let
      m = elemAt matched acc.idx;
    in acc // {
      groups = acc.groups // lib.optionalAttrs (isString curr) { "${curr}" = m; };
      data = acc.data ++ lib.optionals (isString curr || (builtins.isBool curr && curr)) [m];
      idx = acc.idx + 1;
    }) { groups = {}; data = []; idx = 0; } parseMatch.data) [ "idx" ];
in {
  inherit match2;
  inherit removeSuffix removePrefix hasPrefix hasSuffix replaceStrings fixedInMatch;
  addIndent = addIndent true;
  addIndent'= addIndent false;
} // rec {
  toString = x:
    if isNull x then
      "null"
    else if builtins.isString x then
      x
    else if builtins.isBool x then
      if x then "true" else "false"
    else builtins.toString x;
  elem = fn: arrs:
    foldl' (acc: curr: if fn curr then curr else acc) null arrs;

  elem' = fn: arrs:
    (foldl' (acc: curr: {
      id = acc.id + 1;
      res = if fn curr then acc.id else acc.res;
    }) { id = 0; res = null; } arrs).res;

  elemAttrs = fn: attrs:
    foldl' (acc: curr: if fn curr attrs.${curr} then attrs.${curr} else acc) null (attrNames attrs);

  elemAttrs' = fn: attrs:
    foldl' (acc: curr: if fn curr attrs.${curr} then curr else acc) null (attrNames attrs);

  # foldAttrs :: (Any -> Any -> Any) -> Any -> AttrSet -> Any
  # different with lib.foldAttrs, this function is just a builtins.fold' but attrs
  foldAttrs = fn: init: target:
    foldl' (acc: x: fn acc target.${x}) init (attrNames target);

  # foldAttrs' :: (Any -> Any -> Any) -> Any -> AttrSet -> Any
  # ffoldAttrs with key value
  foldAttrs' = fn: init: target:
    foldl' (acc: x: fn acc x target.${x}) init (attrNames target);
  # match :: [String] -> String -> [Null | String] | Null
  # builtins.match but support list
  match  = matches: str: (match' matches str).data;

  # match :: [String] -> String -> [Null | String] | Null
  # for debugging
  match' = matches: str: doMatch matches str { index = 0; };

  # flat :: Elem -> [Elem]
  # convert any Elem except List to [Elem]
  flat = x:
    if isList x then x
    else [x];

  # uniqBy' :: (Elem -> String) -> [Any] -> [Any]
  uniqBy = fn: arr:
    foldl' (acc: e: if any (x: fn x == fn e) acc then
      acc
    else acc ++ [ e ]) [] arr;

  # uniqLastBy' :: (Elem -> String) -> [Any] -> [Any]
  uniqLastBy = fn: arr: let
    rev = reverseList arr;
  in reverseList (uniqBy fn rev);

  # firstChar :: String -> String
  firstChar = str:
    head (filter (x: x != "") (flatten (split "(.)" str)));
  
  # readEnv :: Path -> {String}
  readEnv = file: let
    parseEnv = str: let
      res = split "^([^# ][^= ]+)=(.*)$" str;
    in if isNull res || length res <= 1 then null else elemAt res 1; # key=value => [ key value ]
    no-empty = x: x != ""; # env with no value will be ignored
    listMaybeEnv = splitString "\n" (fileContents file);
    list = filter (x: !isNull x) (map parseEnv (filter no-empty listMaybeEnv));
  in listToAttrs (map (curr: {
    name = elemAt curr 0;
    value = elemAt curr 1;
  }) list); # Just to parse .env file to mapAttrs;

  # replaceStrings' :: AttrSet -> AttrSet -> String -> String
  replaceStrings' = var: { start ? "%(", end ? ")s" } @ prefix: str: let # %(var)s 
    names = attrNames var;
    from = map (x: "${start}${x}${end}") names; 
    to   = map (x: "${toString var.${x}}") names;
  in replaceStrings from to str;

  # basename :: String -> String
  basename = k: let
    bs = baseNameOf k;
    matched = builtins.match "^(.*)\\.(.*)$" bs;
  in if matched == null then bs else head matched;

  # getFilename :: (Path | String) -> String
  getFilename = path:
    baseNameOf (toString path);

  # hasFilename :: String -> (String | Path) -> Bool
  hasFilename = filename: target:
    if isList filename then
      let
        filtered = filter (x: hasFilename x target) filename;
      in if length filtered < 1 then
        false
      else true
    else let
      target-filename = getFilename target;
    in filename == target-filename;

  # hasSuffix' :: (String | [String]) -> (Path | String) -> Bool
  hasSuffix' = suffix: target:
  if isList suffix then
    let
      filtered = filter (x: hasSuffix' x target) suffix;
    in if length filtered < 1 then
      false
    else true
  else let
    targetStr = toString target;
  in hasSuffix suffix targetStr;

  # hasExtension :: (String | [String]) -> (Path | String) -> Bool
  hasExtension = ext: target: let
    exts = if isString ext then ext else map (x: ".${x}") ext;
  in hasSuffix' exts target;
  
  # hasPrefix' :: (String | [String]) -> (Path | String) -> Bool
  hasPrefix' = prefix: target:
  if isList prefix then
    let
      filtered = filter (x: hasPrefix' x target) prefix;
    in if length filtered < 1 then
      false
    else true
  else let
    targetStr = toString target;
  in hasPrefix prefix targetStr;

  # hasRegex :: (String | [String]) -> (Path | String) -> Bool
  hasRegex = regex: target:
  if isList regex then
    let
      filtered = filter (x: hasRegex x target) regex;
    in if length filtered < 1 then false else true
  else let
    targetStr = toString target;
    matched = builtins.match regex targetStr;
  in if isNull matched then false else true;

  # removePrefix' :: (String | [String]) -> (Path | String) -> String
  removePrefix' = prefix: target:
  if isList prefix then
    let
      filtered = filter (x: hasSuffix' x target) prefix;
    in if length filtered < 1 then
      target
    else removePrefix' (head filtered) target
  else let
    targetStr = toString target;
  in removePrefix prefix targetStr;

  # removeSuffix' :: (String | [String]) -> (Path | String) -> String
  removeSuffix' = suffix: target:
  if isList suffix then
    let
      filtered = filter (x: hasSuffix' x target) suffix;
    in if length filtered < 1 then
      target
    else removeSuffix' (head filtered) target
  else let
    targetStr = toString target;
  in removeSuffix suffix targetStr;

  # removeExtension :: (String | [String]) -> (Path | String) -> String
  removeExtension = ext: target: let
    exts =
      if isString ext then
        ".${ext}"
      else
        map (x: ".${x}") ext;
  in removeSuffix' exts target;

  # stringMultiply :: String -> int -> String
  stringMultiply = str: count:
    foldl' (acc: _: str + acc) "" (genList (x: x) count);

  # excludeList :: [Any] -> [Any] -> [Any]
  excludeList = excludes: inputs: let
    fixed = map (x: toString x) excludes;
    filtering = x: ! any (y: x == y) fixed;
  in filter filtering inputs;

  # excludeAttr :: [Any] -> AttrSet -> AttrSet
  excludeAttr = lib.flip removeAttrs;

  # excludeItems :: [Any] -> (AttrSet -> AttrSet | [Any] -> [Any])
  excludeItems = excludes: inputs:
  if isList inputs then
    excludeList excludes inputs
  else if isAttrs inputs then
    excludeAttr excludes inputs
  else throw "Exclude items only support list and AttrSet :(";

  # excludePrefix :: [String] -> (String | [String]) -> [String]
  excludePrefix = excludes: prefixs: let
    fixed = map (x: toString x) excludes;
    filtering = x: ! any (y: hasPrefix' y x) fixed;
  in filter filtering prefixs;

  # excludeSuffix :: [String] -> (String | [String]) -> [String]
  excludeSuffix = excludes: suffixs: let
    fixed = map (x: toString x) excludes;
    filtering = x: ! any (y: hasSuffix' y x) fixed;
  in filter filtering suffixs;

  printPathv1 = config: x: let
    user = config.users.users.${x} or {};
    home-manager = config.home-manager.users.${x} or {};
    toString = arr: builtins.concatStringsSep ":" arr;
  in toString (
    # home-manager level
    (home-manager.home.sessionPath or [])
  ++lib.optionals (user != {}) [ 
    "${user.home}/.local/share/flatpak/exports" # flatpak user
    "${user.home}/.nix-profile/bin" # profile level
  ] ++ [
    "/var/lib/flatpak/exports" # flatpak
    "/etc/profiles/per-user/${user.name}/bin" # user level
    "/run/current-system/sw/bin" # system level
  ]);
  printPathv2 = config: user:
    lib.makeBinPath (
       config.environment.systemPackages # system packages
    ++ config.users.users.${user}.packages # user packages
    ++ lib.optionals (config ? home-manager && config.home-manager.users ? ${user}) config.home-manager.users.${user}.home.packages # home-manager packages
    );

  toCamelCase = str: let
    match = builtins.match "^(.*)[-_](.)(.*)$" str;
    cameled = imap1 (i: v: if i == 2 then
      lib.toUpper v
    else v) match;
  in if isNull match then
    str
  else toCamelCase (lib.concatStrings cameled);

  /*
    mkResolvePath :: (String | Path) -> String -> (Path | String)
    functions for resolve path by string, return itself if it doesn't seem like paths (./ , ../ or /). for example:
    ```nix
    let
      resolvePath = mkResolvePath ./.;
    in resolvePath "./mypath.json" # => ./path.json 
    ```
   */
  mkResolvePath = cwd: str: let
    matched = builtins.match "^([.]{1,2}/|/)(.+)$" str;
  in if isNull matched then
    str
  else let
    prefix = lib.head matched;
    ctx = lib.last matched;
  in if prefix == "./" then
    cwd + "/${ctx}"
  else if prefix == "../" then
    cwd + "/${ctx}"
  else /. + "/${ctx}";
}
