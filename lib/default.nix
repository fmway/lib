{ sources, lib, ... }:
{
  readTree = import sources.read-tree {};
  mapListToAttrs = fn: l: lib.listToAttrs (map fn l);
}
