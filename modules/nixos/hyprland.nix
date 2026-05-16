{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.hyprland;
in
{
  options.northstar.hyprland.enable = lib.mkEnableOption "Hyprland window manager";

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      xwayland.enable = true;
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
