{ config, lib, ... }:

let
  cfg = config.ctos.profiles.workstation;
  features = [
    "dev"
    "devtools"
    "direnv"
    "eza"
    "emacs"
    "fish"
    "fzf"
    "git"
    "starship"
    "tmux"
    "virtualization"
    "yazi"
    "zoxide"
    "zsh"
  ];
in
{
  options.ctos.profiles.workstation.enable =
    lib.mkEnableOption "development workstation ctOS profile";

  config = lib.mkIf cfg.enable {
    ctos.features =
      features
      |> (
        f:
        lib.genAttrs f (_: {
          enable = true;
        })
      );
  };
}
