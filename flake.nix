{
  description = "Snow Flakes with Home Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    awww.url = "git+https://codeberg.org/LGFae/awww";
    tmux-powerkit.url = "github:fabioluciano/tmux-powerkit";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    crane.url = "github:ipetkov/crane";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ ./parts/nixos.nix ./parts/installer.nix ./parts/go-installer.nix ./parts/rust-installer.nix ];
    };
}
