{ config, lib, ... }:
let cfg = config.cryonix.env;
in {
  options.cryonix.env.enable = lib.mkEnableOption "environment variables (EDITOR, VISUAL)";

  config = lib.mkIf cfg.enable {
    environment.variables.EDITOR = "nvim";
    environment.variables.VISUAL = "emacs";
  };
}
