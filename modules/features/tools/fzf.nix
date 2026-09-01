{ config, lib, ... }:

let
  cfg = config.ctos.features.fzf;
in
{
  options.ctos.features.fzf.enable = lib.mkEnableOption "FZF fuzzy finder";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.fzf = {
            enableFishIntegration = true;
            enableZshIntegration = true;
          };
        };
      })
    ];
  };
}
