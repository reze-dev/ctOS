{
  config,
  pkgs,
  ...
}:

{
  # Tmux config
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    escapeTime = 10;
    prefix = "C-Space";
    keyMode = "vi";
    sensibleOnTop = true;
    shell = "~/.nix-profile/bin/fish";
    #customPaneNavigationAndResize = false;
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
      set-option -g focus-events on

      # Vim style key binds for panes
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # Resize panes using Alt + arrow keys
      bind -n M-Left resize-pane -L 5    # Shrink pane by 5 cells to the left
      bind -n M-Right resize-pane -R 5   # Expand pane by 5 cells to the right
      bind -n M-Up resize-pane -U 5      # Shrink pane by 5 cells upwards
      bind -n M-Down resize-pane -D 5    # Expand pane by 5 cells downwards

      # Shift arrow to switch windows
      bind -n S-Left  previous-window
      bind -n S-Right next-window

      # Shift Alt vim keys to switch windows
      bind -n M-H previous-window
      bind -n M-L next-window

      # Set split panes to open in same directory
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # Set split panes to follow vim-motions
      set-window-option -g mode-keys vi 
    '';
    disableConfirmationPrompt = true;
    mouse = true;
    newSession = true;
    baseIndex = 1;
    plugins = with pkgs; [
      tmuxPlugins.yank
      tmuxPlugins.cpu
      tmuxPlugins.battery
      {
        plugin = tmuxPlugins.resurrect;
        extraConfig = "set -g @resurrect-strategy-nvim 'session'";
      }
      {
        plugin = tmuxPlugins.continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '60' # minutes
        '';
      }
      {
        plugin = tmuxPlugins.catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'latte'
          set -g @catppuccin_window_status_style "rounded"
          set -g status-right-length 100
          set -g status-left-length 100
          set -g status-left ""
          set -g status-right "#{E:@catppuccin_status_application}"
          set -agF status-right "#{E:@catppuccin_status_cpu}"
          set -ag status-right "#{E:@catppuccin_status_session}"
          set -ag status-right "#{E:@catppuccin_status_uptime}"
          set -agF status-right "#{E:@catppuccin_status_battery}"
        '';
      }
      {
        plugin = tmuxPlugins.vim-tmux-navigator;
        extraConfig = ''
          set -g @vim_navigator_mapping_left "C-h"
          set -g @vim_navigator_mapping_right "C-l"
          set -g @vim_navigator_mapping_up "C-k"
          set -g @vim_navigator_mapping_down "C-j"
          set -g @vim_navigator_mapping_prev ""  # removes the C-\ binding
        '';
      }
      {
        plugin = tmuxPlugins.online-status;
        extraConfig = ''
          set -g @online_icon "ok"
          set -g @offline_icon "nok"
        '';
      }
    ];
  };

}
