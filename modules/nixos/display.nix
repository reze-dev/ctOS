{ config, lib, pkgs, ... }:
let cfg = config.snowflake.display;
in {
  options.snowflake.display.enable = lib.mkEnableOption "display manager and desktop environment";

  config = lib.mkIf cfg.enable {
    # COSMIC desktop + greeter
    services.displayManager.cosmic-greeter.enable = true;
    services.desktopManager.cosmic.enable = true;

    programs.niri.enable = true;

    # Keymap
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };
}
