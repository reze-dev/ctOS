{ config, lib, ... }:

let
  cfg = config.ctos.features.starship;
in
{
  options.ctos.features.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.starship = {
            enable = true;
            enableFishIntegration = true;
            enableZshIntegration = true;
            enableTransience = true;
          };
        };
      })
    ];
  };
}
