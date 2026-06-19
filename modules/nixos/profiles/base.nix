{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.base;
  modules = [
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
    northstar = lib.genAttrs modules (_: {
      enable = true;
    });
  };
}
