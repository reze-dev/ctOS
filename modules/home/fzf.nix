{ config, lib, ... }:
let cfg = config.snowflake.home.fzf;
in {
  options.snowflake.home.fzf.enable = lib.mkEnableOption "FZF fuzzy finder";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
  };
}
