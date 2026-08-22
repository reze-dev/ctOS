# Flake-parts module: code formatter
{ inputs, ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixfmt;
    };
}
