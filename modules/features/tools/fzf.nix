{ config, lib, ... }:

let
  cfg = config.northstar.features.fzf;
in
{
  options.northstar.features.fzf.enable = lib.mkEnableOption "FZF fuzzy finder";

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
