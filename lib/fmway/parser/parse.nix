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

  fix = cwd: removeLetExpr: arr: importer: let
    res = lib.foldl' (acc: curr: let
      key = curr._key or "expr-${toString acc.idx}";
      res = if lib.isString curr then curr
        else if curr ? _let then
          if removeLetExpr then "" else curr.str
        else expr.${key};
    in {
      # FIXME is it possible to make a frienldy error message?
      idx = if lib.isString curr || curr ? _key || curr ? _let then acc.idx else acc.idx + 1;
      _let= acc._let + lib.optionalString (curr ? _let) "${curr._let}\n";
      ctx = acc.ctx + lib.optionalString (curr ? _expr) (addIndent "  " "${key} = ${resolvePath.map (p: "(/. + \"${cwd}/${p}\")") curr._expr};\n");
      gen = acc.gen + (if lib.isStringLike res then res else builtins.toJSON res);
    }) { idx = 0; _let = ""; ctx = ""; gen = ""; } arr;

    file = builtins.toFile "parse-expr.nix" ''
      var: with var;
      let self = {
      ${res.ctx}};
      ${res._let}in self
    '';
    expr = importer file;
  in {
    inherit file expr;
    text = res.gen;
  };

  toExpr = str: str': let
    matches = lib.match "^([^=]*)=([^=].+)$" str;
    expr = lib.trim (if isNull matches then str else lib.elemAt matches 1);
    key = lib.trim (if isNull matches then str else lib.elemAt matches 0);
    exprKey = if isNull matches || key != "" then "_expr" else "_let";
  in lib.throwIf (expr == "") "(parse): value cannot empty in ${str}" {
    "${exprKey}" = expr;
    str = str';
  } // lib.optionalAttrs (!isNull matches && key != "") {
    _key = key;
  };

  getMatch = prefixs: postfixs: fn:
    match' (map (i: fn (lib.elemAt prefixs i) (lib.elemAt postfixs i)) (lib.range 0 (lib.length prefixs - 1)));

  /*
    parse :: Attrs -> String
    simple functions to handle nix expression inside string, first params has prefix and postfix that will inject the nix expression.
    example:
    ```nix
    parse {
      prefix = "\${{"; # github actions like
      postfix= "}}";
      myvar = "work";
      the.value.is = "work";
      text = "this is \${{ myvar }} and \${{ the.value.is }}";
    } # => "this is work and work"
    ```
  */
  parse = { debug ? false, transform ? (x: x), removeLetExpr ? true, importer ? import, customs ? [], ... } @ variables: let
    prefix = flat (variables.prefix or "{{");
    postfix= flat (variables.postfix or "}}");
    fixedPrefix = map fixedInMatch prefix;
    fixedPostfix= map fixedInMatch postfix;
  in lib.throwIfNot (lib.length prefix == lib.length postfix) "both prefix and postfix doesn't match"
  (let
    source = builtins.toPath variables.source;
    str =
      if variables ? text && builtins.isString variables.text then
        variables.text
      else if variables ? source && lib.pathIsRegularFile variables.source then
        lib.fileContents source
      else throw "need source / text param";
    cwd = dirOf
      (if variables ? text then
        (builtins.unsafeGetAttrPos "text" variables).file
      else source);
    getMetadata = variables.getMetadata or (if variables ? source then lib.hasSuffix ".md" source else false);
    fixImporter = lib.flip importer ({ inherit cwd; } // variables);
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
        ++lib.warnIf debug "(parse) found: ${pr}${ctx.pre'}${po}" [rest]
        ++lib.optional (ctx.post' != "") ctx.post' ++ fn [] post;
      in fn r "";

    metaExpr = let
      m = builtins.match "^---\n(.*\n)?---.*" str;
    in if isNull m then [] else [{
      _key = "meta";
      _expr = let r = builtins.elemAt m 0; in if isNull r then "{}" else "{${r}}";
    }];
    init = if getMetadata then metaExpr else [];
    res = fix cwd removeLetExpr (fn init str) fixImporter;
  in {
    inherit debug;
    inherit (res) expr file;
    text = transform res.text;
  });

  exts = {
    html = {
      prefix = "<!--{";
      postfix= "}-->";
    };
    md = exts.html;

    # TODO: ...
  };

  getPrefixPostFixByExtensions = fileName: let
    ext = lib.toLower (lib.last (lib.splitString "." (baseNameOf (builtins.toPath fileName))));
  in exts.${ext} or null;
  inherit (self'.fmway)
    match'
    flat
    fixedInMatch
    addIndent
    resolvePath
  ;
in lib.fix (s: {
  inherit (s.v2) __functor raw;
  v1 = {
    __functor = self: x: let
      r = self.raw x;
    in lib.warnIf r.debug "(parse) result: ${r.file}" r.text;

    raw = parse;
  };

  v2 = let
    inherit (self'.fmway) toString;
    toString'= x: "\"${builtins.replaceStrings [ "\\" "\"" "$" "\t" "\n" ] [ "\\\\" "\\\"" "\\$" "\\t" "\\n" ] x}\"";

    extractMacros = { rawMacros ? [], macros ? [], }: prefix: postfix: str: let
      m = builtins.match "(^|.*\n)(${prefix}#[\t ]*([^\n\t ][^\n]*[^\n\t ])[\t ]*#${postfix}[^\n]*)\n?" str;
    in
      if str == "" || m == null then { pre = str; inherit rawMacros macros; }
      else let
        prev = extractMacros {} prefix postfix (builtins.elemAt m 0);
      in {
        pre = prev.pre;
        rawMacros = prev.rawMacros ++ rawMacros ++ [ (builtins.elemAt m 1) ];
        macros = prev.macros ++ macros ++ [ (builtins.elemAt m 2) ];
      };

    pipe = pipes: ctx:
      if pipes == [] then
        ctx
      else pipe (lib.init pipes) "(${lib.last pipes} ${ctx})";

    # ref: https://elkowar.github.io/yolk/book/rhai_docs/template/
    # template tags
    customs = {
      # {# macro1 #}
      # {# macro2 #}
      # {# macro3 #}
      # context
      # => macro1 (macro2 (macro3 context))
      next-line-tags = str: prefix: postfix: let
        m = builtins.match "(.*${prefix}#[^\n]+#${postfix}[^\n]*)(\n([^\n]+))?(\n(.*))?" str;
      in if isNull m then { ok = false; }
      else let
        extracted_macros = extractMacros {} prefix postfix (builtins.elemAt m 0);
        context = let r = builtins.elemAt m 2; in
          lib.throwIf (isNull r) "Invalid next line tags, no tags in the next line" r;
      in {
        ok = true;
        inherit (extracted_macros) pre;
        post = let r = builtins.elemAt m 4; in if isNull r then "" else r;
        data._expr = /* nix */ ''
          ${toString' (builtins.concatStringsSep "\n" extracted_macros.rawMacros)} + "\n"
          + ${pipe extracted_macros.macros (toString' context)} + "\n"
        '';
      };

      # context {< macro >}
      inline-tags = str: prefix: postfix: let
        matched = builtins.match "(^|.*\n)([^\n]+)(${prefix}<([^\n]+)>${postfix}[^\n]*)(.*)" str;
      in if isNull matched then { ok = false; } else let
        macro  = builtins.elemAt matched 3;
        context= builtins.elemAt matched 1;
      in {
        ok = true;
        data._expr = /* nix */ ''
          ${lib.trim macro} ${toString' context} + ${toString' (builtins.elemAt matched 2)}
        '';
        pre = builtins.elemAt matched 0;
        post= builtins.elemAt matched 4;
      };

      # {% macro %}
      # context
      # {% end %}
      block-tags = str: prefix: postfix: let
        matched = builtins.match "^(.*)(${prefix}%([^\n]+)%${postfix}[^\n]*)\n(.*)\n(${prefix}%[ ]*end[ ]*%${postfix})(.*)$" str;
      in if isNull matched then { ok = false; } else let
        macro  = builtins.elemAt matched 2;
        context= builtins.elemAt matched 3;
      in {
        ok = true;
        data._expr = /* nix */ ''
          ${toString' (builtins.elemAt matched 1)} + "\n" +
          ${lib.trim macro} ${toString' context} + "\n" +
          ${toString' (builtins.elemAt matched 4)}
        '';
        pre = builtins.elemAt matched 0;
        post= builtins.elemAt matched 5;
      };

      # TODO pretty error handling
      # (str: prefix: postfix: let
      #
      # in {})
    };

    # builtins functions
    # FIXME: duplicate keys
    fns = {
      # Replace a hex coor value
      replace_color = to: from: let
        hex = "[A-Fa-f0-9]";
      in rec {
        isFound = !isNull matched;
        found = "#${builtins.elemAt matched 1}";
        rest = builtins.elemAt matched 0;
        replaced = "#${toString to}";
        context = from;
        matched = builtins.match "(.*)#(${hex}{8}|${hex}{6}|${hex}{3}).*" from;
        __toString = self: if !self.isFound then self.context else builtins.replaceStrings [self.found] [ self.replaced ] self.context;
      };
      rcol = fns.replace_color;

      # Multiple replaces for a value
      replace_many = lib.flip (builtins.foldl' (acc: curr: curr (toString acc)));
      # replace_many = lib.flip (builtins.foldl' (acc: curr: curr (toString acc) // {
      #   founds = lib.optionals (lib.isAttrs acc && acc ? founds) acc.founds ++ [curr.found];
      #   replaceds = lib.optionals (lib.isAttrs acc && acc ? replaceds) acc.replaceds ++ [curr.replaced];
      # }));
      rm   = fns.replace_many;

      # FIXME
      # replace with sequence, Maybe we need nix-parsec, i'm too confused with nix regex
      # replace_seq = funcs: {
      #   inherit funcs;
      #   seqs  = [];
      #   target = null;
      #   __toString = self: let
      #     x = builtins.foldl' (acc: curr: let
      #       r = replace_many (map (x: x curr) self.funcs) acc.target;
      #     in { target = r.rest; founds = acc.founds ++ r.founds; replaceds = acc.replaceds ++ r.replaceds; }) { target = self.target; founds = []; replaceds = []; } (lib.reverseList self.seqs);
      #   in builtins.replaceStrings x.founds x.replaceds self.target;
      #   __functor = self: args: self // {
      #     seqs = self.seqs ++ lib.optionals (!isNull self.target) [self.target];
      #     target = args;
      #   };
      # };
      # rseq = fns.replace_seq;

      # replace a version value
      # xx.xx or major.minor.patch-xxx
      replace_ver = to: from: rec {
        isFound = !isNull matched;
        rest = builtins.elemAt matched 0;
        matched = builtins.match "(^|.* )([[:digit:]]+[.][[:digit:]]+[.][[:digit:]]+[^ ]*|[[:digit:]]+[.][[:digit:]]+).*" from;
        found = builtins.elemAt matched 1;
        replaced = to;
        context = from;
        __toString = self: if !self.isFound then self.context else builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
      };
      rver = fns.replace_ver;
      
      # 
      replace_quoted = to: from: let
        matched = [
          (builtins.match ''(.*)((["])([^"]+)(["])).*'' from)
          (builtins.match ''(.*)((['])([^']+)(['])).*'' from)
        ];
        m = let n = builtins.elemAt matched 0; in if isNull n then builtins.elemAt matched 1 else n;
      in {
        isFound = !isNull m;
        inherit matched;
        rest = builtins.elemAt m 0;
        found  = builtins.elemAt m 1;
        replaced = builtins.elemAt m 2 + toString to + builtins.elemAt m 4;
        context = from;
        __toString = self: if ! self.isFound then
          self.context
        else
          builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
      };
      rq = fns.replace_quoted;

      replace_between = left: right: to: from: rec {
        isFound = !isNull matched;
        matched = builtins.match "(.*)${fixedInMatch left}(.+)${fixedInMatch right}.*" from;
        found = "${left}${builtins.elemAt matched 1}${right}";
        rest = builtins.elemAt matched 0;
        replaced = "${left}${toString to}${right}";
        context = from;
        __toString = self: if ! self.isFound then self.context else builtins.replaceStrings [self.found] [ self.replaced ] self.context;
      };
      rbet = fns.replace_between;

      replace_in = between: fns.replace_between between between;
      rin = fns.replace_in;

      replace_re = regex: to: from: rec {
        isFound = !isNull matched;
        matched = builtins.match "(.*)(${regex}).*" from;
        found = builtins.elemAt matched 1;
        rest = builtins.elemAt matched 0;
        context = from;
        replaced = builtins.replaceStrings (builtins.genList (x: "$" + toString x) (lib.length matched - 1)) (lib.tail matched) (toString to);
        __toString = self: if ! self.isFound then self.context else builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
      };
      rr = fns.replace_re;

      replace_value = to: from: let
        matched = [
          (builtins.match "(.*)(=)([ ]*)([^= ]+).*" from)
          (builtins.match "(.*)(:)([ ]*)([^= ]+).*" from)
        ];
        m = let n = builtins.elemAt matched 0; in if isNull n then builtins.elemAt matched 1 else n;
      in {
        isFound = !isNull m;
        inherit matched;
        found = "${builtins.elemAt m 1}${builtins.elemAt m 2}${builtins.elemAt m 3}";
        rest = builtins.elemAt m 0;
        context = from;
        replaced = "${builtins.elemAt m 1}${builtins.elemAt m 2}${toString to}";
        __toString = self:
          if !self.isFound then self.context else builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
      };
      rv = fns.replace_value;
    };
  in {
    __functor = self: x: let
      r = self.raw x;
    in lib.warnIf r.debug "(parse') result: ${r.file}" r.text;

    raw = { ... } @ arg: let
      pp = getPrefixPostFixByExtensions arg.source;
    in parse (arg // {
      removeLetExpr = arg.removeLetExpr or false;
      customs = arg.customs or [] ++ builtins.attrValues customs;
    } // fns // lib.optionalAttrs (!arg?prefix && !arg?postfix && arg?source && !isNull pp) {
      inherit (pp) postfix prefix;
    });
  };
})
