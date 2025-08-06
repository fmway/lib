{ sources, lib, ... }: {
  readTree = import sources.read-tree {};
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
  kdl = let r = import sources.kdl { inherit lib; }; in r // { shorts = {
    f = r.flag; l = r.leaf; l' = r.magic-leaf; n = r.node; p = r.plain; s = r.serialize;
  }; };
}
