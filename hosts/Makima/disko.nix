# Auto-generated disko config for Makima
{ lib, ... }:

let
  ctos = import ../../lib/core.nix { inherit lib; };
in
ctos.mkDisko {
  mode = "whole-disk";
  device = "/dev/nvme0n1";
  fsType = "btrfs";
  efiSize = "4G";
  swapSize = "16G";
  rootSize = "270G";
}
