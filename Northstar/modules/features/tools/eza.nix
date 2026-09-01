{ config, lib, ... }:

let
  cfg = config.northstar.features.eza;
in
{
  options.northstar.features.eza.enable = lib.mkEnableOption "Eza (ls replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.eza = {
            enableFishIntegration = true;
            enableZshIntegration = true;
          };
        };
      })
    ];
  };
}
