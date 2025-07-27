{ self', lib, sources, ... }: let
  fn = import sources.infuse-nix;
  sugarify = sugars': let
    sugars = let
      x = if lib.isAttrs sugars' then lib.attrsToList sugars' else sugars';
    in self'.fmway.uniqLastBy (x: x.name) (infuse.v1.default-sugars ++ x);
    infuse = fn {
      inherit lib sugars;
    };
  in infuse // {
    __functor = self: self.v1.infuse;
  };

# FIXME recursive sugarify
in sugarify {} // { inherit sugarify; }
