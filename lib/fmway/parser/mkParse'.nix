{ self', lib, ... }: let
  inherit (self'.fmway)
    fixedInMatch
    mkParse
    toString
  ;

  toString'= x: "\"${builtins.replaceStrings [ "\\" "\"" "$" ] [ "\\\\" "\\\"" "\\$" ] x}\"";
in { ... } @ arg: mkParse (arg // {
  removeLetExpr = arg.removeLetExpr or false;
  customs = arg.customs or [] ++ [
    # {# macro #}
    # context
    (str: prefix: postfix: let
      # TODO support multi macro
      matched = builtins.match "(^|.*)(${prefix}#([^\n]+)#${postfix}[^\n]*)\n([^\n]+)\n(.*)$" str;
    in if isNull matched then { ok = false; } else let
      macro  = lib.elemAt matched 2;
      context= builtins.elemAt matched 3;
    in {
      ok = true;
      data._expr = /* nix */ ''
        ${toString' (builtins.elemAt matched 1)} + "\n"
        + ${lib.trim macro} ${toString' context} + "\n"'';
      pre = builtins.elemAt matched 0;
      post= builtins.elemAt matched 4;
    })
    # context {< macro >}
    (str: prefix: postfix: let
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
    })
    # {% macro %}
    # context
    # {% end %}
    (str: prefix: postfix: let
      # FIXME add if else support
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
    })
    # FIXME error handling
    # (str: prefix: postfix: let
    #
    # in {})
  ];

  # FIXME duplicate keys
  importer = lib.flip import (arg // rec {
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
    rcol = replace_color;

    # Multiple replaces for a value
    replace_many = lib.flip (builtins.foldl' (acc: curr: curr (toString acc)));
    # replace_many = lib.flip (builtins.foldl' (acc: curr: curr (toString acc) // {
    #   founds = lib.optionals (lib.isAttrs acc && acc ? founds) acc.founds ++ [curr.found];
    #   replaceds = lib.optionals (lib.isAttrs acc && acc ? replaceds) acc.replaceds ++ [curr.replaced];
    # }));
    rm   = replace_many;

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
    # rseq = replace_seq;

    # replace a version value
    # xx.xx or major.minor.patch-xxx
    replace_ver = to: from: rec {
      isFound = !isNull matched;
      rest = builtins.elemAt matched 0;
      matched = builtins.match "(.*)([[:digit:]]{2}[.][[:digit:]]{2}|[[:digit:]][.]+[[:digit:]]+[.][[:digit:]]+(-[^ ]+)?).*" from;
      found = builtins.elemAt matched 1;
      replaced = to;
      context = from;
      __toString = self: if !self.isFound then self.context else builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
    };
    rver = replace_ver;
    
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
    rq = replace_quoted;

    replace_between = left: right: to: from: rec {
      isFound = !isNull matched;
      matched = builtins.match "(.*)${fixedInMatch left}(.+)${fixedInMatch right}.*" from;
      found = "${left}${builtins.elemAt matched 1}${right}";
      rest = builtins.elemAt matched 0;
      replaced = "${left}${toString to}${right}";
      context = from;
      __toString = self: if ! self.isFound then self.context else builtins.replaceStrings [self.found] [ self.replaced ] self.context;
    };
    rbet = replace_between;

    replace_in = between: replace_between between between;
    rin = replace_in;

    replace_re = regex: to: from: rec {
      isFound = !isNull matched;
      matched = builtins.match "(.*)(${regex}).*" from;
      found = builtins.elemAt matched 1;
      rest = builtins.elemAt matched 0;
      context = from;
      replaced = builtins.replaceStrings (builtins.genList (x: "$" + toString x) (lib.length matched - 1)) (lib.tail matched) (toString to);
      __toString = self: if ! self.isFound then self.context else builtins.replaceStrings [ self.found ] [ self.replaced ] self.context;
    };
    rr = replace_re;

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
    rv = replace_value;
  });
})
