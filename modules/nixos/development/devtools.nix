{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.northstar.devtools;
in
{
  options.northstar.devtools.enable = lib.mkEnableOption "developer tools and programming languages";

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
      zig
      jdk17
      clang
      clang-tools
      cmake
      gnumake
      shfmt
      shellcheck

      # Haskell packages
      ghc
      cabal-install
      haskell-language-server
      haskellPackages.hoogle
      fourmolu
    ];
  };
}
