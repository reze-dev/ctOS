{
  config,
  pkgs,
  ...
}:

{
  #Kitty config
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
      background_opacity = 0.75;
      confirm_os_window_close = 0;
      shell = "fish";
    };
    extraConfig = ''
      font_family family='VictorMono Nerd Font' style=SemiBold
      #text_fg_override_threshold 4.5 ratio
    '';
  };
}
