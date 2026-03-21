{ sources, lib, self', ... }: let
  defaultSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
in {
  readTree = import sources.read-tree {};
  import-tree = import sources.import-tree;
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
  lexer  = import "${sources.nix-parsec}/lexer.nix" { parsec = self'.parsec; };
  parsec = import "${sources.nix-parsec}/parsec.nix";
  eachSystem = systems: fn: let
    outputsParams = builtins.listToAttrs (map (system: {
      name = system;
      value = fn system;
    }) systems);
    
    keys = builtins.attrNames (outputsParams.${builtins.head systems});
  in builtins.listToAttrs (map (key: {
    name = key;
    value = builtins.listToAttrs (map (system: {
      name = system;
      value = outputsParams.${system}.${key};
    }) systems);
  }) keys);
  eachDefaultSystem = self'.eachSystem defaultSystems;
  # minimal flake schema generator, without evalModules
  mkFlake' = { systems ? defaultSystems, inputs, nixpkgs ? {}, flake ? {}, perSystem ? (x: {}), ... } @a:
  self'.eachSystem systems (system: let
    pkgs =
      if inputs ? nixpkgs then
        import inputs.nixpkgs (nixpkgs // { inherit system; })
      else {};
  in perSystem {
    inherit system inputs pkgs;
    lib = pkgs.lib or {};
  }) // flake // removeAttrs a [ "systems" "inputs" "flake" "perSystem" "nixpkgs" ];
}
