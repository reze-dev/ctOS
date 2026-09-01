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
      jq
      nitch
      ripgrep
      tmux
      unzip
      wget
      zoxide
    ];
  };
}
