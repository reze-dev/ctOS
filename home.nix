{
  config,
  pkgs,
  lib,
  importers,
  ...
}:

{
  home.username = lib.mkDefault "nixos";
  home.homeDirectory = lib.mkDefault "/home/nixos";
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
