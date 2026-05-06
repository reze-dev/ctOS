{ config, lib, ... }:
let
  cfg = config.northstar.power;
in
{
  options.northstar.power.enable = lib.mkEnableOption "power profile and battery services";

  config = lib.mkIf cfg.enable {
    services.power-profiles-daemon.enable = true;
    services.upower.enable = true;
  };
}
