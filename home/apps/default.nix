{
  config,
  pkgs,
  ...
}:

{
  imports = [
    ./ghostty.nix
    ./kitty.nix
  ];
}
