let
  sources = builtins.fromJSON (builtins.readFile ./pin.json);
  mkSource = import ./mkSource.nix;
in mkSource sources
