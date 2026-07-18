{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.home.yazi;
in
{
  options.northstar.home.yazi.enable = lib.mkEnableOption "Yazi TUI file manager";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      keymap = {
        manager = {
          prepend_keymap = [
            {
              on = [ "g" "m" ];
              run = "cd /run/media/${config.home.username}";
              desc = "Go to media directory";
            }
          ];
        };
      };
    };
  };
}
