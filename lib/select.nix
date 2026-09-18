{ sources, ... }: let
  # nix-select with .**. support => auto flatten attrValues / list
  patched = builtins.toFile "select.nix" (builtins.replaceStrings [
    "  if (mode == \"str\") || (mode == \"maybe\") then"
    "else if mode == \"start\" then\n          if cur == \"*\" then\n            recurse str (idx + 1) (\n              state\n              // {\n                stack = [ \"end\" ] ++ state.stack;\n                selectors = state.selectors ++ [ { type = \"all\"; } ];\n                acc_str = \"\";\n              }\n            )"
    "selector = builtins.elemAt selectors idx;"
    "if builtins.isList obj then\n            if selector.type == \"all\" then"
    "if builtins.isAttrs obj then\n            if selector.type == \"all\" then"
  ] [
    # nix
    ''
      if mode == "all" then
        state.selectors ++ [ { type = mode; } ]
      else if (mode == "str") || (mode == "maybe") then
    ''
    # nix
    ''
      else if mode == "all" then
        if cur == "*" then
          recurse str (idx + 1) (
            state
            // {
              stack = [ "end" ] ++ state.stack;
              selectors = state.selectors ++ [ { type = "values"; } ];
              acc_str = "";
            }
          )
        else
          recurse str idx (
            state
            // {
              stack = [ "end" ] ++ state.stack;
              selectors = state.selectors ++ [ { type = "all"; } ];
              acc_str = "";
            }
          )
      else if mode == "start" then
        if cur == "*" then
          recurse str (idx + 1) (
            state
            // {
              stack = [ "all" ] ++ state.stack;
              acc_str = "";
            }
          )
    ''
    # nix
    ''
      peek = i: if builtins.length selectors == i then { type = "end"; } else builtins.elemAt selectors i;
      selector = peek idx;
      mapValues = let
        next = peek (idx + 1);
        next_next = peek (idx + 2);
      in if next.type == "values" || (next.type == "str" && next_next.type == "values") then
        builtins.concatMap
      else map;
    ''
    # nix
    ''
      if builtins.isList obj then
        if selector.type == "values" then
          mapValues (recurse selectors (idx + 1)) obj
        else if selector.type == "all" then
    ''
    # nix
    ''
      if builtins.isAttrs obj then
        if selector.type == "values" then
          mapValues (recurse selectors (idx + 1)) (builtins.attrValues obj)
        else if selector.type == "all" then
    ''
  ] (builtins.readFile sources.nix-select));
  nix-select = import patched;
in {
  _file = patched;
  parse = nix-select.parseSelector;
  apply = nix-select.applySelectors;
  __functor = self: selector: self.apply (self.parse selector);
}
