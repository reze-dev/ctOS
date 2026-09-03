{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.ctOS;
  ctosPackage = pkgs.callPackage ./package.nix { };
in
{
  options.programs.ctOS = {
    enable = lib.mkEnableOption "ctOS Quickshell desktop shell";
  };

  config = lib.mkIf cfg.enable {
    home.activation.ctosRemoveLegacyNoctalia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if command -v systemctl >/dev/null 2>&1; then
          systemctl --user disable --now noctalia.service noctalia-shell.service 2>/dev/null || true
      fi
    '';

    systemd.user.services.ctos = {
      Unit = {
        Description = "ctOS Quickshell desktop shell";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        ExecStart = "${pkgs.quickshell}/bin/qs --path ${ctosPackage}/share/ctos/shell.qml";
        Restart = "on-failure";
        RestartSec = 2;
        StartLimitBurst = 5;
        StartLimitIntervalSec = 30;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
