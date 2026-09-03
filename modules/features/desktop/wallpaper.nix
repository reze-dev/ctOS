{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.ctos.features.wallpaper;
  wallpaper = ../../../shell/extras/wallpapers/wallpaper-v1.png;
  wallpaperPath = ".local/share/ctos/wallpapers/wallpaper-v1.png";
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
      ({ ... }:
        {
          home.packages = [ pkgs.awww ];

          home.file.${wallpaperPath}.source = wallpaper;

          systemd.user.services.ctos-awww-daemon = {
            Unit = {
              Description = "ctOS awww wallpaper daemon";
              After = [ "graphical-session.target" ];
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
        })
    ];
  };
}
