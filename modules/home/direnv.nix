{ config, lib, ... }:
let cfg = config.snowflake.home.direnv;
in {
  options.snowflake.home.direnv.enable = lib.mkEnableOption "Direnv integration";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };
  };
}
