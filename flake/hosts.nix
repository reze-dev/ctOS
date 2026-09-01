# Flake-parts module: auto-discover hosts + export module sets
{ inputs, ... }:

let
  lib = inputs.nixpkgs.lib;
  ctos = import ../lib/core.nix { inherit lib; };
  modulePaths = ctos.scanModules ../modules;
  hostsDir = ../hosts;
  hosts = ctos.discoverHosts hostsDir;

  mkHost =
    hostName:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs ctos;
      };
      modules = ctos.mkHostModules {
        inherit
          inputs
          modulePaths
          hostsDir
          hostName
          ;
        commonModule = ../hosts/common.nix;
      };
    };
in
{
  flake = {
    nixosConfigurations = lib.genAttrs hosts mkHost;
    nixosModules.default = {
      imports = modulePaths;
    };
    homeManagerModules.default = import ../home/home.nix;
  };
}
