let
  inherit (import ../../.) fmway;
in fmway.parse {
  colors.foreground = "aeaeae";
  colors.background = "ababab";
  prefix = "<!--{";
  postfix = "}-->";
  rep = true;
  x = "World";
  source = ./context.md;
}
