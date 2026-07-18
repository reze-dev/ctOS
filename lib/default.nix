{ lib }:

let
  isVisibleModule =
    file:
    let
      name = builtins.baseNameOf file;
    in
    lib.hasSuffix ".nix" (toString file)
    && name != "default.nix"
    && !(lib.hasPrefix "." name)
    && !(lib.hasPrefix "_" name);

  sortPaths = builtins.sort (a: b: toString a < toString b);

  hasFile = dir: name: builtins.pathExists (dir + "/${name}");

  hostHasDisko = hostsDir: hostName: builtins.pathExists (hostsDir + "/${hostName}/disko.nix");
in
{
  scanModules =
    dir:
    if builtins.pathExists dir then
      sortPaths (builtins.filter isVisibleModule (lib.filesystem.listFilesRecursive dir))
    else
      [ ];

  discoverHosts =
    hostsDir:
    let
      entries = builtins.readDir hostsDir;
      isHost =
        name: type:
        type == "directory"
        && hasFile (hostsDir + "/${name}") "default.nix"
        && hasFile (hostsDir + "/${name}") "hardware.nix";
    in
    builtins.attrNames (lib.filterAttrs isHost entries);

  inherit hostHasDisko;

  mkHostModules =
    {
      inputs,
      modulePaths,
      hostsDir,
      commonModule,
      hostName,
    }:
    [
      inputs.dedsec-grub-theme.nixosModule
      (hostsDir + "/${hostName}")
      (hostsDir + "/${hostName}/hardware.nix")
      commonModule
      { nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; }
    ]
    ++ modulePaths
    ++ lib.optionals (hostHasDisko hostsDir hostName) [ inputs.disko.nixosModules.disko ];
}
