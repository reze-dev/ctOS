{ config, lib, pkgs, ... }:
let cfg = config.cryonix.home.kitty;
in {
  options.cryonix.home.kitty.enable = lib.mkEnableOption "Kitty terminal";

  config = lib.mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      font.name = "Victor Mono Nerd Font";
      font.size = 13;
      shellIntegration = {
        enableFishIntegration = true;
        enableZshIntegration = true;
      };
      themeFile = "rose-pine";
      settings = {
        background_opacity = 0.85;
        confirm_os_window_close = 0;
        shell = "fish";
      };
      extraConfig = ''
        font_family family='VictorMono Nerd Font' style=SemiBold
        hide_window_decorations yes
      '';
    };
  };
}
