{ config, lib, ... }:
let
  cfg = config.ctos.features.bluetooth;
in
{
  options.ctos.features.bluetooth.enable = lib.mkEnableOption "Bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
