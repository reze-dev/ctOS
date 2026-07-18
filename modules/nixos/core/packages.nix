{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.packages;
in
{
  options.northstar.packages.enable = lib.mkEnableOption "system packages and unfree config";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
      alacritty
      bat
      btop
      codecrafters-cli
      emacs-pgtk
      eza
      fd
      fzf
      fuzzel
      gcc
      go
      hyprcursor
      jq
      kdePackages.dolphin
      kitty
      libgcc
      libnotify
      mpv
      nil
      nitch
      nixfmt
      nodejs
      obsidian
      openconnect
      ripgrep
      rustup
      tmux
      tree-sitter
      unzip
      vscode
      wget
      wl-clipboard
      yazi
      zig
      zoxide
      jdk17
      clang
      clang-tools
      cmake
      gnumake
      shfmt
      shellcheck

      #Hasklul packages
      ghc
      cabal-install
      haskell-language-server
      haskellPackages.hoogle
      fourmolu
    ];
  };
}
