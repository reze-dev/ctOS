{ config, lib, ... }:

let
  cfg = config.northstar.features.direnv;
in
{
  options.northstar.features.direnv.enable = lib.mkEnableOption "Direnv integration";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.direnv = {
            enable = true;
            nix-direnv.enable = true;
            enableBashIntegration = true;
            enableZshIntegration = true;
          };
        };
      })
    ];
  };
}
