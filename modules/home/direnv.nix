{ config, lib, ... }:
let cfg = config.cryonix.home.direnv;
in {
  options.cryonix.home.direnv.enable = lib.mkEnableOption "Direnv integration";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
