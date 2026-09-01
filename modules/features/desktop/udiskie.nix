{ config, lib, ... }:

let
  cfg = config.ctos.features.udiskie;
in
{
  options.ctos.features.udiskie.enable = lib.mkEnableOption "udiskie automounter";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      (
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {

          config = {
            services.udiskie = {
              enable = true;
              tray = "auto";
            };
          };
        }
      )
    ];
  };
}
