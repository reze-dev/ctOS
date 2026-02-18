{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common/base.nix
  ];

  home-manager.users.loid = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "loid";
    home.homeDirectory = lib.mkForce "/home/loid";
  };

  networking.hostName = "Yor";

  system.stateVersion = "26.05";
}
