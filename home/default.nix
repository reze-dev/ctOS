{
  config,
  pkgs,
  lib,
  homeModulePaths,
  ...
}:

{
  home.username = lib.mkDefault "nixos";
  home.homeDirectory = lib.mkDefault "/home/nixos";
  home.stateVersion = "25.11";

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 18;
  };

  imports = homeModulePaths;

  programs.home-manager.enable = true;

  # Enable all cryonix home modules
  cryonix.home = {
    ghostty.enable = true;
    kitty.enable = true;
    fish.enable = true;
    zsh.enable = true;
    git.enable = true;
    tmux.enable = true;
    starship.enable = true;
    omp.enable = true;
    direnv.enable = true;
    fzf.enable = true;
    eza.enable = true;
    zoxide.enable = true;
  };
}
