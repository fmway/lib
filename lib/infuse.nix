{ self', lib, sources, ... }: let
  prevInfuse = import sources.infuse-nix;
  defaultInfuse = prevInfuse { inherit lib; };
  mkInfuse = sugars: {
    _sugars = sugars;
    __functor = self': (prevInfuse { inherit lib; sugars = self'._sugars; }).v1.infuse;
    sugarify = { ... } @ sugars': mkInfuse (self'.fmway.uniqLastBy (x: x.name) (sugars ++ lib.attrsToList sugars'));
  };
in mkInfuse defaultInfuse.v1.default-sugars
