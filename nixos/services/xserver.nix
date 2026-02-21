{
  config,
  lib,
  pkgs,
  ...
}:

{

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Enable the KDE plasma desktop environment
  #services.displayManager.sddm.enable = true;
  #services.desktopManager.plasma6.enable = true;


  programs.niri.enable = true;

  #services.greetd = {
  #  enable = true;
  #  settings = {
  #    default_session = {
  #      command = "${pkgs.tuigreet}/bin/tuigreet \
  #      --time \
  #      --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions \
  #      --remember \
  #      --remember-session";
  #    };
  #  };
  #};

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
