# Example disko configuration — customize for your disk setup
#
# This uses Northstar's mkDisko function to generate the partition layout.
# See lib/disko/default.nix for all available options.
#
{ lib, ... }:

let
  northstar = import ../../lib/core.nix { inherit lib; };
in
northstar.mkDisko {
  mode = "whole-disk";
  device = "/dev/vda"; # Change to your disk (e.g. /dev/nvme0n1 or /dev/sda)
  fsType = "btrfs"; # "btrfs" or "ext4"
  efiSize = "2G"; # 2G default (safe for Limine + NixOS generations)
  swapSize = "8G"; # "0" to disable swap
}
