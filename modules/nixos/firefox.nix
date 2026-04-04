{ config, lib, ... }:
let cfg = config.snowflake.firefox;
in {
  options.snowflake.firefox.enable = lib.mkEnableOption "Firefox browser";

  config = lib.mkIf cfg.enable {
    programs.firefox.enable = true;
  };
}
