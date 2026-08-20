{ config, lib, ... }:
let
  cfg = config.northstar.features.env;
in
{
  options.northstar.features.env.enable = lib.mkEnableOption "environment variables (EDITOR, VISUAL)";

  config = lib.mkIf cfg.enable {
    environment.variables.EDITOR = lib.mkDefault "nvim";
    environment.variables.VISUAL = lib.mkDefault "nvim";
    environment.variables.BROWSER = lib.mkDefault "zen";
  };
}
