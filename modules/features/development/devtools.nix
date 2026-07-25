{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.features.devtools;
  hs = pkgs.haskell.packages.ghc914;
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
      scala
      shfmt
      shellcheck
      zig
      zls

      # Haskell (GHC 9.14 toolchain)
      ##hs.ghc
      ##hs.cabal-install
      ##hs.haskell-language-server
      ##hs.haskell-debugger
      ##hs.hoogle
      ##hs.fourmolu
    ];
  };
}
