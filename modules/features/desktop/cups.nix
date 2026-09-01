{ config, lib, ... }:
let
  cfg = config.ctos.features.cups;
in
{
  options.ctos.features.cups.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable { services.printing.enable = true; };
}
