{ config, lib, ... }:
let cfg = config.northstar.firefox;
in {
  options.northstar.firefox.enable = lib.mkEnableOption "Firefox browser";

  config = lib.mkIf cfg.enable {
    programs.firefox.enable = true;
  };
}
