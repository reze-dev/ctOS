{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.display;
  tuigreet = "${pkgs.tuigreet}/bin/tuigreet";

  # Dynamically discover available Wayland session directories
  waylandSessionDirs =
    lib.optional (config.programs.hyprland.enable or false
    ) "${config.programs.hyprland.package}/share/wayland-sessions"
    ++ lib.optional (config.programs.niri.enable or false
    ) "${config.programs.niri.package}/share/wayland-sessions";

  sessionDirs =
    if waylandSessionDirs != [ ] then
      lib.concatStringsSep ":" waylandSessionDirs
    else
      "/run/current-system/sw/share/wayland-sessions";
in
{
  options.northstar.features.display.enable =
    lib.mkEnableOption "display manager and desktop environment";

  config = lib.mkIf cfg.enable {

    # Tuigreet greeter
    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${tuigreet} --time --remember --remember-session --sessions ${sessionDirs}";
          user = "greeter";
        };
      };
    };

    # this is a life saver.
    # literally no documentation about this anywhere.
    systemd.services.greetd.serviceConfig = {
      Type = "idle";
      StandardInput = "tty";
      StandardOutput = "tty";
      StandardError = "journal"; # Without this errors will spam on screen
      # Without these bootlogs will spam on screen
      TTYReset = true;
      TTYVHangup = true;
      TTYVTDisallocate = true;
    };

    # Keymap
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
