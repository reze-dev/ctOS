{
  config,
  pkgs,
  lib,
  homeModulePaths,
  ...
}:

let
  desktopModules = [
    "direnv"
    "eza"
    "fish"
    "fzf"
    "ghostty"
    "git"
    "hyprland"
    "kitty"
    "noctalia"
    "omp"
    "starship"
    "tmux"
    "zoxide"
    "zsh"
  ];
in
{
  imports = homeModulePaths;

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

  northstar.home = lib.genAttrs desktopModules (_: {
    enable = true;
  });
}
