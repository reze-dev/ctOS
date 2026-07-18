{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.packages;
in
{
  options.northstar.features.packages.enable = lib.mkEnableOption "system packages and unfree config";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    services.udisks2.enable = true;
    services.gvfs.enable = true;

    environment.systemPackages = with pkgs; [
      alacritty
      bat
      btop
      eza
      fd
      fzf
      fuzzel
      hyprcursor
      hyprpolkitagent
      jq
      kdePackages.dolphin
      kitty
      libnotify
      mpv
      nitch
      obsidian
      openconnect
      ripgrep
      tmux
      unzip
      wget
      wl-clipboard
      zoxide
    ];
  };
}
