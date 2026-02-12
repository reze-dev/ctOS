{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Enable nix-ld
  programs.nix-ld.enable = true;

  # Set up the nix-ld libraries to load
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    openssl
    libgcc
    #...
  ];
}
