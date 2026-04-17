{ config, lib, ... }:
let cfg = config.northstar.bluetooth;
in {
  options.northstar.bluetooth.enable = lib.mkEnableOption "Bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
