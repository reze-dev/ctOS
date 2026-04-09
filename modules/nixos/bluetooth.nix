{ config, lib, ... }:
let cfg = config.cryonix.bluetooth;
in {
  options.cryonix.bluetooth.enable = lib.mkEnableOption "Bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
