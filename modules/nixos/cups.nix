{ config, lib, ... }:
let cfg = config.snowflake.cups;
in {
  options.snowflake.cups.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable {
    services.printing.enable = true;
  };
}
