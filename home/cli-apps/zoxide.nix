{
  config,
  pkgs,
  ...
}:

{
  # Zoxide config
  programs.zoxide = {
    enableFishIntegration = true;
    enableZshIntegration = true;
  };
}
