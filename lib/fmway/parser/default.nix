{ lib, self, self', ... }: let
  inherit (lib)
    fileContents
  ;

  # inherit (pkgs)
  #   runCommand
  # ;

  inherit (self'.fmway)
    addIndent
    match'
    flat
    fixedInMatch
  ;

  inherit (builtins)
    # readFile
    fromJSON
    fromTOML
  ;

  # for handle ctx multiple postfix
  getCtx = str: postfix: let
    fn = str: let
      matches = lib.match "^(.*)${fixedInMatch postfix}(.*)$" str;
      h = lib.head matches;
      t = lib.last matches;
      h'= fn h;
    in if isNull matches then str else {
      pre = if lib.isString h' then h' else fn h'.pre;
      post= lib.optionalString (!lib.isString h') h'.post + t + postfix;
    };
    res = fn str;
  in rec {
    pre' = if lib.isString res then res else res.pre;
    pre  = lib.trim pre';
    post'= if lib.isString res then "" else res.post;
    post = lib.trim post';
  };

  mkParse = { _debug ? false, prefix ? "{{", postfix ? "}}", ... } @ variables: str: let
    matches = lib.match "^(.*)${fixedInMatch prefix}(.+)${fixedInMatch postfix}(.*)$" str;
    self = mkParse (variables // { inherit prefix postfix;});
  in if isNull matches then str else let
    pre = lib.elemAt matches 0;
    c   = lib.elemAt matches 1;
    ctx = getCtx c postfix;
    rest=
      if ctx.pre == "" && ctx.post == "" then
        "${prefix}${c}${postfix}"
      else lib.getAttrFromPath (lib.splitString "." ctx.pre) variables;
    post= lib.elemAt matches 2;
    res = self pre + (if lib.isStringLike rest then rest else builtins.toJSON rest) + ctx.post' + self post;
  in lib.warnIf _debug "(mkParse) found: ${prefix}${ctx.pre'}${postfix}" res;

  fix = arr: var: let
    res = lib.foldl' (acc: curr: let
      key = curr._key or "expr-${toString acc.idx}";
      res = if lib.isString curr then curr
        else if curr ? _let then ""
        else obj.${key};
    in {
      idx = if lib.isString curr || curr ? _key || curr ? _let then acc.idx else acc.idx + 1;
      _let= acc._let + lib.optionalString (curr ? _let) "${curr._let}\n";
      ctx = acc.ctx + lib.optionalString (curr ? _expr) (addIndent "  " "${key} = ${curr._expr};\n");
      gen = acc.gen + (if lib.isStringLike res then res else builtins.toJSON res);
    }) { idx = 0; _let = ""; ctx = ""; gen = ""; } arr;

    expr = builtins.toFile "mkParse-expr.nix" ''
      var: with var;
      let self = {
      ${res.ctx}};
      ${res._let}in self
    '';
    obj = import expr var;
  in {
    inherit expr;
    text = res.gen;
  };

  toExpr = str: let
    matches = lib.match "^([^=]*)=([^=].+)$" str;
    expr = lib.trim (if isNull matches then str else lib.elemAt matches 1);
    key = lib.trim (if isNull matches then str else lib.elemAt matches 0);
    exprKey = if isNull matches || key != "" then "_expr" else "_let";
  in lib.throwIf (expr == "") "(mkParse): value cannot empty in ${str}" {
    "${exprKey}" = expr;
  } // lib.optionalAttrs (!isNull matches && key != "") {
    _key = key;
  };

  getMatch = prefixs: postfixs: fn:
    match' (map (i: fn (lib.elemAt prefixs i) (lib.elemAt postfixs i)) (lib.range 0 (lib.length prefixs - 1)));

  mkParse' = { _debug ? false, _transpose ? (x: x), ... } @ variables: let
    prefix = flat (variables.prefix or "{{");
    postfix= flat (variables.postfix or "}}");
  in lib.throwIfNot (lib.length prefix == lib.length postfix) "both prefix and postfix doesn't match"
  (str: let
    fn = res: s: 
      if s == "" then
        res
      else let
        matches = getMatch prefix postfix (prefix: postfix: let
          fixedPrefix = fixedInMatch prefix;
          fixedPostfix= fixedInMatch postfix;
        in "^(.*)${fixedPrefix}(.+)${fixedPostfix}(.*)$") s;
      in if ! matches.isMatch then
        fn (res ++ [s]) ""
      else let
        pre = lib.elemAt matches.data 0;
        c   = lib.elemAt matches.data 1;
        po  = lib.elemAt postfix matches.index;
        pr  = lib.elemAt prefix  matches.index;
        ctx = getCtx c po;
        rest=
          if ctx.pre == "" && ctx.post == "" then
            "${pr}${c}${po}"
          else toExpr ctx.pre;
        post= lib.elemAt matches.data 2;
        r   =
          fn [] pre
        ++lib.warnIf _debug "(mkParse) found: ${pr}${ctx.pre'}${po}" [rest]
        ++lib.optional (ctx.post' != "") ctx.post' ++ fn [] post;
      in fn r "";

    res = fix (fn [] str) variables;
  in lib.warnIf _debug "(mkParse) result: ${res.expr}" (_transpose res.text));
in {
  inherit fromJSON fromTOML;
  fromYAML = yaml: self.readYAML (builtins.toFile "file.yaml" yaml);
  fromJSONC = jsonc: self.readJSONC (builtins.toFile "file.jsonc" jsonc);

  readYAML = FILE: throw "readYAML not available for now"
    # fromJSON (
    #   readFile (
    #     runCommand "from-yaml"
    #       {
    #         inherit FILE;
    #         allowSubstitutes = false;
    #         preferLocalBuild = true;
    #       }
    #       ''
    #         cat "$FILE" | ${lib.getExe pkgs.yj} > $out
    #       ''
    #   )
    # )
  ;
  readJSONC = FILE: throw "readJSONC not available for now"
    # fromJSON (
    #   readFile (
    #     runCommand "from-jsonc"
    #       {
    #         inherit FILE;
    #         allowSubstitutes = false;
    #         preferLocalBuild = true;
    #       }
    #       ''
    #         ${pkgs.gcc}/bin/cpp -P -E "$FILE" > $out
    #       ''
    #   )
    # )
    ;
  readJSON = path: fromJSON (fileContents path);
  readTOML = path: fromTOML (fileContents path);

  /*
    mkParse :: Attrs -> String -> String
    simple functions to handle variables inside string, first params has prefix and postfix that will inject the variable.
    example:
    ```nix
    let
      parse = mkParse {
        prefix = "\${{"; # github actions like
        postfix= "}}";
        myvar = "work";
        the.value.is = "work";
      };
    in parse "this is \${{ myvar }} and \${{ the.value.is }}" # => "this is work and work"
    ```
   */
  inherit mkParse;
  # mkParse with all functionality in nix (like math operation)
  inherit mkParse';
}
