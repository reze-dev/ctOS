{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.zen-browser;
in
{
  options.northstar.zen-browser.enable = lib.mkEnableOption "Zen Browser";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
