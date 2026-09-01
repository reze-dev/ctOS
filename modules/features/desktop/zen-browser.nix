{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.zen-browser;
in
{
  options.ctos.features.zen-browser.enable = lib.mkEnableOption "Zen Browser";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };
}
