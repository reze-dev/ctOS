{ config, lib, ... }:
let
  cfg = config.northstar.features.env;
in
{
  options.northstar.features.env.enable = lib.mkEnableOption "environment variables (EDITOR, VISUAL)";

  config = lib.mkIf cfg.enable {
    environment.variables.EDITOR = lib.mkForce "nvim";
    environment.variables.VISUAL = lib.mkForce "nvim";
    environment.variables.BROWSER = lib.mkForce "zen";
  };
}
