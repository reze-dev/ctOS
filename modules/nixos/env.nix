{ config, lib, ... }:
let cfg = config.northstar.env;
in {
  options.northstar.env.enable = lib.mkEnableOption "environment variables (EDITOR, VISUAL)";

  config = lib.mkIf cfg.enable {
    environment.variables.EDITOR = "nvim";
    environment.variables.VISUAL = "emacs";
  };
}
