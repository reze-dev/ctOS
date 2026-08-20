# Flake-parts module: auto-discover hosts + export module sets
{ inputs, ... }:

let
  lib = inputs.nixpkgs.lib;
  northstar = import ../lib/core.nix { inherit lib; };
  modulePaths = northstar.scanModules ../modules;
  hostsDir = ../hosts;
  hosts = northstar.discoverHosts hostsDir;

  mkHost =
    hostName:
    lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs northstar;
      };
      modules = northstar.mkHostModules {
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
