{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.neovim;
in
{
  options.northstar.neovim.enable = lib.mkEnableOption "Neovim nightly";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      package = inputs.neovim-nightly.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
  };
}
