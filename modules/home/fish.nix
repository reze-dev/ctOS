{ config, lib, pkgs, ... }:
let cfg = config.snowflake.home.fish;
in {
  options.snowflake.home.fish.enable = lib.mkEnableOption "Fish shell configuration";

  config = lib.mkIf cfg.enable {
    xdg.configFile."fish/themes/Rosé Pine Auto.theme".source = "${
      pkgs.fetchFromGitHub {
        owner = "rose-pine";
        repo = "fish";
        rev = "127a990e5ad4688118c950123787fb0686afa4c8";
        sha256 = "3heI6nhItw5WfKGQT1FRQKfv+lONyn+DzwYjYqJjzLE=";
      }
    }/themes/Rosé Pine Auto.theme";

    programs.fish = {
      enable = true;
      shellInit = ''
        set -U fish_greeting
        set -x COLORTERM truecolor
        set -gx PATH $HOME/.local/bin $PATH
        set -gx PATH (go env GOPATH)/bin $PATH
        set -gx PATH $HOME/.config/emacs/bin $PATH
        set -gx DIRENV_LOG_FORMAT ""
        fish_config theme choose nord
      '';
      interactiveShellInit = ''
        set -x TERM xterm-256color
      '';
      functions = {
        starship_transient_prompt_func = "starship module character";
      };
      shellAliases = {
        cat = "bat";
        ll = "eza -l --icons";
        ls = "eza --icons";
        tree = "eza -T --icons";
        la = "eza -la --icons";
        lo = "eza -l -o --icons";
        vim = "nvim";
        tmux = "tmux -u";
        butt = "but";
      };
      shellInitLast = ''
        fzf --fish | source
        zoxide init --cmd cd fish |source
        direnv hook fish | source
      '';
    };
  };
}
