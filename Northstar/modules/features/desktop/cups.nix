{ config, lib, ... }:
let
  cfg = config.northstar.features.cups;
in
{
  options.northstar.features.cups.enable = lib.mkEnableOption "CUPS printing";

  config = lib.mkIf cfg.enable { services.printing.enable = true; };
}
