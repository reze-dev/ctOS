{ config, lib, ... }:
let cfg = config.cryonix.home.eza;
in {
  options.cryonix.home.eza.enable = lib.mkEnableOption "Eza (ls replacement)";

  config = lib.mkIf cfg.enable {
    programs.eza = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
