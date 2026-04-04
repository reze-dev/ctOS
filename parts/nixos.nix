# Flake-parts module: auto-discover NixOS hosts + export module sets
{ self, inputs, ... }:

let
  lib = inputs.nixpkgs.lib;

  # Inline scanPaths — recursively collect .nix files, skipping default.nix
  scanPaths = path:
    builtins.readDir path
    |> builtins.attrNames
    |> builtins.concatMap (name:
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
    );

  nixosModulePaths = scanPaths ../modules/nixos;
  homeModulePaths = scanPaths ../modules/home;

  hosts =
    builtins.readDir ../hosts
    |> lib.filterAttrs (name: type: type == "directory");

  hostHasDisko = hostName: builtins.pathExists ../hosts/${hostName}/disko.nix;

  mkHost = hostName:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs homeModulePaths; };
      modules = [
        ../hosts/${hostName}
        ../hosts/${hostName}/hardware.nix
        ../hosts/common.nix
        { nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ]; }
      ]
      ++ nixosModulePaths
      ++ (lib.optionals (hostHasDisko hostName) [
        inputs.disko.nixosModules.disko
        ../hosts/disko.nix
      ]);
    };
in
{
  flake = {
    nixosConfigurations = hosts |> lib.mapAttrs (name: _: mkHost name);
    nixosModules.default = { imports = nixosModulePaths; };
    homeManagerModules.default = { imports = homeModulePaths; };
  };
}
