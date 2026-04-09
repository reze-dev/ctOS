{ config, lib, ... }:
let cfg = config.cryonix.home.fzf;
in {
  options.cryonix.home.fzf.enable = lib.mkEnableOption "FZF fuzzy finder";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
