# Auto-generated filesystem configuration for Makima
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5e97ec6f-410e-46e1-a228-ee129541985b";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/5e97ec6f-410e-46e1-a228-ee129541985b";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/5e97ec6f-410e-46e1-a228-ee129541985b";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/5e97ec6f-410e-46e1-a228-ee129541985b";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/238D-76D7";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/5e97ec6f-410e-46e1-a228-ee129541985b";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];
}
