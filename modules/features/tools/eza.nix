{ config, lib, ... }:

let
  cfg = config.ctos.features.eza;
in
{
  options.ctos.features.eza.enable = lib.mkEnableOption "Eza (ls replacement)";

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
