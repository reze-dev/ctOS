{ config, lib, pkgs, ... }:
let cfg = config.cryonix.hyprland;
in {
  options.cryonix.hyprland.enable = lib.mkEnableOption "Hyprland window manager";

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
