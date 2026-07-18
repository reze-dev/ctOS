{ config, lib, ... }:

let
  cfg = config.northstar.profiles.base;
  features = [
    "boot"
    "env"
    "fonts"
    "locales"
    "networking"
    "neovim"
    "packages"
    "shells"
    "ssh"
  ];
in
{
  options.northstar.profiles.base.enable = lib.mkEnableOption "base Northstar system profile";

  config = lib.mkIf cfg.enable {
    northstar.features = lib.genAttrs features (_: {
      enable = true;
    });
  };
}
