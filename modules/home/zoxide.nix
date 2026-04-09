{ config, lib, ... }:
let cfg = config.cryonix.home.zoxide;
in {
  options.cryonix.home.zoxide.enable = lib.mkEnableOption "Zoxide (cd replacement)";

  config = lib.mkIf cfg.enable {
    programs.zoxide = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
