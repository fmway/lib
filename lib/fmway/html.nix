# reference: https://code.tvl.fyi/tree/users/sterni/nix/html/default.nix

# sterni nix html render, but with infinite function
{ lib, ... }:
let
  inherit (lib) flatten concatStrings;
  inherit (builtins) isAttrs replaceStrings foldl' isString;
  /* escapeMinimal :: String -> String
     Escape everything we have to escape in an HTML document if either
     in a normal context or an attribute string (`<>&"'`).

     A shorthand for this function called `esc` is also provided.

     Example:
     escapeMinimal "<hello>"
     => "&lt;hello&gt;"
  */
  escapeMinimal = replaceStrings
    [ "<" ">" "&" "\"" "'" ]
    [ "&lt;" "&gt;" "&amp;" "&quot;" "&#039;" ];

  /* renderTag: String -> (AttrSet | Null | [String | Tag]) -> (AttrSet | Null | [String | Tag]) -> ...
     Return (an infinite function that can be cast to) a string with a correctly
     rendered tag of the given name, with the given attributes which are
     automatically escaped.

     If the content argument is `null`, the tag will have no children nor a
     closing element. If the content argument is a string it is used as the
     content as is (unescaped). If the content argument is a list, its
     elements are concatenated (recursively if necessary). If the content
     is attrs, it will become an html attributes

     `renderTag` is only an internal function which is reexposed as `__findFile`
     to allow for much neater syntax than calling `renderTag` everywhere:

     ```nix
     let
       inherit (fmway-nix.parser.html) __findFile esc;
     in {
       html1 = <html> {} [
         (<head> {} (<title> {} "hello world"))
         (<body> {} [
           (<h1> {} "hello world")
           (<p> {} "foo bar")
         ])
       ];
       # or you can easily ignore arrays and an empty attrs
       html2 =
         (<html>
           (<head> (<title> "hello world"))
           (<body> 
             (<h1> "hello world")
             (<p> "foo bar")
           )
         );
    }
     ```

     As you can see, the need to call a function disappears, instead the
     `NIX_PATH` lookup operation via `<foo>` is overloaded, so it becomes
     `renderTag "foo"` automatically.

     If the tag is "html", e.g. in case of `<html> { } …`, "<!DOCTYPE html> will
     be prepended to the normal rendering of the text.

     Example:

     <link> {
       rel = "stylesheet";
       href = "/css/main.css";
       type = "text/css";
     }

     renderTag "link" {
       rel = "stylesheet";
       href = "/css/main.css";
       type = "text/css";
     }

     => "<link href=\"/css/main.css\" rel=\"stylesheet\" type=\"text/css\"/>"
     # you need to call toString or wrap the tag with "${<tag>...}" or ''${<tag>...''

     <p> [
       "foo "
       (<strong> "bar")
     ]

     renderTag "p" "foo <strong>bar</strong>"
     => "<p>foo <strong>bar</strong></p>"

    if you worry about __findFile, you can pick specific key that will be render by renderTag

    html = let inherit (fmway-nix.parser.html) __findFile; in toString
    (<html>
      (<head>
        (<title> "Hello World")
        (<style> ''
          p {
            color: blue;
          }
        '')
      )
      (<body>
        (<h1> "Hello World" { style = "text-align:center;"; })
        (<p> "lorem ipsum dolor sit amet coloroda.")
      )
    )
  */
  # TODO more features in style, id/class, and script
  renderTag = tag: {
    _type = "html";
    _tag = tag;
    _attrs = {};
    _children = null;
    __toString = toHtmlString;
    __functor = self: arg:
      self // (if isAttrs arg && ! arg ? __toString then {
        _attrs = self._attrs // arg;
      } else {
        _children = if isNull self._children && !isNull arg then
          flatten arg
        else if isNull arg then
          null
        else flatten self._children ++ flatten arg;
      });
  };

  /* toString alternative */
  toValue = v: if isString v then v else builtins.toJSON v;

  toHtmlAttrs = attrs: foldl' (acc: curr:
    acc + " ${escapeMinimal curr}=\"${escapeMinimal (toValue attrs.${curr})}\""
  ) "" (builtins.attrNames attrs);
  toHtmlString = self:
    (if self._tag == "html" then "<!DOCTYPE html>" else "")
    + "<${self._tag}${toHtmlAttrs self._attrs}" + (
      if isNull self._children then
        "/>"
      else
        ">" + concatStrings (map (x: if isAttrs x && x._type or "" == "html" then
          toString x
        else escapeMinimal x) self._children) + "</${self._tag}>"
    );

in
{
  inherit renderTag;
  __findFile = _: renderTag;
}
