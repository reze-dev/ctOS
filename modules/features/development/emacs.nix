{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.emacs;
in
{
  options.northstar.features.emacs.enable = lib.mkEnableOption "Emacs daemon service";

  config = lib.mkIf cfg.enable {
    services.emacs = {
      enable = true;
      package = pkgs.emacs-pgtk;
    };
  };
}
