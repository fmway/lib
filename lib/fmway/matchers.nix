{ self', lib, ... }: let
  inherit (builtins)
    isString
    isAttrs
    mapAttrs
    filter
  ;
  inherit (self'.fmway)
    hasSuffix'
    hasRegex
    hasFilename
    hasPrefix'
    doImport
    excludeItems
    getFilename
    parser
  ;

  inherit (lib)
    fileContents
  ;
  
  basicMatchers = {
    regex = re: path: hasRegex re (getFilename path);
    extension = ext: path: hasSuffix' ".${ext}" (getFilename path);
    suffix = suf: path: hasSuffix' suf (getFilename path);
    filename = file: path: hasFilename file path;
    prefix = pre: path: hasPrefix' pre (getFilename path);
  };

  basic = mapAttrs (key: value: let
    func = value;
  in selector: {
    _type = "matcher";
    _by-ext = key == "extension";
    isMatchedIn = path: func selector path;
    read = path: variables: fileContents path;
    inherit selector;
    __functor = self: args:
      self // (
        if isAttrs args then 
          args // rec {
            isMatchedIn = path: func selector path;
            selector = if args ? selector then args.selector else self.selector;
          }
        else if isString args then {
          selector = args;
          isMatchedIn = path: func args path;
        } else throw "${self._type} must be string or attrs");
  }) basicMatchers;

in basic // (let
  inherit (basic) extension;
  do = func:
    excludeItems [ "__functor" ] func;
in {
  nix = do (extension "nix" {
    read = path: variables: doImport path variables;
  });
  json = do (extension "json" {
    read = path: _: parser.readJSON path;
  });
  jsonc = do (extension "jsonc" {
    read = path: _: parser.readJSONC path;
  });
  yaml = do (extension "yaml" {
    read = path: _: parser.readYAML path;
  }); 
  toml = do (extension "toml" {
    read = path: _: parser.readTOML path;
  });
  getExt = arr: let
    filtered = filter (x: x._by-ext or false) arr;
  in map (x: x.selector) filtered;
})
