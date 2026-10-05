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
  # Only wallpapers that belong in the repository are listed. Two further images
  # are present in the working tree and are deliberately not referenced here or
  # in the shell -- see .gitignore. Adding one is two entries, one per side.
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

  wallpapers = lib.listToAttrs (
    map (w: {
      name = ".local/share/ctos/wallpapers/${w.file}";
      value = ../../../shell/extras/wallpapers/${w.file};
    }) wallpaperFiles
  );

  defaultWallpaper = "v1";
  defaultWallpaperFile =
    lib.head (
      builtins.filter (w: w.id == defaultWallpaper) wallpaperFiles
    )
      .file;
  wallpaperPath = ".local/share/ctos/wallpapers/${defaultWallpaperFile}";
  applyWallpaper = pkgs.writeShellScript "ctos-apply-wallpaper" ''
    set -eu

    # The daemon socket can appear shortly after the graphical session target.
    # Retry briefly so startup ordering does not make the wallpaper disappear.
    for attempt in $(seq 1 20); do
      if ${pkgs.awww}/bin/awww img \
        "$HOME/${wallpaperPath}" \
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

          # Every authored wallpaper, not just the default. home.file merges
          # attribute names rather than replacing, so this composes with any
          # other module that wants to drop something else in that directory.
          home.file = wallpapers;

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
