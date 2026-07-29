{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.devtools;
  hs = pkgs.haskell.packages.ghc910;
in
{
  options.northstar.features.devtools.enable =
    lib.mkEnableOption "developer tools and programming languages";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      codecrafters-cli
      go
      rustup
      tree-sitter
      vscode
      jdk21
      python3
      nushell
      shfmt
      shellcheck

      # Nix
      nil
      nixfmt

      # C/C++
      gcc
      libgcc
      clang
      clang-tools
      cmake
      gnumake

      # JavaScript
      nodejs
      bun

      # Zig
      zig
      zls

      # Scala
      metals
      coursier

      # Haskell (GHC 9.10 toolchain)
      hs.ghc
      hs.cabal-install
      hs.haskell-language-server
      hs.haskell-debug-adapter
      hs.hoogle
      hs.fourmolu
    ];
  };
}
