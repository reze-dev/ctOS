{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.niri;

  hmNiriModule =
    {
      config,
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      niriEnabled = osConfig.northstar.features.niri.enable or false;
      noctaliaEnabled = osConfig.northstar.features.noctalia.enable or false;
      actions = config.lib.niri.actions;
    in
    {
      config = lib.mkIf niriEnabled {
        home.packages = with pkgs; [
          alacritty
          brightnessctl
          fuzzel
          playerctl
          swappy
          xwayland-satellite
        ];

        programs.niri = {
          settings = {
            # Autostart processes
            spawn-at-startup = lib.optionals noctaliaEnabled [
              { command = [ "noctalia" ]; }
            ];

            # Input configuration
            input = {
              keyboard = {
                repeat-delay = 600;
                repeat-rate = 25;
                track-layout = "global";
              };
              touchpad = {
                tap = true;
                natural-scroll = true;
                dwt = true;
              };
              focus-follows-mouse = {
                enable = true;
                max-scroll-amount = "0%";
              };
              warp-mouse-to-focus = {
                enable = true;
              };
            };

            # Cursor settings
            cursor = {
              theme = "Bibata-Modern-Classic";
              size = 20;
            };

            # Layout & Visual Styling
            layout = {
              gaps = 12;
              center-focused-column = "on-overflow";

              preset-column-widths = [
                { proportion = 0.33333; }
                { proportion = 0.5; }
                { proportion = 0.66667; }
              ];

              default-column-width = { proportion = 0.5; };

              # Focus ring (Active window outline)
              focus-ring = {
                enable = true;
                width = 2;
                active.color = "#7dcfff";
                inactive.color = "#414868";
              };

              # Window border styling
              border = {
                enable = true;
                width = 2;
                active.color = "#bb9af7";
                inactive.color = "#24283b";
              };

              # Window drop shadows
              shadow = {
                enable = true;
                color = "#00000070";
                softness = 30;
                spread = 5;
                offset = {
                  x = 0;
                  y = 5;
                };
              };

              # Column insertion indicator
              insert-hint = {
                enable = true;
              };
            };

            # Smooth animations
            animations = {
              enable = true;
              slowdown = 1.0;
            };

            # Window rules: Rounded corners, transparency, borders & shadows
            window-rules = [
              # Global window rounding and clipping
              {
                clip-to-geometry = true;
                geometry-corner-radius = {
                  top-left = 12.0;
                  top-right = 12.0;
                  bottom-left = 12.0;
                  bottom-right = 12.0;
                };
                draw-border-with-background = false;
              }
              # Terminal window transparency
              {
                matches = [
                  { app-id = "^(ghostty|kitty|alacritty|foot|org\\.wezfurlong\\.wezterm)$"; }
                ];
                opacity = 0.92;
              }
              # Floating popups/dialog window rule
              {
                matches = [
                  { is-floating = true; }
                ];
                shadow.enable = true;
              }
            ];

            # Layer rules for notification bars / shell overlays
            layer-rules = [
              {
                matches = [
                  { namespace = "^noctalia.*$"; }
                  { namespace = "^waybar$"; }
                ];
                shadow.enable = true;
              }
            ];

            # Comprehensive Keybindings
            binds = {
              # Application Launchers
              "Mod+Return".action = actions.spawn "kitty";
              "Mod+Shift+Return".action = actions.spawn "ghostty";
              "Mod+D".action = actions.spawn "fuzzel";
              "Mod+Space".action = actions.spawn "fuzzel";
              "Mod+E".action = actions.spawn "kitty" "-e" "yazi";
              "Mod+B".action = actions.spawn "zen";

              # Window & Column Controls
              "Mod+Q".action = actions.close-window;
              "Mod+V".action = actions.toggle-window-floating;
              "Mod+Shift+V".action = actions.switch-focus-between-floating-and-tiling;
              "Mod+F".action = actions.maximize-column;
              "Mod+Shift+F".action = actions.fullscreen-window;
              "Mod+C".action = actions.center-column;
              "Mod+W".action = actions.toggle-column-tabbed-display;

              # Focus Movement
              "Mod+Left".action = actions.focus-column-left;
              "Mod+H".action = actions.focus-column-left;
              "Mod+Right".action = actions.focus-column-right;
              "Mod+L".action = actions.focus-column-right;
              "Mod+Up".action = actions.focus-window-or-workspace-up;
              "Mod+K".action = actions.focus-window-or-workspace-up;
              "Mod+Down".action = actions.focus-window-or-workspace-down;
              "Mod+J".action = actions.focus-window-or-workspace-down;

              "Mod+Home".action = actions.focus-column-first;
              "Mod+End".action = actions.focus-column-last;

              # Moving Columns & Windows
              "Mod+Shift+Left".action = actions.move-column-left;
              "Mod+Shift+H".action = actions.move-column-left;
              "Mod+Shift+Right".action = actions.move-column-right;
              "Mod+Shift+L".action = actions.move-column-right;
              "Mod+Shift+Up".action = actions.move-window-up-or-to-workspace-up;
              "Mod+Shift+K".action = actions.move-window-up-or-to-workspace-up;
              "Mod+Shift+Down".action = actions.move-window-down-or-to-workspace-down;
              "Mod+Shift+J".action = actions.move-window-down-or-to-workspace-down;

              "Mod+Shift+Home".action = actions.move-column-to-first;
              "Mod+Shift+End".action = actions.move-column-to-last;

              # Workspace Focus
              "Mod+1".action = actions.focus-workspace 1;
              "Mod+2".action = actions.focus-workspace 2;
              "Mod+3".action = actions.focus-workspace 3;
              "Mod+4".action = actions.focus-workspace 4;
              "Mod+5".action = actions.focus-workspace 5;
              "Mod+6".action = actions.focus-workspace 6;
              "Mod+7".action = actions.focus-workspace 7;
              "Mod+8".action = actions.focus-workspace 8;
              "Mod+9".action = actions.focus-workspace 9;

              # Move to Workspace
              "Mod+Shift+1".action = actions.move-column-to-index 1;
              "Mod+Shift+2".action = actions.move-column-to-index 2;
              "Mod+Shift+3".action = actions.move-column-to-index 3;
              "Mod+Shift+4".action = actions.move-column-to-index 4;
              "Mod+Shift+5".action = actions.move-column-to-index 5;
              "Mod+Shift+6".action = actions.move-column-to-index 6;
              "Mod+Shift+7".action = actions.move-column-to-index 7;
              "Mod+Shift+8".action = actions.move-column-to-index 8;
              "Mod+Shift+9".action = actions.move-column-to-index 9;

              "Mod+U".action = actions.focus-workspace-down;
              "Mod+I".action = actions.focus-workspace-up;
              "Mod+Shift+U".action = actions.move-column-to-workspace-down;
              "Mod+Shift+I".action = actions.move-column-to-workspace-up;

              # Sizing Controls
              "Mod+R".action = actions.switch-preset-column-width;
              "Mod+Shift+R".action = actions.switch-preset-window-height;
              "Mod+Ctrl+R".action = actions.reset-window-height;
              "Mod+Minus".action = actions.set-column-width "-10%";
              "Mod+Equal".action = actions.set-column-width "+10%";
              "Mod+Shift+Minus".action = actions.set-window-height "-10%";
              "Mod+Shift+Equal".action = actions.set-window-height "+10%";

              # Tab consume & expel
              "Mod+BracketLeft".action = actions.consume-or-expel-window-left;
              "Mod+BracketRight".action = actions.consume-or-expel-window-right;

              # Media & Hardware Keys
              "XF86AudioRaiseVolume".action = actions.spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
              "XF86AudioLowerVolume".action = actions.spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
              "XF86AudioMute".action = actions.spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
              "XF86AudioMicMute".action = actions.spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
              "XF86MonBrightnessUp".action = actions.spawn "brightnessctl" "set" "10%+";
              "XF86MonBrightnessDown".action = actions.spawn "brightnessctl" "set" "10%-";
              "XF86AudioPlay".action = actions.spawn "playerctl" "play-pause";
              "XF86AudioNext".action = actions.spawn "playerctl" "next";
              "XF86AudioPrev".action = actions.spawn "playerctl" "previous";

              # Screenshot & Overview
              "Print".action.screenshot = [ ];
              "Ctrl+Print".action.screenshot-screen = [ ];
              "Alt+Print".action.screenshot-window = [ ];
              "Mod+O".action = actions.toggle-overview;

              # Quit & Monitors
              "Mod+Shift+E".action = actions.quit;
              "Mod+Shift+P".action = actions.power-off-monitors;
            };
          };
        };
      };
    };
in
{
  imports = [ inputs.niri.nixosModules.niri ];

  options.northstar.features.niri.enable = lib.mkEnableOption "Niri scrollable-tiling Wayland compositor";

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
    };

    home-manager.sharedModules = [ hmNiriModule ];

    security.polkit.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}

