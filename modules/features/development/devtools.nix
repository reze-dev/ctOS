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
      gcc
      go
      libgcc
      nil
      nixfmt
      nodejs
      rustup
      tree-sitter
      vscode
      jdk21
      clang
      clang-tools
      cmake
      gnumake
      python3
      shfmt
      shellcheck

      # Zig
      zig
      zls

      # Scala
      metals
      coursier

      # Haskell (GHC 9.14 toolchain)
      hs.ghc
      hs.cabal-install
      hs.haskell-language-server
      #hs.haskell-debugger
      hs.haskell-debug-adapter
      hs.hoogle
      hs.fourmolu
    ];
  };
}
