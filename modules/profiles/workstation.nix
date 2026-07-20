{ config, lib, ... }:

let
  cfg = config.northstar.profiles.workstation;
  features = [
    "dev"
    "devtools"
    "direnv"
    "emacs"
    "eza"
    "fish"
    "fzf"
    "git"
    "omp"
    "starship"
    "tmux"
    "virtualization"
    "yazi"
    "zoxide"
    "zsh"
  ];
in
{
  options.northstar.profiles.workstation.enable =
    lib.mkEnableOption "development workstation Northstar profile";

  config = lib.mkIf cfg.enable {
    northstar.features =
      features
      |> (
        f:
        lib.genAttrs f (_: {
          enable = true;
        })
      );
  };
}
