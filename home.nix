{
  config,
  pkgs,
  lib,
  importers,
  ...
}:

{
  home.username = lib.mkDefault "nixos";
  home.homeDirectory = lib.mkDefault "/home/nixos";
  home.stateVersion = "25.11";

  home.packages = [
  ];

  home.file = {
  };

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 18;
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  imports = (importers.scanPaths ./home);

  programs.home-manager.enable = true;
}
