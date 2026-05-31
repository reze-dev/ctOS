{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.workstation;
in
{
  options.northstar.profiles.workstation.enable =
    lib.mkEnableOption "development workstation Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar = {
      dev.enable = true;
      emacs.enable = true;
      virtualization.enable = true;
    };
  };
}
