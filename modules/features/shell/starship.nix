{ config, lib, ... }:

let
  cfg = config.northstar.features.starship;
in
{
  options.northstar.features.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.starship = {
            enable = true;
            enableFishIntegration = true;
            enableTransience = true;
          };
        };
      })
    ];
  };
}
