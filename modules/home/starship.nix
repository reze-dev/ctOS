{ config, lib, ... }:
let cfg = config.snowflake.home.starship;
in {
  options.snowflake.home.starship.enable = lib.mkEnableOption "Starship prompt";

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      enableTransience = true;
    };
  };
}
