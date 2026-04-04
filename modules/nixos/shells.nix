{ config, lib, ... }:
let cfg = config.snowflake.shells;
in {
  options.snowflake.shells.enable = lib.mkEnableOption "system-level shell support (fish, zsh)";

  config = lib.mkIf cfg.enable {
    programs.fish.enable = true;
    programs.zsh.enable = true;
  };
}
