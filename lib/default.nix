{ sources, lib, self', ... }: let
  systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
in {
  readTree = import sources.read-tree {};
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
  lexer  = import "${sources.nix-parsec}/lexer.nix" { parsec = self'.parsec; };
  parsec = import "${sources.nix-parsec}/parsec.nix";
  eachSystem = systems: fn: builtins.foldl' (acc: system: let
    r = fn system;
  in self'.fmway.foldAttrs' (a: k: v: a // {
    ${k} = a.${k} or {} // {
      ${system} = v;
    };
  }) acc r) {} systems;
  eachDefaultSystem = self'.eachSystem systems;
}
