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
          merge = args: res args // { _do = "merge"; };
          assign = args: res args // { _do = "assign"; };
          inherit (fold-args (lib.toList args)) arguments properties;
          __functor = self: args: removeAttrs self [ "merge" "assign" ] // {
            children = self.children ++ (if builtins.isList args then args else [args]);
          };
        }; in res;
    ''
    # nix
    ''
      leaf = name: plain name // {
          __functor = self: args: let
            r = fold-args (lib.toList args);
          in self // {
            arguments = self.arguments ++ r.arguments;
            properties = self.properties // r.properties;
          };
        };
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
            (builtins.foldl' (acc: curr:
              if ! curr ? _do then
                acc ++ [curr]
              else let
                res = builtins.foldl' (a: c:
                  a // (if c.name == curr.name && c.arguments == curr.arguments then
                  lib.throwIf a.is_found "found duplicated nodes ''${curr.name}, i can't do ''${curr._do} twice" {
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
  r = import patched { inherit lib; };
in r // {
  shorts = {
    f = r.flag; l = r.leaf; l' = r.magic-leaf; n = r.node; p = r.plain; s = r.serialize;
  };
}
