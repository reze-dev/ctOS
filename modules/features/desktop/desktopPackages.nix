{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.desktopPackages;
in
{
  options.ctos.features.desktopPackages.enable =
    lib.mkEnableOption "desktop/Wayland packages and services";

  config = lib.mkIf cfg.enable {
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    environment.systemPackages = with pkgs; [
      cliphist
      easyeffects
      fuzzel
      grim
      hyprcursor
      hyprpolkitagent
      kdePackages.dolphin
      kdePackages.okular
      libnotify
      mpv
      obsidian
      openconnect
      qpwgraph
      qview
      satty
      slurp
      wl-clipboard
      zathura
    ];
  };
}
