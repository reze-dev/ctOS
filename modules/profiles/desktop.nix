{ config, lib, ... }:

let
  cfg = config.ctos.profiles.desktop;
  features = [
    "audio"
    "bluetooth"
    "desktopPackages"
    "cups"
    "display"
    "firefox"
    "ghostty"
    "hyprland"
    "kitty"
    "niri"
    "power"
    "udiskie"
    "wallpaper"
    "xdg"
    "zen-browser"
  ];
in
{
  options.ctos.profiles.desktop.enable = lib.mkEnableOption "desktop ctOS profile";

  config = lib.mkIf cfg.enable {
    ctos.features =
      features
      |> (
        f:
        lib.genAttrs f (_: {
          enable = true;
        })
      );
  };
}
