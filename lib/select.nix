{ sources, ... }: let
  # nix-select with .**. support => auto flatten attrValues / list
  patched = builtins.toFile "select.nix" (builtins.replaceStrings [
    "acc_str = \"\";"
    "  if (mode == \"str\") || (mode == \"maybe\") then"
    "type = mode;"
    "if (state.submode == \"\") && (cur == \"?\")"
    "else if (mode == \"str\") || (mode == \"maybe\") then"
    "type = if state.submode == \"\" then \"str\" else state.submode;"
    "{\n                acc_str = \"\${state.acc_str}\${cur}\";\n                submode = if state.submode == \"\" then \"str\" else state.submode;\n              }"
    "else if mode == \"start\" then\n          if cur == \"*\" then\n            recurse str (idx + 1) (\n              state\n              // {\n                stack = [ \"end\" ] ++ state.stack;\n                selectors = state.selectors ++ [ { type = \"all\"; } ];\n                acc_str = \"\";\n              }\n            )"
    "applySelectors =\n    selectors: obj:\n    let"
    "selector = builtins.elemAt selectors idx;"
    "if builtins.isList obj then\n            if selector.type == \"all\" then"
    "if builtins.isAttrs obj then\n            if selector.type == \"all\" then\n              builtins.mapAttrs (_: v: recurse selectors (idx + 1) v) obj"
    "if x.type == \"maybe\" then"
    "if selector.type == \"maybe\" then"
    "name = x.value;"
    "{ \${selector.value} = recurse selectors (idx + 1) (builtins.getAttr selector.value obj); }"
    "\${sel.value}"
  ] [
    # nix
    ''
      acc_str = "";
      acc_rename = "";
    ''
    # nix
    "  if (mode == \"str\") || (mode == \"maybe\") || (mode == \"maybe_\") || (mode == \"all\") || (mode == \"all_\") then"
    # nix
    "type = if mode == \"all_\" then \"all\" else mode;"
    # nix
    ''
      if (state.submode != "maybe_") && (cur == ":") then
        recurse str (idx + 1) (
          state
          // {
            submode = if state.submode == "maybe" then "maybe_renamed" else "renamed";
          }
        )
      else if (state.submode == "") && (cur == "?")
    ''
    # nix
    ''
      else if mode == "maybe" && cur == "?" then
        recurse str (idx + 1) (
          state
          // {
            stack = [ "maybe_" ];
            acc_str = "";
          }
        )
      else if (mode == "str") || (mode == "maybe") || (mode == "maybe_") || (mode == "all_") then
    ''
    # nix
    ''
      type = if state.submode == "" || state.submode == "renamed" then "str" else if state.submode == "maybe_renamed" then "maybe" else state.submode;
      rename = if state.submode == "renamed" || state.submode == "maybe_renamed" then state.acc_rename else "";
    ''
    # nix
    ''
      (if state.submode == "renamed" || state.submode == "maybe_renamed" then {
        acc_rename = "''${state.acc_rename}''${cur}";
      } else {
        acc_str = "''${state.acc_str}''${cur}";
        submode = if state.submode == "" then "str" else state.submode;
      })
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
        else if cur == ":" then
          recurse str (idx + 1) (
            state
            // {
              stack = [ "all_" ];
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
      getKey = selector:
        if selector.rename or "" != "" then selector.rename else selector.value;
      applySelectors =
        selectors: obj: let
          peek = i: if builtins.length selectors == i then { type = "end"; } else builtins.elemAt selectors i;
    ''
    # nix
    ''
      selector = peek idx;
      next = peek (idx + 1);
      next_next = peek (idx + 2);
      mapValues =
        if next.type == "values" || (next.type == "str" && next_next.type == "values") then
          builtins.concatMap
        else map;
      fixValues =
        fn: l: builtins.filter (x: x != { }) (mapValues fn l);
    ''
    # nix
    ''
      if builtins.isList obj then
        if selector.type == "values" then
          fixValues (recurse selectors (idx + 1)) obj
        else if selector.type == "all" then
          (x: if selector.value != "" then builtins.warn "all type with custom name not supported for lists" x else x)
    ''
    # nix
    ''
      if builtins.isAttrs obj then
        if selector.type == "values" then
          fixValues (recurse selectors (idx + 1)) (builtins.attrValues obj)
        else if selector.type == "all" then
          if selector.value or "" == "" then
            builtins.mapAttrs (_: v: recurse selectors (idx + 1) v) obj
          else
            builtins.listToAttrs (map (x: let
              o = builtins.getAttr x obj;
            in {
              name = builtins.getAttr selector.value o;
              value = recurse selectors (idx + 1) o;
            }) (builtins.attrNames obj))
    ''
    # nix
    "if x.type == \"maybe\" || x.type == \"maybe_\" then"
    # nix
    "if selector.type == \"maybe\" || selector.type == \"maybe_\" then"
    # nix
    "name = getKey x;"
    # nix
    "(r: if selector.type == \"maybe\" then { \${getKey selector} = r; } else r) (recurse selectors (idx + 1) (builtins.getAttr selector.value obj))"
    # nix
    "\${getKey sel}"
  ] (builtins.readFile sources.nix-select));
  nix-select = import patched;
in {
  _file = patched;
  parse = nix-select.parseSelector;
  apply = nix-select.applySelectors;
  __functor = self: selector: self.apply (self.parse selector);
}
