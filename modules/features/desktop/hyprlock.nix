{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.hyprlock;

  hmHyprlockModule =
    { ... }:
    {
      config = {
        xdg.configFile."hypr/hyprlock.conf".source = ../../../shell/config/hypr/hyprlock.conf;
        xdg.configFile."hypr/hypridle.conf".source = ../../../shell/config/hypr/hypridle.conf;
      };
    };
in
{
  options.ctos.features.hyprlock.enable = lib.mkEnableOption "ctOS lockscreen and idle daemon";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      hyprlock
      hypridle
    ];

    security.pam.services.hyprlock = { };

    services.hypridle.enable = true;

    home-manager.sharedModules = [ hmHyprlockModule ];
  };
}
