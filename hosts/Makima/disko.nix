# Auto-generated disko config for Makima (partition-only)
{
  disko.devices.disk.nixos = {
    type = "disk";
    device = "/dev/nvme0n1p4";
    content = {
      type = "btrfs";
      extraArgs = [ "-f" ];
      subvolumes = {
        "/root" = {
          mountpoint = "/";
          mountOptions = [ "compress=zstd" ];
        };
        "/home" = {
          mountpoint = "/home";
          mountOptions = [ "compress=zstd" ];
        };
        "/nix" = {
          mountpoint = "/nix";
          mountOptions = [ "compress=zstd" "noatime" ];
        };
        "/log" = {
          mountpoint = "/var/log";
          mountOptions = [ "compress=zstd" ];
        };
      };
    };
  };

  # Existing EFI partition — not managed by disko
  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/CB41-6695";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
}
