{ config, lib, ... }:
let cfg = config.cryonix.firefox;
in {
  options.cryonix.firefox.enable = lib.mkEnableOption "Firefox browser";

  config = lib.mkIf cfg.enable {
    programs.firefox.enable = true;
  };
}
