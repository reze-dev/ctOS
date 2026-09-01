{ config, lib, ... }:

let
  cfg = config.ctos.features.zoxide;
in
{
  options.ctos.features.zoxide.enable = lib.mkEnableOption "Zoxide (cd replacement)";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.zoxide = {
            enableFishIntegration = true;
            enableZshIntegration = true;
          };
        };
      })
    ];
  };
}
