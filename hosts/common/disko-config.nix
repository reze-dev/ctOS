{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # The device will be determined by the installer script
        # device = "/dev/nvme0n1"; 
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot/efi";
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                discardPolicy = "both";
                resumeDevice = true; # resume from hiberation from this device
              };
            };
            root = {
              size = "100%";
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ]; # Override existing partition
                # Subvolumes must set a mountpoint in order to be mounted,
                # unless their parent is mounted
                subvolumes = {
                  # Subvolume name is different from mountpoint
                  "/root" = {
                    mountpoint = "/";
                  };
                  # Subvolume name is the same as the mountpoint
                  "/home" = {
                    mountpoint = "/home";
                  };
                  # Parent is not mounted so the mountpoint must be set
                  "/nix" = {
                    mountpoint = "/nix";
                  };
                  "/log" = {
                    mountpoint = "/var/log";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
