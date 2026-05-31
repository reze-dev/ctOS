# Flake-parts module: auto-discover NixOS hosts + export module sets
{ inputs, ... }:

let
  lib = inputs.nixpkgs.lib;

  scanModules =
    path:
    builtins.filter (
      file: lib.hasSuffix ".nix" (toString file) && builtins.baseNameOf file != "default.nix"
    ) (lib.filesystem.listFilesRecursive path);

  nixosModulePaths = scanModules ../modules/nixos;
  homeModulePaths = scanModules ../modules/home;

  hosts = builtins.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts)
  );

  hostHasDisko = hostName: builtins.pathExists ../hosts/${hostName}/disko.nix;

  mkHost =
    hostName:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs homeModulePaths; };
      modules = [
        inputs.dedsec-grub-theme.nixosModule
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
    nixosConfigurations = lib.genAttrs hosts mkHost;
    nixosModules.default = {
      imports = nixosModulePaths;
    };
    homeManagerModules.default = {
      imports = homeModulePaths;
    };
  };
}
