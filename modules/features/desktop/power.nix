{ config, lib, ... }:
let
  cfg = config.northstar.features.power;
in
{
  options.northstar.features.power.enable = lib.mkEnableOption "power profile and battery services";

  config = lib.mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
  };
}
