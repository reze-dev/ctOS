{ config, lib, ... }:
let cfg = config.northstar.home.zoxide;
in {
  options.northstar.home.zoxide.enable = lib.mkEnableOption "Zoxide (cd replacement)";

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
