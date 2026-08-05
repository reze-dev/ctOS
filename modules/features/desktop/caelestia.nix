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
      imports = [ inputs.caelestia-shell.homeManagerModules.default ];

      config = {
        programs.caelestia = {
          enable = true;
          systemd.enable = false; # Autostarted by compositor

          cli.enable = true;

          settings = {
            bar.statusIcons = [
              {
                id = "network";
                enabled = true;
              }
              {
                id = "bluetooth";
                enabled = true;
              }
              {
                id = "battery";
                enabled = true;
              }
            ];
          };
        };
      };
    };
in
{
  options.northstar.features.caelestia.enable =
    lib.mkEnableOption "Caelestia Wayland desktop shell";

  config = lib.mkIf cfg.enable {
    home-manager.sharedModules = [ hmCaelestiaModule ];
  };
}
