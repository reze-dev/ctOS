{ ... }:

{
  perSystem =
    { pkgs, ... }:
    {
      packages.ctos-shell = pkgs.callPackage ../shell/nix/package.nix { };
    };
}
