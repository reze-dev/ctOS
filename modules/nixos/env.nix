{ config, lib, ... }:
let cfg = config.snowflake.env;
in {
  options.snowflake.env.enable = lib.mkEnableOption "environment variables (EDITOR, VISUAL)";

  config = lib.mkIf cfg.enable {
    environment.variables.EDITOR = "nvim";
    environment.variables.VISUAL = "emacs";
  };
}
