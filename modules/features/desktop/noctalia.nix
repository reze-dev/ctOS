{ config, lib, ... }:

let
  cfg = config.northstar.features.noctalia;

  hmNoctaliaModule =
    {
      config,
      lib,
      inputs,
      ...
    }:
    let
      wallpaper = ../../../assets/wallpapers/rose-pine-fractal.jpg;
    in
    {
      imports = [
        (inputs.noctalia.homeModules.default or inputs.noctalia.homeManagerModules.default or inputs.noctalia.homeManagerModule)
      ];

      config = {
        programs.noctalia = {
          enable = true;
          systemd.enable = false;

          settings = {
            shell = {
              time_format = "{:%H:%M}";
              settings_show_advanced = true;
            };

            bar.main = {
              position = "top";
              thickness = 34;
              background_opacity = 0.70;
              radius = 12;
              margin_h = 180;
              margin_v = 10;
              padding = 14;
              widget_spacing = 6;
              capsule = true;
              start = [
                "launcher"
                "active_window"
              ];
              center = [ "workspaces" ];
              end = [
                "network"
                "bluetooth"
                "battery"
                "clock"
              ];
            };

            widget.workspaces.settings = {
              hide_empty_workspaces = false;
            };

            widget.clock = {
              type = "clock";
              settings = {
                format = "{:%H:%M}";
              };
            };

            theme = {
              mode = "dark";
              source = "wallpaper";
              wallpaper_scheme = "m3-content";
            };

            wallpaper = {
              enabled = true;
              directory = "${../../../assets/wallpapers}";
              default.path = "${wallpaper}";
            };
          };
        };

        home.file.".cache/noctalia/wallpapers.json".text = builtins.toJSON {
          defaultWallpaper = "${wallpaper}";
          wallpapers = { };
        };
      };
    };
in
{
  options.northstar.features.noctalia.enable = lib.mkEnableOption "Noctalia Wayland shell";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ hmNoctaliaModule ];
  };
}
