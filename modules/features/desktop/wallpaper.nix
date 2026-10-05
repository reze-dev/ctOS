{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.wallpaper;

  # The authored set.
  #
  # Each entry names its own file rather than deriving one from the id, so a
  # non-PNG or irregularly-named wallpaper cannot silently fail to install.
  #
  # This list and WallpaperService.wallpapers are two halves of one contract.
  # They must agree on every id and every installed filename: an id installed
  # here but absent there can never be selected, and a file shipped here but
  # named differently there selects a path that does not exist.
  #
  # Only wallpapers that belong in the repository are listed. Adding one is an
  # entry here and one there.
  #
  # The install below is written out longhand rather than folded over this list,
  # and that is deliberate. Generating `home.file` entries from interpolated path
  # expressions -- `../../../shell/extras/wallpapers/${w.file}` -- produces a
  # value that reports itself as a path and resolves to the right file in
  # isolation, but makes `system.build.toplevel` fail to evaluate with
  #
  #   syntax error, unexpected invalid token
  #   at shell/extras/wallpapers/wallpaper-v1.png:1:1
  #
  # i.e. Nix parses the PNG as an expression. So the set is still data, but the
  # one place a path is built for home-manager spells it as a literal. Two
  # entries is a small enough list that being explicit costs nothing, and being
  # explicit is what the previous working version of this module did.
  wallpaperFiles = [
    {
      id = "v1";
      file = "wallpaper-v1.png";
    }
    {
      id = "v2";
      file = "wallpaper-v2.png";
    }
  ];

  wallpaperPath = ".local/share/ctos/wallpapers/wallpaper-v1.png";

  wallpaperV1 = ../../../shell/extras/wallpapers/wallpaper-v1.png;
  wallpaperV2 = ../../../shell/extras/wallpapers/wallpaper-v2.png;

  applyWallpaper = pkgs.writeShellScript "ctos-apply-wallpaper" ''
    set -eu

    # Apply the recorded choice, not a hardcoded one.
    #
    # This unit runs at graphical-session.target and WallpaperService applies the
    # same value a moment later. While the unit applied v1 outright, every boot
    # showed v1 fading out and the real wallpaper fading in. The shell being the
    # authority fixed what ended up on screen; this stops the wrong image being
    # painted first.
    #
    # Any of settings.json being unreadable, absent, lacking the key, or naming a
    # file that is not there is an ordinary condition on a first boot or after a
    # wallpaper has been deleted, and all of them fall back to v1.
    settings="''${XDG_CONFIG_HOME:-$HOME/.config}/ctos/settings.json"
    target="$HOME/${wallpaperPath}"

    if [ -r "$settings" ]; then
      name=$(${pkgs.jq}/bin/jq -r '.wallpaper // empty' "$settings" 2>/dev/null) || name=""
      dir=$(${pkgs.jq}/bin/jq -r '.wallpaperDir // empty' "$settings" 2>/dev/null) || dir=""
      [ -n "$dir" ] || dir="$HOME/.local/share/ctos/wallpapers"
      if [ -n "$name" ] && [ -f "$dir/$name" ]; then
        target="$dir/$name"
      fi
    fi

    # The daemon socket can appear shortly after the graphical session target.
    # Retry briefly so startup ordering does not make the wallpaper disappear.
    for attempt in $(seq 1 20); do
      if ${pkgs.awww}/bin/awww img \
        "$target" \
        --transition-type fade \
        --transition-duration 1; then
        exit 0
      fi
      sleep 0.25
    done

    echo "ctOS wallpaper: awww daemon did not become ready" >&2
    exit 1
  '';
in
{
  options.ctos.features.wallpaper.enable = lib.mkEnableOption "ctOS animated wallpaper";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [
      (
        { ... }:
        {
          home.packages = [ pkgs.awww ];

          # Every authored wallpaper, not just the default -- so there is
          # something to switch between. home.file merges attribute names rather
          # than replacing, so this composes with any other module that wants to
          # drop something else in that directory.
          home.file.".local/share/ctos/wallpapers/wallpaper-v1.png".source = wallpaperV1;
          home.file.".local/share/ctos/wallpapers/wallpaper-v2.png".source = wallpaperV2;

          systemd.user.services.ctos-awww-daemon = {
            Unit = {
              Description = "ctOS awww wallpaper daemon";
              PartOf = [ "graphical-session.target" ];
            };

            Service = {
              ExecStart = "${pkgs.awww}/bin/awww-daemon";
              Restart = "on-failure";
              RestartSec = 2;
            };

            Install.WantedBy = [ "graphical-session.target" ];
          };

          systemd.user.services.ctos-wallpaper = {
            Unit = {
              Description = "Apply the ctOS desktop wallpaper";
              After = [ "ctos-awww-daemon.service" ];
              Requires = [ "ctos-awww-daemon.service" ];
              PartOf = [ "graphical-session.target" ];
            };

            Service = {
              Type = "oneshot";
              ExecStart = applyWallpaper;
              RemainAfterExit = true;
            };

            Install.WantedBy = [ "graphical-session.target" ];
          };
        }
      )
    ];
  };
}
