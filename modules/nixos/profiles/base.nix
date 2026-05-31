{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.base;
in
{
  options.northstar.profiles.base.enable = lib.mkEnableOption "base Northstar system profile";

  config = lib.mkIf cfg.enable {
    northstar = {
      boot.enable = true;
      env.enable = true;
      fonts.enable = true;
      locales.enable = true;
      networking.enable = true;
      packages.enable = true;
      shells.enable = true;
      ssh.enable = true;
      neovim.enable = true;
    };
  };
}
