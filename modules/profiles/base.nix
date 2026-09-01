{ config, lib, ... }:

let
  cfg = config.ctos.profiles.base;
  features = [
    "boot"
    "env"
    "fonts"
    "locales"
    "networking"
    "neovim"
    "packages"
    "shells"
    "ssh"
  ];
in
{
  options.ctos.profiles.base.enable = lib.mkEnableOption "base ctOS system profile";

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
