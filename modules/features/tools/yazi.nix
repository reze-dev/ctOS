{ config, lib, ... }:

let
  cfg = config.northstar.features.yazi;
in
{
  options.northstar.features.yazi.enable = lib.mkEnableOption "Yazi TUI file manager";

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
            programs.yazi = {
              enable = true;
              enableZshIntegration = true;
              enableFishIntegration = true;
              keymap = {
                manager = {
                  prepend_keymap = [
                    {
                      on = [
                        "g"
                        "m"
                      ];
                      run = "cd /run/media/${config.home.username}";
                      desc = "Go to media directory";
                    }
                  ];
                };
              };
            };
          };
        }
      )
    ];
  };
}
