{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable the X11 windowing system.
  #services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  #services.xserver.displayManager.gdm.enable = true;
  #services.xserver.desktopManager.gnome.enable = true;

  # Enable the KDE plasma desktop environment
  #services.displayManager.sddm.enable = true;
  #services.desktopManager.plasma6.enable = true;
  environment.etc."greetd/environments".text = ''
    Hyprland (Wayland):start-hyprland
    Niri (Wayland):niri
  '';

  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet \
        --clear \
        --remember \
        --remember-session \
        --time";
      };
    };
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
}
