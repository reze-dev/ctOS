{
  config,
  inputs,
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
      grim
      hyprcursor
      hypridle
      hyprlock
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
      superfile
      inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ctos-shell

      # Agent tooling for working on this configuration.
      opencode
    ];
  };
}
