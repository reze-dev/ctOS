{ config, lib, ... }:
let cfg = config.northstar.home.fzf;
in {
  options.northstar.home.fzf.enable = lib.mkEnableOption "FZF fuzzy finder";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
