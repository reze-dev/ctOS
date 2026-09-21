{ config, lib, ... }:

let
  cfg = config.ctos.features.kitty;
in
{
  options.ctos.features.kitty.enable = lib.mkEnableOption "Kitty terminal";

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
            programs.kitty = {
              enable = true;
              font.name = "MonoLisa";
              font.size = 13;
              shellIntegration = {
                enableFishIntegration = true;
                enableZshIntegration = true;
              };
              settings = {
                background_opacity = "0.85";
                confirm_os_window_close = 0;
                shell = "fish";
              };
              extraConfig = ''
                include ${../../../shell/config/kitty/themes/monoglow.conf}

                font_family family='MonoLisa' style=Regular features="+calt +liga +salt"
                bold_font        auto
                italic_font family='MonoLisa Italic' style=Regular features="+calt +liga +salt +ss02"
                bold_italic_font auto
                window_padding_width 12
                hide_window_decorations yes
                map ctrl+shift+h no_op
              '';
            };
          };
        }
      )
    ];
  };
}
