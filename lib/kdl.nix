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
  ] [
    "_A-Z" # add _ to regex
    ''
      node = name: args: {
          children = [];
          inherit name;
          inherit (fold-args (lib.toList args)) arguments properties;
          __functor = self: args: self // {
            children = self.children ++ (if builtins.isList args then args else [args]);
          };
        };
    ''
    ''
      leaf = name: args: node name args [ ] // rec {
          __functor = self: args: let
            r = fold-args (lib.toList args);
          in self // {
            inherit __functor;
            arguments = self.arguments ++ r.arguments;
            properties = self.properties // r.properties;
          };
        };
    ''
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
  ] (builtins.readFile sources.kdl));
  r = import patched { inherit lib; };
in r // {
  shorts = {
    f = r.flag; l = r.leaf; l' = r.magic-leaf; n = r.node; p = r.plain; s = r.serialize;
  };
}
