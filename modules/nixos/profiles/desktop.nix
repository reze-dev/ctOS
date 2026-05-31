{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.desktop;
in
{
  options.northstar.profiles.desktop.enable = lib.mkEnableOption "desktop Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar = {
      audio.enable = true;
      bluetooth.enable = true;
      cups.enable = true;
      display.enable = true;
      firefox.enable = true;
      hyprland.enable = true;
      power.enable = true;
      zen-browser.enable = true;
    };
  };
}
