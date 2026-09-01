{ config, lib, ... }:
let
  cfg = config.ctos.features.firefox;
in
{
  options.ctos.features.firefox.enable = lib.mkEnableOption "Firefox browser";

  config = lib.mkIf cfg.enable { programs.firefox.enable = true; };
}
