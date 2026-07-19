{ config, lib, ... }:

let
  cfg = config.northstar.features.git;
in
{
  options.northstar.features.git.enable = lib.mkEnableOption "Git user configuration";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      ({ config, lib, ... }: {

        config = {
          programs.git = {
            enable = true;
            settings = {
              user.name = "reze-dev";
              user.email = "25588579+reze-dev@users.noreply.github.com ";
              init.defaultBranch = "main";
            };
          };
        };
      })
    ];
  };
}
