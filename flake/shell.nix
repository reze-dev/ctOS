{ ... }:

{
  perSystem =
    { pkgs, ... }:
    rec {
      packages.ctos-shell = pkgs.callPackage ../shell/nix/package.nix { };
      packages.default = packages.ctos-shell;
    };
}
