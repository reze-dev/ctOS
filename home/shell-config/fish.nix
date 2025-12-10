{
  config,
  pkgs,
  ...
}:

{
  xdg.configFile."fish/themes/Rosé Pine.theme".source = "${
    pkgs.fetchFromGitHub {
      owner = "rose-pine";
      repo = "fish";
      rev = "38aab5baabefea1bc7e560ba3fbdb53cb91a6186";
      sha256 = "bSGGksL/jBNqVV0cHZ8eJ03/8j3HfD9HXpDa8G/Cmi8=";
    }
  }/themes/Rosé Pine.theme";

  programs.fish = {
    enable = true;
    shellInit = ''
      set -U fish_greeting
      set -x COLORTERM truecolor
      set -gx PATH $HOME/.local/bin $PATH
      set -gx PATH (go env GOPATH)/bin $PATH
      set -gx PATH $HOME/.config/emacs/bin $PATH
      #set -gx PATH $HOME/zig $PATH
      fish_config theme choose 'Rosé Pine'
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
    };
    shellInitLast = ''
      fzf --fish | source
      zoxide init --cmd cd fish |source
      direnv hook fish | source
    '';
  };
}
