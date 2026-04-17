{ config, lib, ... }:
let cfg = config.northstar.home.starship;
in {
  options.northstar.home.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      enableTransience = true;
    };
  };
}
