{ config, lib, ... }:

let
  cfg = config.northstar.features.caelestia;

  hmCaelestiaModule =
    {
      config,
      lib,
      inputs,
      ...
    }:
    {
      imports = [
        (inputs.caelestia-shell.homeManagerModules.default or inputs.caelestia-shell.homeModules.default or inputs.caelestia-shell.homeManagerModule)
      ];

      config = {
        programs.caelestia = {
          enable = true;
          systemd.enable = false; # Autostarted by compositor
        };
      };
    };
in
{
  options.northstar.features.caelestia.enable = lib.mkEnableOption "Caelestia Wayland desktop shell";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ hmCaelestiaModule ];
  };
}
