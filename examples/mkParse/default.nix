let
  inherit (import ../../.) fmway;
in fmway.mkParse' {
  colors.foreground = "aeaeae";
  colors.background = "ababab";
  prefix = "<!--{";
  postfix = "}-->";
  rep = true;
  x = "World";
} (builtins.readFile ./context.md)
