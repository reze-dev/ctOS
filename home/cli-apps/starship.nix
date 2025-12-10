{
  config,
  pkgs,
  ...
}:

{
  # Starship config
  programs.starship = {
    enable = true;
    #settings = pkgs.lib.importTOML ./dotfiles/starship.toml;
    enableFishIntegration = true;
    enableTransience = true;
  };
}
