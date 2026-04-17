{ config, lib, pkgs, ... }:
let cfg = config.northstar.emacs;
in {
  options.northstar.emacs.enable = lib.mkEnableOption "Emacs daemon service";

  config = lib.mkIf cfg.enable {
    services.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
