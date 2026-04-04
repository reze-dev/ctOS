{ config, lib, ... }:
let cfg = config.snowflake.bluetooth;
in {
  options.snowflake.bluetooth.enable = lib.mkEnableOption "Bluetooth support";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
  };
}
