{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.xdg;

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
            "inode/directory" = [ "org.gnome.Nautilus.desktop" ];

            # Web / URLs
            "text/html" = [ "zen-beta.desktop" ];
            "x-scheme-handler/http" = [ "zen-beta.desktop" ];
            "x-scheme-handler/https" = [ "zen-beta.desktop" ];
            "x-scheme-handler/about" = [ "zen-beta.desktop" ];
            "x-scheme-handler/unknown" = [ "zen-beta.desktop" ];

            # Images (qView primary, GNOME Loupe, Nautilus fallback)
            "image/png" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/jpeg" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/webp" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/gif" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/svg+xml" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "zen-beta.desktop"
            ];
            "image/bmp" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/tiff" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "image/avif" = [
              "com.interversehq.qView.desktop"
              "org.gnome.Loupe.desktop"
              "org.gnome.Nautilus.desktop"
            ];

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

            # PDF & Documents (Evince primary, Zathura terminal fallback, Zen)
            "application/pdf" = [
              "org.gnome.Evince.desktop"
              "org.pwmt.zathura.desktop"
              "zen-beta.desktop"
            ];
            "application/epub+zip" = [
              "org.gnome.Evince.desktop"
              "org.pwmt.zathura.desktop"
            ];
            "application/postscript" = [
              "org.gnome.Evince.desktop"
              "org.pwmt.zathura.desktop"
            ];

            # Archives (GNOME Archive Manager / Nautilus)
            "application/zip" = [
              "org.gnome.FileRoller.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "application/x-tar" = [
              "org.gnome.FileRoller.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "application/x-7z-compressed" = [
              "org.gnome.FileRoller.desktop"
              "org.gnome.Nautilus.desktop"
            ];
            "application/x-compressed-tar" = [
              "org.gnome.FileRoller.desktop"
              "org.gnome.Nautilus.desktop"
            ];

            # Plain Text, Markdown & Code (Emacs / Neovim)
            "text/plain" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "text/markdown" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "text/x-nix" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "text/css" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "text/x-python" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "application/json" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "application/yaml" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "application/toml" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
            "application/xml" = [
              "emacs.desktop"
              "nvim.desktop"
            ];
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
  options.ctos.features.xdg.enable =
    lib.mkEnableOption "XDG desktop portals and MIME default application associations";

  config = lib.mkIf cfg.enable {
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
        kdePackages.xdg-desktop-portal-kde
      ];
      config = {
        common = {
          default = [
            "gtk"
            "kde"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
        niri = {
          default = [
            "gtk"
            "kde"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
        hyprland = {
          default = [
            "hyprland"
            "gtk"
            "kde"
          ];
          "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        };
      };
    };

    home-manager.sharedModules = [ hmXdgModule ];

    environment.sessionVariables = {
      GTK_USE_PORTAL = "1";
    };
  };
}
