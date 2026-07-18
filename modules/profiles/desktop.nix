{ config, lib, ... }:

let
  cfg = config.northstar.profiles.desktop;
  features = [
    "audio"
    "bluetooth"
    "cups"
    "display"
    "firefox"
    "ghostty"
    "hyprland"
    "kitty"
    "noctalia"
    "power"
    "udiskie"
    "zen-browser"
  ];
in
{
  options.northstar.profiles.desktop.enable = lib.mkEnableOption "desktop Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar.features = lib.genAttrs features (_: {
      enable = true;
    });
  };
}
