{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.packages;
in
{
  options.ctos.features.packages.enable = lib.mkEnableOption "core system packages and unfree config";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      bat
      btop
      eza
      fd
      fzf
      fuzzel
      jq
      ydotool
      fastfetch
      ripgrep
      superfile
      tmux
      unzip
      wget
      zoxide
    ];

    systemd.services.ydotoold = {
      description = "ydotool daemon";

      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.ydotool}/bin/ydotoold --socket-own=1000:100";
        Restart = "always";
        RestartSec = 2;
      };
    };
  };
}
