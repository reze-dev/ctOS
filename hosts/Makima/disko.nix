# Auto-generated disko config for Makima
{ lib, ... }:
{
  imports = [ ../../lib/disko/btrfs.nix ];

  disko.devices.disk.main.device = "/dev/nvme0n1";
  disko.devices.disk.main.content.partitions.swap.size = lib.mkForce "16G";
  disko.devices.disk.main.content.partitions.root.size = lib.mkForce "200G";
}
