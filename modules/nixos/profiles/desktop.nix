{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.desktop;
  modules = [
    "audio"
    "bluetooth"
    "cups"
    "display"
    "firefox"
    "hyprland"
    "power"
    "zen-browser"
  ];
in
{
  options.northstar.profiles.desktop.enable = lib.mkEnableOption "desktop Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar = lib.genAttrs modules (_: {
      enable = true;
    });
  };
}
