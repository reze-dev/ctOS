{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    let
      customNeovim = inputs.nvf.lib.neovimConfiguration {
        inherit pkgs;
        modules = [ ../nvf/nvf.nix ];
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
      packages.nvf-vim = nvf-vim;
    };
}
