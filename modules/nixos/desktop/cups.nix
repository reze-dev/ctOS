{ config, lib, ... }:
let cfg = config.northstar.cups;
in {
  options.northstar.cups.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable {
    services.printing.enable = true;
  };
}
