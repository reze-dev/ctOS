{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.northstar.features.niri;

  hmNiriModule =
    {
      config,
      lib,
      pkgs,
      osConfig ? { },
      ...
    }:
    let
      niriEnabled = osConfig.northstar.features.niri.enable or false;
      noctaliaEnabled = osConfig.northstar.features.noctalia.enable or false;
    in
    {
      config = lib.mkIf niriEnabled {
        home.packages = with pkgs; [
          alacritty
          fuzzel
          xwayland-satellite
        ];

        programs.niri = {
          settings = {
            # Noctalia autostart if noctalia feature is enabled
            spawn-at-startup = lib.optionals noctaliaEnabled [
              { command = [ "noctalia" ]; }
            ];
          };
        };
      };
    };
in
{
  imports = [ inputs.niri.nixosModules.niri ];

  options.northstar.features.niri.enable = lib.mkEnableOption "Niri scrollable-tiling Wayland compositor";

  config = lib.mkIf cfg.enable {
    programs.niri = {
      enable = true;
    };

    home-manager.sharedModules = [ hmNiriModule ];

    security.polkit.enable = true;

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
  };
}
