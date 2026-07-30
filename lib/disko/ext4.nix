{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # Host-specific disko modules must set this.
        # device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              priority = 1;
              name = "ESP";
              start = "1M";
              end = "1024M";
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
                resumeDevice = true; # resume from hibernation from this device
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
