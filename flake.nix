{
  description = "Snow Flakes with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    tmux-powerkit.url = "github:fabioluciano/tmux-powerkit";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      myLib = import ./lib/importers.nix { inherit lib; };
    in
    {
      nixosConfigurations =
        let
          # Get all subdirectories in ./hosts, excluding "common"
          hosts = lib.filterAttrs
            (name: type: type == "directory" && name != "common")
            (builtins.readDir ./hosts);
            
          mkHost = hostName: lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
              importers = myLib;
            };
            modules = [
              ./hosts/${hostName}/configuration.nix
              ./hosts/${hostName}/hardware-configuration.nix
              inputs.disko.nixosModules.disko
              ./hosts/common/disko-config.nix
              { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
            ];
          };
        in
          lib.mapAttrs (name: _: mkHost name) hosts;
    };
}
