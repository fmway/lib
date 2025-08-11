{ sources, lib, self', ... }:
{
  readTree = import sources.read-tree {};
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
  lexer  = import "${sources.nix-parsec}/lexer.nix" { parsec = self'.parsec; };
  parsec = import "${sources.nix-parsec}/parsec.nix";
}
