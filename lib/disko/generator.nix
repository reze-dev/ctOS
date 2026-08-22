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
  # parseSizeToMiB: robustly parse user size strings like "8G", "1024M" into MiB
  parseSizeToMiB =
    sizeStr:
    let
      match = builtins.match "^([0-9]+)([a-zA-Z%]*)$" (lib.strings.toUpper sizeStr);
      numStr = if match != null then builtins.elemAt match 0 else "8";
      suffix = if match != null then builtins.elemAt match 1 else "G";
      val = lib.toInt numStr;
    in
    if suffix == "G" || suffix == "GB" then
      val * 1024
    else if suffix == "M" || suffix == "MB" then
      val
    else if suffix == "T" || suffix == "TB" then
      val * 1024 * 1024
    else
      val * 1024;

  # mkDisko: generate a complete disko configuration attrset
  #
  # Arguments:
  #   mode        : "whole-disk" | "partition-only"
  #   fsType      : "btrfs" | "ext4"                     (default: "btrfs")
  #   device      : disk device path                      (whole-disk mode)
  #   nixosPart   : NixOS partition device path            (partition-only mode)
  #   efiDevice   : EFI partition device or UUID path      (partition-only: existing EFI)
  #   efiSize     : EFI partition size                     (whole-disk: default "2G")
  #   swapSize    : swap partition/file size, "0" to skip  (default: "16G")
  #   rootSize    : root partition size                    (default: "100%")
  #   swapPartition : dedicated swap partition device       (partition-only + ext4 only)
  #
  # Swap architecture by mode:
  #   - whole-disk:     Swap is a dedicated GPT partition managed by disko.
  #                     The btrfs /swap subvolume is NOT created (btrfsSubvolumes false)
  #                     because the swap lives on its own partition, not as a swapfile.
  #   - partition-only: Swap is a btrfs swapfile at /swap/swapfile inside a /swap subvolume
  #                     (btrfsSubvolumes swapEnabled), or for ext4 a separate swap partition
  #                     specified via swapPartition.
  mkDisko =
    {
      mode ? "whole-disk",
      fsType ? "btrfs",
      device ? null,
      nixosPart ? null,
      efiDevice ? null,
      efiSize ? "2G",
      swapSize ? "16G",
      rootSize ? "100%",
      swapPartition ? null,
      extraConfig ? { },
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
                      # false: no /swap subvolume needed — swap is a dedicated GPT partition
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
            size = parseSizeToMiB swapSize;
          }
        ];
      };

    in
    lib.recursiveUpdate (
      if mode == "whole-disk" then wholeDiskConfig else partitionOnlyConfig
    ) extraConfig;
}
