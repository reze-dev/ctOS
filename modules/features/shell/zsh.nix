{ config, lib, ... }:

let
  cfg = config.northstar.features.zsh;
in
{
  options.northstar.features.zsh.enable = lib.mkEnableOption "Zsh shell configuration";

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
            programs.zsh = {
              enable = true;
              antidote = {
                enable = true;
                plugins = [
                  "Aloxaf/fzf-tab"
                  "zsh-users/zsh-syntax-highlighting"
                  "olets/zsh-transient-prompt"
                ];
                useFriendlyNames = true;
              };
              initContent = lib.mkMerge [
                (lib.mkOrder 550 ''
                  EDITOR=nvim
                  export GPG_TTY=$(tty)
                  export PATH=$HOME/.config/emacs/bin:$PATH
                  export PATH=$(go env GOPATH)/bin:$PATH
                  export DIRENV_LOG_FORMAT=""
                '')
                (lib.mkOrder 1000 ''
                  zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
                  zstyle ':completion:*' menu no
                  zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
                  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always --icons always $realpath'
                  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza --color=always --icons always $realpath'
                  eval "$(fzf --zsh)"
                  eval "$(zoxide init --cmd cd zsh)"
                '')
                (lib.mkOrder 1500 ''
                  TRANSIENT_PROMPT_PROMPT='$(starship prompt --terminal-width="$COLUMNS" --keymap="''${KEYMAP:-}" --status="''${STARSHIP_CMD_STATUS}" --pipestatus="''${STARSHIP_PIPE_STATUS[*]}" --cmd-duration="''${STARSHIP_DURATION:-}" --jobs="''${STARSHIP_JOBS_COUNT}")'
                  TRANSIENT_PROMPT_RPROMPT='$(starship prompt --right --terminal-width="$COLUMNS" --keymap="''${KEYMAP:-}" --status="''${STARSHIP_CMD_STATUS}" --pipestatus="''${STARSHIP_PIPE_STATUS[*]}" --cmd-duration="''${STARSHIP_DURATION:-}" --jobs="''${STARSHIP_JOBS_COUNT}")'
                  TRANSIENT_PROMPT_TRANSIENT_PROMPT='$(starship module character)'
                '')
              ];
              completionInit = ''
                autoload -U compinit && compinit
              '';
              autosuggestion.enable = true;
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
                butt = "but";
              };
            };
          };
        }
      )
    ];
  };
}
