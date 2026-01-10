{
  description = "Snow Flakes with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      # Ensure Home Manager uses the same nixpkgs as your configuration
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rose-pine-hyprcursor.url = "github:ndom91/rose-pine-hyprcursor";
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    awww.url = "git+https://codeberg.org/LGFae/awww";
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
      nixosConfigurations = {
        Yor = lib.nixosSystem {
          specialArgs = { inherit inputs; importers = myLib; };
          inherit system;
          modules = [
            ./hosts/Yor/configuration.nix
            ./hosts/Yor/hardware-configuration.nix
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        };
      };
    };
}
