{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.neovim;
in
{
  options.northstar.neovim.enable = lib.mkEnableOption "Neovim";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
    };
  };
}
