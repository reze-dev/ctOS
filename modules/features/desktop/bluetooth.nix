{ config, lib, ... }:
let
  cfg = config.northstar.features.bluetooth;
in
{
  options.northstar.features.bluetooth.enable = lib.mkEnableOption "Bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
