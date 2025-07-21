{
  description = "Collection of functions and modules for nix in my own way";

  inputs = {
    nixpkgs.url = "github:nix-community/nixpkgs.lib";
    # TODO
    # nix-parsec.url = "github:nprindle/nix-parsec";
  };

  outputs = x: import ./flake-module.nix x;
}
