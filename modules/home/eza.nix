{ config, lib, ... }:
let cfg = config.northstar.home.eza;
in {
  options.northstar.home.eza.enable = lib.mkEnableOption "Eza (ls replacement)";

  config = lib.mkIf cfg.enable {
    programs.eza = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
