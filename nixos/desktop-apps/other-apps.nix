{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    with pkgs;
    [
      bat
      discord
      dunst
      emacs-pgtk
      epy
      eza
      fd
      fzf
      fastfetch
      gcc
      ghostty
      go
      hyprpaper
      hyprcursor
      kdePackages.dolphin
      kitty
      libgcc
      libnotify
      lazygit
      mpv
      nil
      nitch
      nixfmt-rfc-style
      nodejs
      obsidian
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
      #...
    ]
    ++ [
      # Required for hyprland cursor
      inputs.zen-browser.packages."${stdenv.hostPlatform.system}".default
      inputs.rose-pine-hyprcursor.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.awww.packages.${pkgs.stdenv.hostPlatform.system}.awww
    ];
}
