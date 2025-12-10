{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./eza.nix
    ./fzf.nix
    ./git.nix
    ./direnv.nix
    #./nix-index.nix
    ./omp.nix
    ./starship.nix
    ./tmux.nix
    ./zoxide.nix
  ];
}
