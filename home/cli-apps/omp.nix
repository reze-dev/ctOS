{
  config,
  pkgs,
  ...
}:

{
  # Oh-my-posh configs
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = builtins.fromJSON (
      builtins.unsafeDiscardStringContext (builtins.readFile ../dotfiles/omp.json)
    );
  };
}
