{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.hyprland;
  debugEnabled = config.ctos.debug.enable;

  hmHyprlandModule =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      config = {
        home.packages = with pkgs; [
          brightnessctl
          playerctl
        ];

        xdg.configFile."hypr/hyprland.lua".text = ''
          -- Managed by ctOS. Hyprland 0.55+ loads this before hyprland.conf.

          hl.monitor({
              output = "",
              mode = "preferred",
              position = "auto",
              scale = 1.20,
          })

          local terminal = "kitty"
          local fileManager = "kitty -e yazi"
          local menu = "fuzzel"
          local mainMod = "SUPER"

          hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
          hl.env("XCURSOR_SIZE", "20")
          hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
          hl.env("HYPRCURSOR_SIZE", "20")

          -- Hyprland 0.56 renders through aquamarine, not wlroots.
          --
          -- From the aquamarine log of a failing greeter start-up:
          --   drm: gpu /dev/dri/card1 becomes primary drm
          --   drm: Starting backend for /dev/dri/card0, with driver nvidia-drm
          --         with primary /dev/dri/card1
          --   Couldn't open a GBM device at fd 40
          --   Cannot create a GBM Allocator: gbm failed to create a device.
          --   CRIT: Cannot open backend: no allocator available
          --
          -- So DRM itself opens fine and card1 (the AMD APU) is already
          -- primary, but aquamarine still brings the backend up on card0 with
          -- nvidia-drm, and gbm_create_device() fails on the NVIDIA node
          -- because the NVIDIA GBM userspace is not on the session's library
          -- path. The result is no allocator and an abort.
          --
          -- AQ_DRM_DEVICES is aquamarine's own override. Restricting it to the
          -- AMD APU keeps the backend off the NVIDIA card entirely, which is
          -- what Niri already does successfully on this machine. This is an
          -- Optimus laptop (GeForce GTX 1650 Ti + Renoir APU) and the internal
          -- panel is driven by the APU.
          --
          -- Note /dev/dri numbering is not what it looks like: card1 is the AMD
          -- APU (PCI 05:00.0) while renderD128 is *also* the APU and renderD129
          -- is the NVIDIA card.
          hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")

          ${lib.optionalString debugEnabled ''
            -- 0.56 defaults debug.disable_logs to true, so Hyprland prints
            -- nothing at all unless logs are explicitly re-enabled. Combined
            -- with the launcher redirecting stderr, a failing start-up used to
            -- produce a completely empty log.
            hl.env("HYPRLAND_TRACE", "1")
            hl.env("AQ_TRACE", "1")
          ''}

          hl.on("hyprland.start", function()
            -- nixos-fake-graphical-session.target, the same target niri
            -- starts.
            --
            -- This used to start and stop hyprland-session.target, but the
            -- nixpkgs Hyprland package installs no systemd user units, so
            -- that target does not exist and systemctl fails with "Unit
            -- hyprland-session.target not found". Nothing then pulled in
            -- graphical-session.target, which is where ctos.service,
            -- ctos-awww-daemon.service and ctos-wallpaper.service live --
            -- hence a Hyprland session with no shell, no awww and no
            -- wallpaper.
            hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP DISPLAY GTK_USE_PORTAL HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE && systemctl --user start nixos-fake-graphical-session.target")
            hl.exec_cmd("systemctl --user start hyprpolkitagent")
          end)

          hl.config({
              ${lib.optionalString debugEnabled ''
                -- enable_stdout_logs is only honoured when disable_logs is false,
                -- so both are needed to get anything on stdout.
                debug = {
                    disable_logs = false,
                    enable_stdout_logs = true,
                    disable_time = false,
                    suppress_errors = false,
                    error_limit = 20,
                },
              ''}
              general = {
                  gaps_in = 3,
                  gaps_out = 5,
                  border_size = 2,
                  col = {
                      active_border = { colors = { "rgba(1bfd9cee)", "rgba(66b2b2ee)" }, angle = 120 },
                      inactive_border = "rgba(2a2a2aaa)",
                  },
                  resize_on_border = false,
                  allow_tearing = false,
                  layout = "dwindle",
              },
              decoration = {
                  rounding = 10,
                  rounding_power = 2,
                  active_opacity = 1.0,
                  inactive_opacity = 1.0,
                  shadow = {
                      enabled = true,
                      range = 4,
                      render_power = 3,
                      color = 0xee1a1a1a,
                  },
                  blur = {
                      enabled = true,
                      size = 3,
                      passes = 1,
                      vibrancy = 0.1696,
                  },
              },
              animations = {
                  enabled = true,
              },
              dwindle = {
                  preserve_split = true,
              },
              master = {
                  new_status = "master",
              },
              misc = {
                  force_default_wallpaper = 0,
                  disable_hyprland_logo = true,
              },
              input = {
                  kb_layout = "us",
                  kb_variant = "",
                  kb_model = "",
                  kb_options = "",
                  kb_rules = "",
                  follow_mouse = 1,
                  sensitivity = 0,
                  touchpad = {
                      natural_scroll = false,
                  },
              },
          })

          hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
          hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
          hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
          hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
          hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
          hl.curve("easy", { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

          hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
          hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
          hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
          hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
          hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })
          hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
          hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
          hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })
          hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
          hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
          hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
          hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
          hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
          hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
          hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
          hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
          hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })

          hl.gesture({
              fingers = 3,
              direction = "horizontal",
              action = "workspace",
          })

          hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
          hl.bind(mainMod .. " + C", hl.dsp.window.close())
          hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())
          hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
          hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
          hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
          hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
          hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))

          -- Screenshot bindings
          hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | satty --filename -'))
          hl.bind("CTRL + Print", hl.dsp.exec_cmd('grim - | satty --filename -'))
          hl.bind("ALT + Print", hl.dsp.exec_cmd('grim -g "$(hyprctl activewindow -j | jq -r \'"\\(.at[0]),\\(.at[1]) \\(.size[0])x\\(.size[1])"\')" - | satty --filename -'))

          hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
          hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
          hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
          hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

          for i = 1, 10 do
              local key = i % 10
              hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
              hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
          end

          hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
          hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

          hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
          hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
          hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
          hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

          hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
          hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
          hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
          hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
          hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
          hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
          hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
          hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
          hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
          hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

          hl.window_rule({
              name = "suppress-maximize-events",
              match = { class = ".*" },
              suppress_event = "maximize",
          })

          hl.window_rule({
              name = "fix-xwayland-drags",
              match = {
                  class = "^$",
                  title = "^$",
                  xwayland = true,
                  float = true,
                  fullscreen = false,
                  pin = false,
              },
              no_focus = true,
          })
        '';
      };
    };
in
{
  options.ctos.features.hyprland.enable = lib.mkEnableOption "Hyprland window manager";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ hmHyprlandModule ];

    programs.hyprland = {
      enable = true;

      # From the system nixpkgs rather than the Hyprland git flake input.
      #
      # The flake input carries its own nixpkgs, so Hyprland and aquamarine
      # were linked against glibc-2.42 while the system's Mesa is built
      # against glibc-2.44. Hyprland therefore starts with glibc 2.42 mapped,
      # and when GBM tries to dlopen the driver's dri_gbm.so it pulls in
      # mesa's libgallium, which requires GLIBC_2.43:
      #
      #   MESA-LOADER: failed to open dri:
      #     .../glibc-2.42-84/lib/libm.so.6: version `GLIBC_2.43' not found
      #     (required by .../mesa-26.2.3/lib/libgallium-26.2.3.so)
      #
      # gbm_create_device() then returns NULL and start-up dies with
      # "Cannot create a GBM Allocator" / "no allocator available". Niri is
      # unaffected because it comes from the system nixpkgs and so runs
      # against glibc 2.44.
      #
      # No environment variable can paper over this: glibc resolves its
      # dlopen search path once at startup, and the GLIBC_2.43 requirement is
      # absolute. The two closures have to be built against the same glibc.
      package = pkgs.hyprland;
      xwayland.enable = true;
    };

    security.polkit.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      XDG_SESSION_TYPE = "wayland";
    };
  };
}
