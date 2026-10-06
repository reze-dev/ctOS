{ config, lib, pkgs, ... }:

let
  cfg = config.ctos.features.gtk;

  _ = builtins.trace "GTK MODULE LOADED" (builtins.add 1 1);

  hmGtkModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = with pkgs; [
          nautilus
          yaru-theme
          gsettings-desktop-schemas
        ];

        xdg.configFile."gtk-3.0/settings.ini".text = ''
          [Settings]
          gtk-theme-name = ${cfg.theme}
          gtk-icon-theme-name = ${cfg.theme}
          gtk-font-name = "Maple Mono 11"
          gtk-cursor-theme-name = "Bibata-Modern-Classic"
          gtk-cursor-theme-size = 20
        '';

        xdg.configFile."gtk-4.0/settings.ini".text = ''
          [Settings]
          gtk-theme-name = ${cfg.theme}
          gtk-icon-theme-name = ${cfg.theme}
          gtk-font-name = "Maple Mono 11"
          gtk-cursor-theme-name = "Bibata-Modern-Classic"
          gtk-cursor-theme-size = 20
        '';

        xdg.mimeApps.user = {
          "inode/directory" = "org.gnome.Nautilus.desktop";
        };

        home.sessionVariables = {
          GTK_THEME = cfg.theme;
          ICON_THEME = cfg.theme;
        };
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
    # nixpkgs.overlays = [ (self: super: {
    #   libadwaita = super.libadwaita.override { enableThemes = true; };
    # }) ];

    home-manager.sharedModules = [ hmGtkModule ];
  };
}