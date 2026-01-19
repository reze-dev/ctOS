{
  config,
  lib,
  pkgs,
  inputs,
  importers,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
  ] ++ (importers.scanPaths ../../nixos);

  home-manager.extraSpecialArgs = { inherit inputs importers; };
  home-manager.users.loid = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "loid";
    home.homeDirectory = lib.mkForce "/home/loid";
  };

  # Enable flakes and other features
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  system.stateVersion = "26.05";
}
