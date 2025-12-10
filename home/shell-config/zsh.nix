{
  config,
  pkgs,
  lib,
  ...
}:

{
  # Zsh Config
  programs.zsh = {
    enable = true;
    antidote = {
      enable = true;
      plugins = [
        "Aloxaf/fzf-tab"
        #"romkatv/powerlevel10k"
        "zsh-users/zsh-syntax-highlighting"
      ];
      useFriendlyNames = true;
    };
    initContent = lib.mkMerge [
      (lib.mkOrder 550 ''
        EDITOR=nvim
        export GPG_TTY=$(tty)
        export PATH=$HOME/.config/emacs/bin:$PATH
        export PATH=$(go env GOPATH)/bin:$PATH
        #export PATH=$HOME/zig:$PATH
      '')
      (lib.mkOrder 1000 ''
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' menu no
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --icons $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always --icons $realpath'
        eval "$(fzf --zsh)"
        eval "$(zoxide init --cmd cd zsh)"
        eval "$(direnv hook zsh)"
      '')
    ];
    completionInit = ''
      autoload -U compinit && compinit
    '';

    autosuggestion = {
      enable = true;
    };
    defaultKeymap = "emacs";
    enableCompletion = true;
    history = {
      append = true;
      expireDuplicatesFirst = true;
      extended = true;
      ignoreAllDups = true;
      ignoreDups = true;
      ignoreSpace = true;
      save = 5000;
      share = true;
      size = 5000;
      path = "$HOME/.histfile";
    };
    sessionVariables = {
      COLORTERM = "24bit";
      TERM = "xterm-256color";
    };
    shellAliases = {
      cat = "bat";
      ll = "eza -l --icons --no-permissions";
      ls = "eza --icons";
      tree = "eza -T --icons";
      la = "eza -la --icons";
      lo = "eza -l -o --icons";
      vim = "nvim";
    };
  };
}
