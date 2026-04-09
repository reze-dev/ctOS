{ config, lib, ... }:
let cfg = config.cryonix.cups;
in {
  options.cryonix.cups.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable {
    services.printing.enable = true;
  };
}
