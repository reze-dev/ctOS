{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.neovim;
in
{
  options.ctos.features.neovim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
    };
  };
}
