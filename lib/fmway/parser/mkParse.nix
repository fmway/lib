{ lib, self', ... }: let
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

  fix = removeLetExpr: arr: importer: let
    res = lib.foldl' (acc: curr: let
      key = curr._key or "expr-${toString acc.idx}";
      res = if lib.isString curr then curr
        else if curr ? _let then
          if removeLetExpr then "" else curr.str
        else obj.${key};
    in {
      # FIXME is it possible to make a frienldy error message?
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
    obj = importer expr;
  in {
    inherit expr;
    text = res.gen;
  };

  toExpr = str: str': let
    matches = lib.match "^([^=]*)=([^=].+)$" str;
    expr = lib.trim (if isNull matches then str else lib.elemAt matches 1);
    key = lib.trim (if isNull matches then str else lib.elemAt matches 0);
    exprKey = if isNull matches || key != "" then "_expr" else "_let";
  in lib.throwIf (expr == "") "(mkParse): value cannot empty in ${str}" {
    "${exprKey}" = expr;
    str = str';
  } // lib.optionalAttrs (!isNull matches && key != "") {
    _key = key;
  };

  getMatch = prefixs: postfixs: fn:
    match' (map (i: fn (lib.elemAt prefixs i) (lib.elemAt postfixs i)) (lib.range 0 (lib.length prefixs - 1)));

  /*
    mkParse :: Attrs -> String -> String
    simple functions to handle nix expression inside string, first params has prefix and postfix that will inject the nix expression.
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
  mkParse = { debug ? false, transform ? (x: x), removeLetExpr ? true, importer ? (path: import path variables), customs ? [], ... } @ variables: let
    prefix = flat (variables.prefix or "{{");
    postfix= flat (variables.postfix or "}}");
    fixedPrefix = map fixedInMatch prefix;
    fixedPostfix= map fixedInMatch postfix;
  in lib.throwIfNot (lib.length prefix == lib.length postfix) "both prefix and postfix doesn't match"
  (str: let
    fn = res: s: 
      if s == "" then
        res
      else let
        matches = getMatch fixedPrefix fixedPostfix (pre: post:
          "^(.*)${pre}(.+)${post}(.*)$") s;
        customify = builtins.foldl' (r: f:
          if r.ok then
            r
          else
            builtins.foldl' (a: c:
              if a.ok then
                a
              else
                a // f s (builtins.elemAt fixedPrefix c) (builtins.elemAt fixedPostfix c)
            ) r (lib.genList (x: x) (lib.length prefix))) { ok = false; pre = ""; post = ""; data = null; } customs;
      in if customs != [] && customify.ok then
        lib.optionals (customify.pre != "") (fn [] customify.pre)
        ++res ++ [customify.data]
        ++lib.optionals (customify.post != "") (fn [] customify.post)
      else if ! matches.isMatch then
        fn (res ++ [s]) ""
      else let
        pre = lib.elemAt matches.data 0;
        c   = lib.elemAt matches.data 1;
        po  = lib.elemAt postfix matches.index;
        pr  = lib.elemAt prefix  matches.index;
        ctx = getCtx c po;
        foundExpr = "${pr}${c}${po}";
        rest=
          if ctx.pre == "" && ctx.post == "" then
            foundExpr
          else toExpr ctx.pre foundExpr;
        post= lib.elemAt matches.data 2;
        r   =
          fn [] pre
        ++lib.warnIf debug "(mkParse) found: ${pr}${ctx.pre'}${po}" [rest]
        ++lib.optional (ctx.post' != "") ctx.post' ++ fn [] post;
      in fn r "";

    res = fix removeLetExpr (fn [] str) importer;
  in lib.warnIf debug "(mkParse) result: ${res.expr}" (transform res.text));

  inherit (self'.fmway)
    match'
    flat
    fixedInMatch
    addIndent
  ;
in mkParse
