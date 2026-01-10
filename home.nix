{
  config,
  pkgs,
  lib,
  importers,
  ...
}:

{
  home.username = "loid";
  home.homeDirectory = "/home/loid";
  home.stateVersion = "24.11";

  home.packages = [
    pkgs.hello
  ];

  home.file = {
  };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  imports = (importers.scanPaths ./home);

  programs.home-manager.enable = true;
}
