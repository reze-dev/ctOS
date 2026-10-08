{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.polkit;

  hmPolkitModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = [
          pkgs.polkit_gnome
        ];
      };
    };
in
{
  options.ctos.features.polkit.enable = lib.mkEnableOption "Polkit authentication agent";

  config = lib.mkIf cfg.enable {
    security.polkit.enable = true;

    home-manager.sharedModules = [ hmPolkitModule ];
  };
}
