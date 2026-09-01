{ config, lib, ... }:

let
  cfg = config.northstar.profiles.gaming;
in
{
  options.northstar.profiles.gaming.enable =
    lib.mkEnableOption "gaming workstation Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar.profiles.desktop.enable = true;
    northstar.features.gaming.enable = true;
  };
}
