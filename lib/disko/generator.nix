# lib/disko/default.nix — Dynamic disko configuration generator
#
# Usage:
#   mkDisko { mode = "whole-disk"; device = "/dev/nvme0n1"; fsType = "btrfs"; }
#   mkDisko { mode = "partition-only"; nixosPart = "/dev/nvme0n1p2"; efiDevice = "/dev/disk/by-uuid/XXXX"; }
#
{ lib }:

let
  # Btrfs subvolume layout — standard Northstar layout with compress=zstd
  btrfsSubvolumes =
    swapEnabled:
    {
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
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };
      "/log" = {
        mountpoint = "/var/log";
        mountOptions = [ "compress=zstd" ];
      };
    }
    // lib.optionalAttrs swapEnabled {
      "/swap" = {
        mountpoint = "/swap";
      };
    };
in
rec {
  # mkDisko: generate a complete disko configuration attrset
  #
  # Arguments:
  #   mode        : "whole-disk" | "partition-only"
  #   fsType      : "btrfs" | "ext4"                     (default: "btrfs")
  #   device      : disk device path                      (whole-disk mode)
  #   nixosPart   : NixOS partition device path            (partition-only mode)
  #   efiDevice   : EFI partition device or UUID path      (partition-only: existing EFI)
  #   efiSize     : EFI partition size                     (whole-disk: default "2G")
  #   swapSize    : swap partition/file size, "0" to skip  (default: "8G")
  #   rootSize    : root partition size                    (default: "100%")
  #   swapPartition : dedicated swap partition device       (partition-only + ext4 only)
  mkDisko =
    {
      mode ? "whole-disk",
      fsType ? "btrfs",
      device ? null,
      nixosPart ? null,
      efiDevice ? null,
      efiSize ? "2G",
      swapSize ? "8G",
      rootSize ? "100%",
      swapPartition ? null,
    }:
    let
      swapEnabled = swapSize != "0";

      # Whole-disk mode: full GPT with ESP + optional swap + root
      wholeDiskConfig = {
        disko.devices.disk.main = {
          type = "disk";
          inherit device;
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                priority = 1;
                name = "ESP";
                start = "1M";
                end = efiSize;
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot/efi";
                };
              };
            }
            // lib.optionalAttrs swapEnabled {
              swap = {
                size = swapSize;
                content = {
                  type = "swap";
                  discardPolicy = "both";
                  resumeDevice = true;
                };
              };
            }
            // {
              root = {
                size = rootSize;
                content =
                  if fsType == "btrfs" then
                    {
                      type = "btrfs";
                      extraArgs = [ "-f" ];
                      subvolumes = btrfsSubvolumes false;
                    }
                  else
                    {
                      type = "filesystem";
                      format = "ext4";
                      mountpoint = "/";
                    };
              };
            };
          };
        };
      };

      # Partition-only mode: use existing partitions
      partitionOnlyConfig = {
        disko.devices.disk.nixos = {
          type = "disk";
          device = nixosPart;
          content =
            if fsType == "btrfs" then
              {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = btrfsSubvolumes swapEnabled;
              }
            else
              {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
        };
      }
      # Dedicated swap partition (ext4 partition-only mode)
      // lib.optionalAttrs (swapEnabled && fsType == "ext4" && swapPartition != null) {
        disko.devices.disk.swap = {
          type = "disk";
          device = swapPartition;
          content = {
            type = "swap";
            discardPolicy = "both";
            resumeDevice = true;
          };
        };
      }
      # Existing EFI partition — not managed by disko
      // {
        fileSystems."/boot/efi" = {
          device = efiDevice;
          fsType = "vfat";
          options = [
            "fmask=0022"
            "dmask=0022"
          ];
        };
      }
      # Btrfs swapfile
      // lib.optionalAttrs (swapEnabled && fsType == "btrfs") {
        swapDevices = [
          {
            device = "/swap/swapfile";
            size = lib.toInt (lib.removeSuffix "G" swapSize) * 1024;
          }
        ];
      };

    in
    if mode == "whole-disk" then wholeDiskConfig else partitionOnlyConfig;
}
