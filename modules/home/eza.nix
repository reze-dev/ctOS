{ config, lib, ... }:
let cfg = config.snowflake.home.eza;
in {
  options.snowflake.home.eza.enable = lib.mkEnableOption "Eza (ls replacement)";

  config = lib.mkIf cfg.enable {
    programs.eza = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
