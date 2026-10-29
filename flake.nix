{
  description = "Collection of functions and modules for nix in my own way";

  inputs = {
    nixpkgs.url = "github:nix-community/nixpkgs.lib";
    fmway-parser.url = "github:fmway/parser";
  };

  outputs = x: import ./flake-module.nix x;
}
