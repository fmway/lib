let
  inherit (import ../../.) fmway;
in fmway.parse {
  colors.foreground = "aeaeae";
  colors.background = "ababab";
  rep = true;
  x = "World";
  source = ./context.md;
}
