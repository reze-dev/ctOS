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
  home.stateVersion = "24.11";

  home.packages = [
    pkgs.hello
  ];

  home.file = {
  };

  home.pointerCursor = {
  gtk.enable = true;
  x11.enable = true;
  package = pkgs.bibata-cursors;
  name = "Bibata-Modern-Classic";
  size = 16;
};

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  imports = (importers.scanPaths ./home);

  programs.home-manager.enable = true;
}
