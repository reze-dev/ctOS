{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.home.udiskie;
in
{
  options.northstar.home.udiskie.enable = lib.mkEnableOption "udiskie automounter";

  config = lib.mkIf cfg.enable {
    services.udiskie = {
      enable = true;
      tray = "auto";
    };
  };
}
