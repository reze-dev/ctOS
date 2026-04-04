{ config, lib, pkgs, ... }:
let cfg = config.snowflake.hyprland;
in {
  options.snowflake.hyprland.enable = lib.mkEnableOption "Hyprland window manager";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
