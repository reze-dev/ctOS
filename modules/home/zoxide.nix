{ config, lib, ... }:
let cfg = config.snowflake.home.zoxide;
in {
  options.snowflake.home.zoxide.enable = lib.mkEnableOption "Zoxide (cd replacement)";

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
