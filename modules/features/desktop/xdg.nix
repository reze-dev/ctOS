{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.xdg;

  hmXdgModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        xdg.mimeApps = {
          enable = true;
          associations.removed = {
            "text/html" = [ "firefox.desktop" ];
            "x-scheme-handler/http" = [ "firefox.desktop" ];
            "x-scheme-handler/https" = [ "firefox.desktop" ];
            "x-scheme-handler/about" = [ "firefox.desktop" ];
            "x-scheme-handler/unknown" = [ "firefox.desktop" ];
          };
          associations.added = {
            "text/html" = [ "zen-beta.desktop" ];
            "x-scheme-handler/http" = [ "zen-beta.desktop" ];
            "x-scheme-handler/https" = [ "zen-beta.desktop" ];
          };
          defaultApplications = {
            # File manager / Directories
            "inode/directory" = [ "org.kde.dolphin.desktop" ];

            # Web / URLs
            "text/html" = [ "zen-beta.desktop" ];
            "x-scheme-handler/http" = [ "zen-beta.desktop" ];
            "x-scheme-handler/https" = [ "zen-beta.desktop" ];
            "x-scheme-handler/about" = [ "zen-beta.desktop" ];
            "x-scheme-handler/unknown" = [ "zen-beta.desktop" ];

            # Images (qView primary)
            "image/png" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" "org.kde.dolphin.desktop" ];
            "image/jpeg" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" "org.kde.dolphin.desktop" ];
            "image/webp" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" "org.kde.dolphin.desktop" ];
            "image/gif" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" "org.kde.dolphin.desktop" ];
            "image/svg+xml" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" "zen-beta.desktop" ];
            "image/bmp" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" ];
            "image/tiff" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" ];
            "image/avif" = [ "com.interversehq.qView.desktop" "org.gnome.Loupe.desktop" "org.kde.gwenview.desktop" ];

            # Video & Audio (MPV)
            "video/mp4" = [ "mpv.desktop" ];
            "video/mkv" = [ "mpv.desktop" ];
            "video/webm" = [ "mpv.desktop" ];
            "video/x-matroska" = [ "mpv.desktop" ];
            "video/avi" = [ "mpv.desktop" ];
            "video/quicktime" = [ "mpv.desktop" ];
            "audio/mpeg" = [ "mpv.desktop" ];
            "audio/flac" = [ "mpv.desktop" ];
            "audio/wav" = [ "mpv.desktop" ];
            "audio/ogg" = [ "mpv.desktop" ];

            # PDF & Documents (Okular primary, Zathura terminal fallback, Zen)
            "application/pdf" = [ "org.kde.okular.desktop" "org.pwmt.zathura.desktop" "zen-beta.desktop" ];
            "application/epub+zip" = [ "org.kde.okular.desktop" "org.pwmt.zathura.desktop" ];
            "application/postscript" = [ "org.kde.okular.desktop" "org.pwmt.zathura.desktop" ];

            # Archives (Ark / Dolphin)
            "application/zip" = [ "org.kde.ark.desktop" "org.kde.dolphin.desktop" ];
            "application/x-tar" = [ "org.kde.ark.desktop" "org.kde.dolphin.desktop" ];
            "application/x-7z-compressed" = [ "org.kde.ark.desktop" "org.kde.dolphin.desktop" ];
            "application/x-compressed-tar" = [ "org.kde.ark.desktop" "org.kde.dolphin.desktop" ];

            # Plain Text, Markdown & Code (Zed / Ghostty)
            "text/plain" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "text/markdown" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "text/x-nix" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "text/css" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "text/x-python" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "application/json" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "application/yaml" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "application/toml" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
            "application/xml" = [ "dev.zed.Zed.desktop" "ghostty.desktop" ];
          };
        };

        xdg.configFile."menus/applications.menu".text = ''
          <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
           "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
          <Menu>
            <Name>Applications</Name>
            <DefaultAppDirs/>
            <DefaultDirectoryDirs/>
            <DefaultMergeDirs/>
          </Menu>
        '';

        home.sessionVariables = {
          GTK_USE_PORTAL = "1";
        };
      };
    };
in
{
  options.northstar.features.xdg.enable = lib.mkEnableOption "XDG desktop portals and MIME default application associations";

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        kdePackages.xdg-desktop-portal-kde
        xdg-desktop-portal-gtk
      ];
      config = {
        common = {
          default = [
            "kde"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
        niri = {
          default = [
            "kde"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
        hyprland = {
          default = [
            "hyprland"
            "kde"
            "gtk"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "kde" ];
        };
      };
    };

    home-manager.sharedModules = [ hmXdgModule ];

    environment.sessionVariables = {
      GTK_USE_PORTAL = "1";
    };
  };
}
