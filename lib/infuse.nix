{ self', lib, sources, ... }: let
  inherit (self'.fmway) do;
  fn = import sources.infuse-nix;
  mkInfuse = { overlays ? [] }: let
    infuse = fn {
      inherit lib;
      sugars =
        if overlays == [] then
          null
        else
          lib.attrsToList (removeAttrs (lib.fix (lib.extends (lib.composeManyExtensions overlays) (_: infuse.v1 // builtins.listToAttrs infuse.v1.default-sugars))) (builtins.attrNames infuse.v1));
    };
    self = infuse // {
      __functor = self: self.v1.infuse;
      assignable = template "__assign";
      initable   = template "__init";
      defaultable= template "__default";

      addSugars = x: mkInfuse {
        overlays = overlays ++ [
          (self: super: do (do x self) super)
        ];
      };
    };
  in self;

  template = method: val:
    if lib.isDerivation val || !lib.isAttrs val then {
      "${method}" = val;
    } else lib.mapAttrs (k: v:
      if k == method then
        v
      else
        template method v
    ) val;

in mkInfuse { }
