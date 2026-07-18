{
  config,
  lib,
  ...
}:

let
  cfg = config.northstar.profiles.workstation;
  modules = [
    "dev"
    "devtools"
    "emacs"
    "virtualization"
  ];
in
{
  options.northstar.profiles.workstation.enable =
    lib.mkEnableOption "development workstation Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar = lib.genAttrs modules (_: {
      enable = true;
    });
  };
}
