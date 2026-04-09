{ config, lib, pkgs, ... }:
let cfg = config.cryonix.emacs;
in {
  options.cryonix.emacs.enable = lib.mkEnableOption "Emacs daemon service";

  config = lib.mkIf cfg.enable {
    services.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
