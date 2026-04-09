{ config, lib, ... }:
let cfg = config.cryonix.home.starship;
in {
  options.cryonix.home.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      enableTransience = true;
    };
  };
}
