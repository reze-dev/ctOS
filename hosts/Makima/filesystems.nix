# Auto-generated filesystem configuration for Makima
# Partition-only (dual-boot) mode
# NixOS partition: /dev/nvme0n1p5 (UUID: 9e90e012-e7c8-4616-8acc-3f8d78588774)
# EFI partition: /dev/nvme0n1p1 (UUID: BE63-A59B)
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9e90e012-e7c8-4616-8acc-3f8d78588774";
    fsType = "btrfs";
    options = [
      "subvol=@root"
      "compress=zstd"
    ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/9e90e012-e7c8-4616-8acc-3f8d78588774";
    fsType = "btrfs";
    options = [
      "subvol=@home"
      "compress=zstd"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/9e90e012-e7c8-4616-8acc-3f8d78588774";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/9e90e012-e7c8-4616-8acc-3f8d78588774";
    fsType = "btrfs";
    options = [
      "subvol=@log"
      "compress=zstd"
    ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/BE63-A59B";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

}
