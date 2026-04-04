{ config, lib, pkgs, ... }:
let cfg = config.snowflake.emacs;
in {
  options.snowflake.emacs.enable = lib.mkEnableOption "Emacs daemon service";

  config = lib.mkIf cfg.enable {
    services.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
