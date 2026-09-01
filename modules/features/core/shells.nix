{ config, lib, ... }:
let
  cfg = config.ctos.features.shells;
in
{
  options.ctos.features.shells.enable = lib.mkEnableOption "system-level shell support (fish, zsh)";

  config = lib.mkIf cfg.enable {
    programs.fish.enable = true;
    programs.zsh.enable = true;
  };
}
