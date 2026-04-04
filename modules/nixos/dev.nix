{ config, lib, pkgs, ... }:
let cfg = config.snowflake.dev;
in {
  options.snowflake.dev.enable = lib.mkEnableOption "development tools (direnv, git, gpg, neovim, nix-ld)";

  config = lib.mkIf cfg.enable {
    programs.direnv = {
      loadInNixShell = true;
      nix-direnv.enable = true;
    };

    programs.git.enable = true;

    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    programs.neovim.enable = true;

    programs.nix-ld.enable = true;
    programs.nix-ld.libraries = with pkgs; [
      stdenv.cc.cc
      dbus
      zlib
      openssl
      libgcc
    ];
  };
}
