{
  config,
  pkgs,
  ...
}:

{
  # Fzf config
  programs.fzf = {
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
