{ config, lib, ... }:

let
  cfg = config.ctos.profiles.gaming;
in
{
  options.ctos.profiles.gaming.enable =
    lib.mkEnableOption "gaming workstation ctOS profile";

  config = lib.mkIf cfg.enable {
    ctos.profiles.desktop.enable = true;
    ctos.features.gaming.enable = true;
  };
}
