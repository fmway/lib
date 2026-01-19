{ sources, lib, self', ... }: let
  defaultSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
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
  eachDefaultSystem = self'.eachSystem defaultSystems;
  # minimal flake schema generator, without evalModules
  mkFlake' = { systems ? defaultSystems, inputs, nixpkgs ? {}, flake ? {}, perSystem ? (x: {}), ... } @a: let
    others = removeAttrs a [ "systems" "inputs" "flake" "perSystem" "nixpkgs" ];
  in self'.eachSystem systems (system: let
    inputs' = lib.mapAttrs (_: v: v.${system} or v) inputs;
    args = { inherit system inputs inputs'; } // lib.optionalAttrs (inputs ? nixpkgs) rec {
      pkgs = import inputs.nixpkgs { inherit system; config = nixpkgs; };
      lib = pkgs.lib;
    };
  in perSystem args) // others // flake;
}
