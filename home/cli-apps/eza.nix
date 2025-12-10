{
  config,
  pkgs,
  ...
}:

{
  programs.eza = {
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
