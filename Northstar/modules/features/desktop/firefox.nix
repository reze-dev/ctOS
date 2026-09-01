{ config, lib, ... }:
let
  cfg = config.northstar.features.firefox;
in
{
  options.northstar.features.firefox.enable = lib.mkEnableOption "Firefox browser";

  config = lib.mkIf cfg.enable { programs.firefox.enable = true; };
}
