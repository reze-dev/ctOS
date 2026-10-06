{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.xdg;
in
{
  options.ctos.features.xdg.enable = lib.mkEnableOption "XDG desktop portals";

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;

      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    environment.sessionVariables = {
      GTK_USE_PORTAL = "1";
    };
  };
}
