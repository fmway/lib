{ lib, sources, ... }: let
  patched= builtins.toFile "source" (builtins.replaceStrings [
    "A-Z"
    ''
      node = name: args: children: {
          inherit name;
          inherit (fold-args (lib.toList args)) arguments properties;
          inherit children;
        };
    ''
    "leaf = name: args: node name args [ ];"
    "flag = name: node name [ ] [ ];"
    ''
      serialize.node-with =
          indent:
          {
            name,
            arguments,
            properties,
            children,
          }:
    ''
    ''
      serialize.nodes-with =
          indent:
          lib.flip lib.pipe [
    ''
  ] [
    "_A-Z" # add _ to regex
    # nix
    ''
      node = name: args: let res = {
          children = [];
          inherit name;
          append = lib.mkFn "append" res;
          prepend= lib.mkFn "prepend" res;
          assign = lib.mkFn "assign" res;
          remove = res.assign (removeAttrs res [ "remove" ]) [] // { _remove = true; };
          inherit (fold-args (lib.toList args)) arguments properties;
          __functor = self: args: removeAttrs self [ "merge" "assign" ] // {
            children = self.children ++ (if builtins.isList args then args else [args]);
          };
        }; in res;
    ''
    # nix
    ''
      leaf = name: let res = removeAttrs (plain name) [ "append" "prepend" ] // {
          assign = args: res args // { _do = "assign"; };
          remove = res.assign (removeAttrs res [ "remove" ]) [] // { _remove = true; };
          __functor = self: args: let
            r = fold-args (lib.toList args);
          in self // {
            arguments = self.arguments ++ r.arguments;
            properties = self.properties // r.properties;
          };
        }; in res;
    ''
    # nix
    ''flag = name: removeAttrs (plain name) [ "__functor" "assign" "append" "prepend" ];''
    # nix
    ''
      serialize.node-with =
          indent:
          {
            name,
            arguments,
            properties,
            children,
            ...
          }:
    ''
    # nix
    ''
      serialize.nodes-with =
          indent:
          lib.flip lib.pipe [
            # FIXME too complicated
            (builtins.foldl' (acc: curr: let
              is.assign = curr._do == "assign";
              is.append = curr._do == "append";
              is.prepend= curr._do == "prepend";
              found_me = c: if ! curr ? _has then true else let
                x = lib.kdl.normalize c;
              in curr._has (c // {
                is = y': let y = lib.kdl.normalize y'; in x == y;
                has = y': let y = lib.kdl.normalize y'; in builtins.any (z: y == z) x.children;
              });
            in if ! curr ? _do then
                acc ++ [curr]
              else let
                res = builtins.foldl' (a: c: let
                  is_leaf   = c.children == [] && (c.arguments != [] || c.properties != {});
                  is_found  = found_me c;
                in a // (if is_found && c.name == curr.name && ((!is.assign && !is_leaf && c.arguments == curr.arguments) || is.assign) then
                  lib.throwIf (is_found && a.is_found) "found duplicated nodes ''${curr.name}, i can't do ''${curr._do} twice" {
                    is_found = true;
                    data = let
                      r = if is.append || is.prepend then
                        c // {
                          children = lib.optionals is.prepend curr.children ++ c.children ++ lib.optionals is.append curr.children;
                          properties = lib.optionalAttrs is.prepend curr.properties // c.properties // lib.optionalAttrs is.append curr.properties;
                        }
                      else if is.assign then curr
                      else throw "(kdl:serialize): i don't know what do you mean with ''${curr._do}";
                    in a.data ++ [r];
                  } else { data = a.data ++ [c]; })
                ) { is_found = false; data = []; } acc;
              in res.data ++ lib.optionals (!res.is_found) [curr]
            ) [])
            (builtins.filter (x: !x._remove or false))
    ''
  ] (builtins.readFile sources.kdl));
  r = import patched { lib = lib.extend (_: _: {
    inherit kdl;
    mkFn = name: res: args: if lib.isAttrs args then res args // { _do = name; } else x: res.${name} x // { _has = args; };
  }); };
  kdl = r // {
    shorts = {
      f = r.flag; l = r.leaf; l' = r.magic-leaf; n = r.node; p = r.plain; s = r.serialize;
    };
    normalize = x: lib.mapAttrs (k: v: if k != "children" then v else map kdl.normalize v) (removeAttrs x [ "__functor" "_do" "_has" "assign" "merge" "remove" ]);
    _source = patched;
  };
in kdl
