{ lib }:
rec {
  scanPaths = path:
    builtins.concatMap
      (name:
        let
          type = (builtins.readDir path).${name};
          fullPath = path + "/${name}";
        in
        if type == "directory" then
          scanPaths fullPath
        else if type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix" then
          [ fullPath ]
        else
          []
      )
      (builtins.attrNames (builtins.readDir path));
}
