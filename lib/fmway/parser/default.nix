{ lib, self, ... }: let
  inherit (lib)
    fileContents
  ;

  # inherit (pkgs)
  #   runCommand
  # ;

  inherit (builtins)
    # readFile
    fromJSON
    fromTOML
  ;

  
in {
  inherit fromJSON fromTOML;
  fromYAML = yaml: self.readYAML (builtins.toFile "file.yaml" yaml);
  fromJSONC = jsonc: self.readJSONC (builtins.toFile "file.jsonc" jsonc);

  readYAML = FILE: throw "readYAML not available for now"
    # fromJSON (
    #   readFile (
    #     runCommand "from-yaml"
    #       {
    #         inherit FILE;
    #         allowSubstitutes = false;
    #         preferLocalBuild = true;
    #       }
    #       ''
    #         cat "$FILE" | ${lib.getExe pkgs.yj} > $out
    #       ''
    #   )
    # )
  ;
  readJSONC = FILE: throw "readJSONC not available for now"
    # fromJSON (
    #   readFile (
    #     runCommand "from-jsonc"
    #       {
    #         inherit FILE;
    #         allowSubstitutes = false;
    #         preferLocalBuild = true;
    #       }
    #       ''
    #         ${pkgs.gcc}/bin/cpp -P -E "$FILE" > $out
    #       ''
    #   )
    # )
    ;
  readJSON = path: fromJSON (fileContents path);
  readTOML = path: fromTOML (fileContents path);
}
