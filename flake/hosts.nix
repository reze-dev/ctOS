# Flake-parts module: auto-discover hosts + export module sets
{ inputs, ... }:

let
  lib = inputs.nixpkgs.lib;
  northstar = import ../lib { inherit lib; };
  modulePaths = ../modules |> northstar.scanModules;
  hostsDir = ../hosts;
  hosts = hostsDir |> northstar.discoverHosts;

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
    nixosConfigurations = hosts |> (h: lib.genAttrs h mkHost);
    nixosModules.default = {
      imports = modulePaths;
    };
    homeManagerModules.default = import ../home;
  };
}
