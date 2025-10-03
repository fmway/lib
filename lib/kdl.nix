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
          merge = args: if lib.isAttrs args then res args // { _do = "merge"; } else x: res.merge x // { _has = args; };
          assign = args: if lib.isAttrs args then res args // { _do = "assign"; } else x: res.assign x // { _has = args; };
          inherit (fold-args (lib.toList args)) arguments properties;
          __functor = self: args: removeAttrs self [ "merge" "assign" ] // {
            children = self.children ++ (if builtins.isList args then args else [args]);
          };
        }; in res;
    ''
    # nix
    ''
      leaf = name: let res = removeAttrs (plain name) [ "merge" ] // {
          assign = args: res args // { _do = "assign"; };
          __functor = self: args: let
            r = fold-args (lib.toList args);
          in self // {
            arguments = self.arguments ++ r.arguments;
            properties = self.properties // r.properties;
          };
        }; in res;
    ''
    # nix
    ''flag = name: removeAttrs (plain name) [ "__functor" "assign" "merge" ];''
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
                  is_assign = curr._do == "assign";
                  is_leaf   = c.children == [] && builtins.length c.arguments == 1;
                  is_found  = found_me c;
                in a // (if is_found && c.name == curr.name && ((!is_assign && !is_leaf && c.arguments == curr.arguments) || is_assign && is_leaf) then
                  lib.throwIf (is_found && a.is_found) "found duplicated nodes ''${curr.name}, i can't do ''${curr._do} twice" {
                    is_found = true;
                    data = let
                      r = if curr._do == "merge" then
                        c // {
                          children = c.children ++ curr.children;
                          properties = c.properties // curr.properties;
                        }
                      else if curr._do == "assign" then curr
                      else throw "(kdl:serialize): i don't know what do you mean with ''${curr._do}";
                    in a.data ++ [r];
                  } else { data = a.data ++ [c]; })
                ) { is_found = false; data = []; } acc;
              in res.data ++ lib.optionals (!res.is_found) [curr]
            ) [])
    ''
  ] (builtins.readFile sources.kdl));
  r = import patched { lib = lib.extend (_: _: { inherit kdl; }); };
  kdl = r // {
    shorts = {
      f = r.flag; l = r.leaf; l' = r.magic-leaf; n = r.node; p = r.plain; s = r.serialize;
    };
    normalize = x: lib.mapAttrs (k: v: if k != "children" then v else map kdl.normalize v) (removeAttrs x [ "__functor" "_do" "_has" "assign" "merge" ]);
    _source = patched;
  };
in kdl
