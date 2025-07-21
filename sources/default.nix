let
  sources = builtins.fromJSON (builtins.readFile ./pin.json);
  res = builtins.mapAttrs (k: v: let
    type = v.type or "tarball";
    fn = if type == "file" then
      builtins.fetchurl
    else if type == "tarball" then
      fetchTarball
    else throw "undefined";
  in fn {
    name = v.name or "source";
    inherit (v) url sha256;
  }) sources;
in res
