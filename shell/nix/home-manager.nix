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
    systemd.user.services.ctos = {
      Unit = {
        Description = "ctOS Quickshell desktop shell";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${ctosPackage}/bin/ctos-shell";
        Restart = "on-failure";
        RestartSec = 3;
        StartLimitBurst = 5;
        StartLimitIntervalSec = 30;
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
