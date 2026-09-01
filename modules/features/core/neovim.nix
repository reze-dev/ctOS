{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.neovim;
in
{
  options.northstar.features.neovim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
    };
  };
}
