{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.username = lib.mkDefault "nixos";
  home.homeDirectory = lib.mkDefault "/home/nixos";
  home.stateVersion = "26.11";

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 20;
  };

  programs.home-manager.enable = true;

  xdg.configFile."fastfetch/config.jsonc".source = ../shell/config/fastfetch/config.jsonc;
  xdg.configFile."fastfetch/dedsec.txt".source = ../shell/config/fastfetch/dedsec.txt;
}
