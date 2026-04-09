{ config, lib, pkgs, inputs, ... }:
let cfg = config.cryonix.packages;
in {
  options.cryonix.packages.enable = lib.mkEnableOption "system packages and unfree config";

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    environment.systemPackages =
      with pkgs;
      [
        bat
        btop
        discord
        dunst
        emacs-pgtk
        epy
        eza
        fd
        fzf
        fuzzel
        gcc
        ghostty
        go
        hyprpaper
        hyprcursor
        hyprlauncher
        kitty
        libgcc
        libnotify
        lazygit
        mpv
        nil
        nitch
        nixfmt
        nodejs
        obsidian
        quickshell
        ripgrep
        rofi
        rustup
        tmux
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
      ]
      ++ [
        inputs.zen-browser.packages."${stdenv.hostPlatform.system}".default
        inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
      ];
  };
}
