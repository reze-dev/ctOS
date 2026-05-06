{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.northstar.home.noctalia;
  wallpaper = ../../assets/wallpapers/rose-pine-fractal.jpg;
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  options.northstar.home.noctalia.enable = lib.mkEnableOption "Noctalia Wayland shell";

  config = lib.mkIf cfg.enable {
    programs.noctalia-shell = {
      enable = true;
      systemd.enable = false;

      settings = {
        settingsVersion = 0;
        bar = {
          position = "top";
          density = "compact";
          showCapsule = true;
          backgroundOpacity = 0.92;
          widgets = {
            left = [
              { id = "Launcher"; }
              { id = "ActiveWindow"; }
            ];
            center = [
              {
                id = "Workspace";
                hideUnoccupied = false;
              }
            ];
            right = [
              { id = "Network"; }
              { id = "Bluetooth"; }
              { id = "Battery"; }
              {
                id = "Clock";
                formatHorizontal = "HH:mm";
                useMonospacedFont = true;
              }
            ];
          };
        };
        colorSchemes = {
          darkMode = true;
          useWallpaperColors = true;
        };
        wallpaper = {
          enabled = true;
          directory = "${../../assets/wallpapers}";
        };
      };
    };

    home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
      defaultWallpaper = "${wallpaper}";
      wallpapers = { };
    };

  };
}
