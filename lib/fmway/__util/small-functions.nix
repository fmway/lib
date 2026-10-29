{ lib, ... }: let
  inherit (builtins)
    isAttrs
    attrNames
    foldl'
    head
    isList
    filter
    any
    isString
    genList
    elemAt
    ;
  inherit (lib)
    listToAttrs
    reverseList
    imap1
    findFirst
    flip
    ;

  genDoc = pad: x: let
    doc = x.__doc or [];
  in if doc != [] then "\n" + lib.concatMapStringsSep "\n" (x: stringMultiply " " pad + "# ${toString x}") (flat doc) + "\n" else "";

  removeDoc = v:
    if isAttrs v then removeAttrs v [ "__doc" "__oneliner" ] else v;

  # Like recursiveUpdate but support auto-append list
  deepMerge = lhs: rhs:
    lhs // rhs // (builtins.mapAttrs (rName: rValue:
      let lValue = lhs.${rName} or null; in
      if builtins.isAttrs lValue && builtins.isAttrs rValue then
        deepMerge lValue rValue
      else if builtins.isList lValue && builtins.isList rValue then
        lValue ++ rValue
      else rValue
    ) rhs);

  
  # deepMergeList :: [Attrs] -> Attrs
  deepMergeList =
    builtins.zipAttrsWith (_: v: let
      f = builtins.head v;
    in
      if builtins.length v == 1 then
        f
      else if builtins.isAttrs f then
        deepMergeList v
      else if builtins.isList f then
        builtins.concatLists v
      else
        lib.last v
    );


  addIndent = with-first: indent: str:
    lib.concatStringsSep "\n" (
      imap1 (i: x:
        lib.optionalString ((i != 1 || with-first) && lib.trim x != "") indent + x
      ) (lib.splitString "\n" str)
    );

  # FIXME
  listNeedFixed = [ "$" "{" "}" "." "(" ")" "[" "|" ];

  fixedInMatch = str:
    lib.foldl' (acc: curr: acc + (if lib.any (x: curr == x) listNeedFixed then "[${curr}]" else curr)) "" (lib.splitString "" str);

  transformerString = name: re: fn: let
    result = x: let
      m = builtins.match re x;
      r = lib.concatStrings (imap1 fn m);
    in if isString x then
      if isNull m then
        x
      else result r
    else if isAttrs x then
      lib.mapAttrs' (k: v: let
        key = result k;
        value = if lib.isAttrs v then result v else v;
      in lib.nameValuePair key value) x
    else throw "(${name}): unknown x, allowed string or attrs, found ${builtins.typeOf x}";
  in result;

  isFunction = x: x ? __functor || builtins.isFunction x;

  listToFunction' = loose: fns: let
    f = if loose then isFunction else builtins.isFunction;
    allFunc = builtins.all f fns;
  in if allFunc then x: listToFunction' loose (map (fn: fn x) fns) else fns;

  stringification = include-drv: x: let
    type = builtins.typeOf x;
    switch = rec {
      null = "null";
      bool = if x then "true" else "false";
      float = toString x;
      path = float;
      int = float;
      string = x;
      list = map (stringification include-drv) x;
      set = if include-drv && lib.isDerivation x then float else lib.mapAttrs (_: stringification include-drv) x;
      lambda = "<function>";
    };
  in switch.${type};

  # stringMultiply :: String -> int -> String
  stringMultiply = str: count:
    foldl' (acc: _: str + acc) "" (genList (x: x) count);

  # flat :: Elem -> [Elem]
  # convert any Elem except List to [Elem]
  flat = x:
    if isList x then x
    else [x];

  toString2 = x:
    if isNull x then
      "null"
    else if builtins.isString x then
      x
    else if builtins.isBool x then
      if x then "true" else "false"
    else toString x;
in {
  inherit
    deepMerge deepMergeList
    fixedInMatch stringMultiply flat
  ;
  addIndent = addIndent true;
  addIndent'= addIndent false;
  stringification = {
    __functor = _: stringification false;
    include-drv = stringification true;
  };

  # Might be removed, i forgot what the usecase is for
  listToFunction = {
    # listToFunction :: [Function] -> Any -> ...
    # listToFunction, a function to make list of functions that behaves like a function
    # e.g:
    # fn = listToFunction (map (x: y: z: x + y) [ 1 2 3 ])
    # fn 5 1 # => [ 7 8 9 ]
    __functor = _: listToFunction' false;

    # listToFunction.loose :: [FunctionLike] -> Any
    # like listToFunction.v1 but support __functor detection
    loose = listToFunction' true;
  };

  replaceStrings = {
    __functor = builtins.replaceStrings;
    
    # replaceStrings.v2 :: AttrSet -> String -> String
    # replaceStrings.v2 = replaceStrings + regex
    v2 = {
      # default = %(var)s
      __functor = self: var:
        self.custom "%[(]([^)]+)[)]s" (m:
          lib.select (builtins.elemAt m 0) var);
      custom = regex: fn: str:
        lib.concatMapStrings (token:
          if isList token then
            toString2 (fn token)
          else token
        ) (builtins.split regex str);
    };
  };
} // rec {
  toString = toString2;
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
  # foldAttrs with key value
  foldAttrs' = fn: init: target:
    foldl' (acc: x: fn acc x target.${x}) init (attrNames target);

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
    if str == "" then "" else builtins.substring 0 1 str;
  
  # readEnv :: Path -> {String}
  readEnv = file:
    assert lib.pathIsRegularFile file;
    let
      vars = builtins.concatMap (x: [("$" + x) "\${${x}}"]) (attrNames s);
      values = builtins.concatMap (x: [x x]) (builtins.attrValues s);
      fix = builtins.replaceStrings vars values;
      s = listToAttrs (builtins.concatMap (t:
        if isList t then [{
          name = builtins.elemAt t 1;
          value = let
            v = builtins.elemAt t 3;
            v' = if isNull v then
                builtins.elemAt t 2
              else v;
          in fix v';
        }]
        else []
      ) (builtins.split "(^|\n)([^#=][^= ]*)=(\"([^\"\n]*)\"|[^\n]*)" (builtins.readFile file)));
    in s; # Just to parse .env file to mapAttrs;

  # basename :: String -> String
  basename = k: let
    bs = getFilename k;
    matched = builtins.match "^(.*)\\.(.*)$" bs;
  in if matched == null then bs else head matched;

  # getFilename :: (Path | String) -> String
  getFilename = path:
    assert isString path || lib.types.path.check path;
    baseNameOf (toString path);

  # hasFilename :: String -> (String | Path) -> Bool
  hasFilename = filename: target:
    any (x: getFilename x == filename) (flat target);

  hasSuffix = lib.fix (s: {
    __functor = self: self.v2;
    v1 = lib.hasSuffix;

    # hasSuffix.v2 :: (String | [String]) -> (Path | String) -> Bool
    v2 = suffix: target:
      assert isString target || lib.types.path.check target; let
        t = toString target;
      in any (flip s.v1 t) (flat suffix);
  });

  # hasExtension :: (String | [String]) -> (Path | String) -> Bool
  hasExtension = ext: target:
    assert isString target || lib.types.path.check target;
    let t = toString target; in
    any (x: hasSuffix.v1 ".${x}" t) (flat ext);
  
  hasPrefix = lib.fix (s: {
    v1 = lib.hasPrefix;

    # hasPrefix.v2 :: (String | [String]) -> (Path | String) -> Bool
    v2 = prefix: target:
      assert isString target || lib.types.path.check target; let
        t = toString target;
      in any (flip s.v1 t) (flat prefix);

    __functor = self: self.v2;
  });

  # hasRegex :: (String | [String]) -> (Path | String) -> Bool
  hasRegex = regex: target:
    assert isString target || lib.types.path.check target;
    any (re: !isNull (builtins.match re target)) (flat regex);

  removePrefix = lib.fix (s: {
    v1 = lib.removePrefix;

    # removePrefix.v2 :: (String | [String]) -> (Path | String | [String|Path]) -> String|[String]
    v2 = prefix: target:
      if isList target then
        map (s.v2 prefix) target
      else
        assert isString target || lib.types.path.check target;
        let t = toString target; in
          s.v1 (findFirst (flip hasPrefix.v1 t) "" (flat prefix)) t;

    __functor = self: self.v2;
  });

  removeSuffix = lib.fix (s: {
    v1 = lib.removeSuffix;

    # removeSuffix.v2 :: (String | [String]) -> (Path | String | [String|Path]) -> String|[String]
    v2 = suffix: target:
      if isList target then
        map (s.v2 suffix) target
      else
        assert isString target || lib.types.path.check target;
        let t = toString target; in
          s.v1 (findFirst (flip hasSuffix.v1 t) "" (flat suffix)) t;

    __functor = self: self.v2;
  });

  # removeExtension :: (String | [String]) -> (Path | String | [String|Path]) -> String|[String]
  removeExtension = ext: target:
    assert isString target || lib.types.path.check target;
    removeSuffix.v2 (map (x: ".${x}") (flat ext)) target;

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
    filtering = x: ! any (y: hasPrefix.v2 y x) fixed;
  in filter filtering prefixs;

  # excludeSuffix :: [String] -> (String | [String]) -> [String]
  excludeSuffix = excludes: suffixs: let
    fixed = map (x: toString x) excludes;
    filtering = x: ! any (y: hasSuffix.v2 y x) fixed;
  in filter filtering suffixs;

  printPathv1 = config: x: let
    user = config.users.users.${x} or {};
    home-manager = config.home-manager.users.${x} or {};
  in builtins.concatStringsSep ":" (
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

  camelize =
    transformerString "camelize" # regex
    "^(.*)[-_ ]([^-_ ])(.*)$" # FIXME
    (i: v:
      if i == 2 then
        lib.toUpper v
      else v);

  kebabize =
    transformerString "kebabize" # regex
    "^(.*)([A-Z_ ])([^A-Z_ ]+)(.*)$" # FIXME
    (i: v:
      if i == 2 then
        "-" + lib.optionalString (v != "_" && v != " ") (lib.toLower v)
      else v);

  snakeize =
    transformerString "snakeize" # regex
    "^(.*)([-A-Z ])([^-A-Z ]+)(.*)$" # FIXME
    (i: v:
      if i == 2 then
        "_" + lib.optionalString (v != "-" && v != " ") (lib.toLower v)
      else v);

  /*
    resolvePath :: (String | Path) -> Any -> Any
    functions for resolve path by string, return itself if it doesn't seem like paths (./ , ../ or /). for example:
    ```nix
      resolvePath "/home/user" "./path.json" # => "/home/user/path.json"
    ```
   */
  resolvePath = {
    __functor = self: cwd: x: let
      t = builtins.typeOf x;
      r = {
        set    = builtins.mapAttrs (_: self cwd) x;
        list   = map (self cwd) x;
        string = self.map (p: builtins.toPath "${cwd}/${p}") x;
      };
    in r.${t} or x;

    /*
       resolvePath.map :: (String -> Any) -> String -> Any
       e.g:
       ```nix
        resolvePath.map (path: "real-${path}") "./path, ../woy, nothing" => "real-./path, real-../woy, nothing"
       ```
    */
    map = mapf: str: let
      tokens = builtins.split "(''([^']|'[^'])*''|\"([^\"\\\\]|\\\\.)*\"|\\.+/[a-zA-Z0-9_./+-]+)" str;
    in lib.concatMapStrings (token:
      if isList token then let
        matchStr = elemAt token 0;
        isRelativePath = builtins.substring 0 2 matchStr == "./" || builtins.substring 0 3 matchStr == "../";
      in
        if isRelativePath then
          mapf matchStr
        else matchStr
      else token
    ) tokens;
  };

  /* do :: MaybeFn -> Any -> Any */
  do = x: args: if builtins.isFunction x then x args else x;

  genNix = lib.fix (s: {
    mkScript = pkgs: x:
      pkgs.writeScript "gen-nix.sh" /* bash */ ''
        #!${lib.getExe pkgs.bash}

        output="''${1:-/dev/stdout}"
        cat ${pkgs.writeText "source.nix" (s x)} > $output
      '';
    __functor = _: genNix' 0 false;
    oneliner = genNix' 0 true;
  });
    
  genNix' = pad: oneliner': x': let
    x = x'.__value or (removeDoc x');
    t = builtins.typeOf x;
    oneliner = x'.__oneliner or oneliner' == true;
    sep = if oneliner then " " else "\n";
    genPad = pad: if oneliner then "" else stringMultiply " " pad;
  in (if oneliner then "" else genDoc pad x') + {
    string = lib.strings.escapeNixString x;
    list =
      if x == [] then "[]"
      else "[${sep}${lib.concatMapStringsSep sep (item:
        (if oneliner then "" else genDoc (pad + 2) item) +
        genPad (pad + 2) + genNix' (pad + 2) (item.__oneliner or oneliner) (removeDoc item)
      ) x}${sep}${genPad pad}]";
    set =
      if x ? __raw && builtins.isString x.__raw then
        addIndent false (genPad pad) (lib.trim x.__raw)
      else if x == {} then "{ }" else "{${sep}${lib.concatMapAttrsStringSep sep (k: v: 
        (if oneliner then "" else genDoc (pad + 2) v) +
        genPad (pad + 2) + "${lib.strings.escapeNixIdentifier k} = ${genNix' (pad + 2) (v.__oneliner or oneliner) (removeDoc v)};"
      ) x}${sep}${genPad pad}}";
    null = "null";
    int = toString x;
    bool = if x then "true" else "false";
    lambda = "<<FUNC>>";
  }.${t} or (throw "Unknown type ${t}");
}
