{ lib, ... }: let
  doMatch = matches: str: res:
    if ! isList matches then
      doMatch [matches] str { index = 0; }
    else if matches == [] then
      { isMatch = false; data = null; index = -1; }
    else let
      r = builtins.match (head matches) str;
    in if isNull r then
      doMatch (builtins.tail matches) str (res // { index = res.index + 1; })
    else (res // { isMatch = true; data = r; })
  ;

  tokenRegex = "(\\\\.|[(][?]<[^>]*>|[(][?]:|[(]|[[]|[]])";

  tokensOf = pattern:
    filter (x: x != "")
      (concatMap (x: if isList x then x else [ x ]) (split tokenRegex pattern));

  scan = pattern:
    let
      tokens = tokensOf pattern;

      go = inClass: classStart: posix: count: descs: out: rest:
        if rest == [ ] then {
          regex = concatStringsSep "" (reverseList out);
          descriptors = reverseList descs;
        }
        else
          let
            tok = head rest;
            tail = builtins.tail rest;
            next = if tail == [ ] then null else head tail;
            isEscape = substring 0 1 tok == "\\";
          in
          if isEscape then
            go inClass false false count descs ([ tok ] ++ out) tail
          else if inClass then
            if tok == "]" then
              if posix || classStart then
                go true false false count descs ([ tok ] ++ out) tail
              else
                go false false false count descs ([ tok ] ++ out) tail
            else if tok == "[" then
              let
                special = next != null
                  && (hasPrefix ":" next
                    || hasPrefix "." next
                    || hasPrefix "=" next);
              in
                go true false special count descs ([ tok ] ++ out) tail
            else if posix then
              go true false true count descs ([ tok ] ++ out) tail
            else if classStart then
              go true (tok == "^") false count descs ([ tok ] ++ out) tail
            else
              go true false false count descs ([ tok ] ++ out) tail
          else if tok == "[" then
            go true true false count descs ([ tok ] ++ out) tail
          else if tok == "]" then
            go false false false count descs ([ tok ] ++ out) tail
          else if tok == "(?:" then
            let n = count + 1; in
            go false false false n
              ([ { kind = "noncapture"; index = n; } ] ++ descs)
              ([ "(" ] ++ out) tail
          else if hasPrefix "(?<" tok then
            let
              len = stringLength tok;
              name = substring 3 (len - 4) tok;
            in
              if name == "" then
                throw "fmway.match.v2: empty capture group name"
              else
                let n = count + 1; in
                go false false false n
                  ([ { kind = "named"; inherit name; index = n; } ] ++ descs)
                  ([ "(" ] ++ out) tail
          else if tok == "(" && next != null && hasPrefix "?" next then
            throw "fmway.match.v2: unsupported group syntax '${substring 0 3 ("(" + next)}'"
          else if tok == "(" then
            let n = count + 1; in
            go false false false n
              ([ { kind = "plain"; index = n; } ] ++ descs)
              ([ "(" ] ++ out) tail
          else
            go false false false count descs ([ tok ] ++ out) tail;
    in go false false false 0 [ ] [ ] tokens;

  duplicateName = names:
    let
      go = seen: rest:
        if rest == [ ] then null
        else
          let name = head rest; in
          if hasAttr name seen then name
          else go (seen // { "${name}" = true; }) (builtins.tail rest);
    in go { } names;

  inherit (builtins)
    concatMap
    concatStringsSep
    elemAt
    filter
    hasAttr
    head
    isList
    listToAttrs
    split
    stringLength
    substring
  ;
  inherit (lib)
    reverseList
    hasPrefix
    throwIf
  ;
in {
  # match :: [String] -> String -> [Null | String] | Null
  # builtins.match but support list
  __functor = self: matches: str:
    (self.debug matches str).data;

  debug = matches: str: doMatch matches str { index = 0; };

  # match.v2 :: String -> Null | { items: [String]; groups: Attrs }
  # builtins.match but support group names
  v2 = {
    __functor = self: pattern:
      (self.compile pattern).match;
    compile = pattern:
    if isNull (builtins.match ".*[(][?].*" pattern) then {
      match = text:
        let raw = builtins.match pattern text; in
          if raw == null then null
          else {
            items = raw;
            groups = { };
          };
    }
    else
      let
        scanned = scan pattern;
        named = filter (d: d.kind == "named") scanned.descriptors;
        duplicate = duplicateName (map (d: d.name) named);
        selected = filter (d: d.kind != "noncapture") scanned.descriptors;
      in throwIf (duplicate != null) "fmway.match.v2: duplicate capture group name '${duplicate}'"
        {
          match = text:
            let raw = builtins.match scanned.regex text; in
              if raw == null then null
              else {
                items = map (d: elemAt raw (d.index - 1)) selected;
                groups = listToAttrs (map (d: {
                  name = d.name;
                  value = elemAt raw (d.index - 1);
                }) named);
              };
        };
  };
}
