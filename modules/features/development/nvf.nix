{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ctos.features.nvf;
in
{
  options.ctos.features.nvf.enable = lib.mkEnableOption "nvf Neovim configuration exposed as vim";

  config = lib.mkIf cfg.enable (
    let
      customNeovim = inputs.nvf.lib.neovimConfiguration {
        inherit pkgs;
        modules = [ ../../../nvf/nvf.nix ];
      };
      nvf-vim =
        pkgs.runCommand "nvf-vim"
          {
            meta.mainProgram = "vim";
          }
          ''
            mkdir -p $out/bin
            ln -s ${customNeovim.neovim}/bin/nvim $out/bin/vim
          '';
    in
    {
      environment.systemPackages = [ nvf-vim ];
    }
  );
}
