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
      bat
      btop
      cliphist
      easyeffects
      eza
      fd
      fzf
      fuzzel
      grim
      hyprcursor
      hyprpolkitagent
      jq
      kdePackages.dolphin
      kdePackages.okular
      libnotify
      mpv
      nitch
      obsidian
      openconnect
      qpwgraph
      qview
      ripgrep
      satty
      slurp
      tmux
      unzip
      wget
      wl-clipboard
      zathura
      zoxide
    ];
  };
}
