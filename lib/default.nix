{ lib }:

let
  isVisibleModule =
    file:
    let
      name = file |> builtins.baseNameOf;
    in
    (file |> toString |> lib.hasSuffix ".nix")
    && name != "default.nix"
    && !(lib.hasPrefix "." name)
    && !(lib.hasPrefix "_" name);

  sortPaths = builtins.sort (a: b: toString a < toString b);

  hasFile = dir: name: (dir + "/${name}") |> builtins.pathExists;

  hostHasDisko = hostsDir: hostName: (hostsDir + "/${hostName}/disko.nix") |> builtins.pathExists;
in
{
  scanModules =
    dir:
    if dir |> builtins.pathExists then
      dir
      |> lib.filesystem.listFilesRecursive
      |> builtins.filter isVisibleModule
      |> sortPaths
    else
      [ ];

  discoverHosts =
    hostsDir:
    let
      isHost =
        name: type:
        type == "directory"
        && hasFile (hostsDir + "/${name}") "default.nix"
        && hasFile (hostsDir + "/${name}") "hardware.nix";
    in
    hostsDir
    |> builtins.readDir
    |> lib.filterAttrs isHost
    |> builtins.attrNames;

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
