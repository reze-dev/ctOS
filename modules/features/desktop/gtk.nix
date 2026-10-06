{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.gtk;

  hmGtkModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        gtk = {
          enable = true;

          theme = {
            name = cfg.theme;
            package = pkgs.yaru-theme;
          };

          iconTheme = {
            name = "Yaru";
            package = pkgs.yaru-theme;
          };
        };

        dconf.settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = cfg.theme;
            icon-theme = "Yaru";
          };
        };

        home.packages = [
          pkgs.nautilus
        ];
      };
    };
in
{
  options.ctos.features.gtk = {
    enable = lib.mkEnableOption "GTK theming and file manager";

    theme = lib.mkOption {
      type = lib.types.str;
      default = "Yaru";
      description = "GTK theme name";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ hmGtkModule ];
  };
}
