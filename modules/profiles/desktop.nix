{ config, lib, ... }:

let
  cfg = config.northstar.profiles.desktop;
  features = [
    "audio"
    "bluetooth"
    "caelestia"
    "cups"
    "display"
    "firefox"
    "ghostty"
    "hyprland"
    "kitty"
    "niri"
    "power"
    "udiskie"
    "xdg"
    "zen-browser"
  ];
in
{
  options.northstar.profiles.desktop.enable = lib.mkEnableOption "desktop Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar.features = features |> (f: lib.genAttrs f (_: { enable = true; }));
  };
}
