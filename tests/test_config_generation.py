"""
Unit tests for host configuration and Disko Nix code generation.
Directly mirrors installer-rs/tests/config_generation_tests.rs and provides additional coverage.
"""

import unittest

from installer.install import (
    BootloaderChoice,
    DualBootEntry,
    FeatureOption,
    GpuChoice,
    IgpuType,
    InstallConfig,
    InstallMode,
    ProfileChoice,
    build_features_override,
    build_profile_config,
    default_features,
    generate_disko_partition_only,
    generate_disko_whole_disk,
    generate_host_default_nix,
    strip_filesystems_from_hardware,
)


class TestConfigGeneration(unittest.TestCase):
    def test_generate_host_default_nix_base_grub(self):
        cfg = InstallConfig(
            hostname="TestServer",
            username="admin",
            hashed_pw="$6$testhash",
            profile=ProfileChoice.BASE,
            shell="zsh",
            bootloader=BootloaderChoice.GRUB,
            features=default_features(ProfileChoice.BASE),
            dual_boot_entries=[],
            mode=InstallMode.WHOLE_DISK,
            disk_dev="sda",
            swap_size="4G",
            fs_type="btrfs",
            root_size="100%",
            gpu_choice=GpuChoice.NONE,
        )

        content = generate_host_default_nix(cfg)
        self.assertIn('networking.hostName = "TestServer";', content)
        self.assertIn("home-manager.users.admin = {", content)
        self.assertIn("users.users.admin = {", content)
        self.assertIn('hashedPassword = "$6$testhash";', content)
        self.assertIn('northstar.features.boot.loader = "grub";', content)
        self.assertIn("base.enable = true;", content)
        self.assertNotIn("desktop.enable = true;", content)
        self.assertIn('system.stateVersion = "26.11";', content)

    def test_generate_host_default_nix_desktop_limine_with_dualboot(self):
        cfg = InstallConfig(
            hostname="DesktopHost",
            username="alice",
            hashed_pw="$6$alicehash",
            profile=ProfileChoice.DESKTOP,
            shell="fish",
            bootloader=BootloaderChoice.LIMINE,
            features=default_features(ProfileChoice.DESKTOP),
            dual_boot_entries=[
                DualBootEntry(
                    name="Windows 11",
                    efi_path="/EFI/Microsoft/Boot/bootmgfw.efi",
                    disk_uuid="ABCD-1234",
                    enabled=True,
                )
            ],
            mode=InstallMode.WHOLE_DISK,
            disk_dev="nvme0n1",
            swap_size="8G",
            fs_type="btrfs",
            root_size="100%",
            gpu_choice=GpuChoice.NONE,
        )

        content = generate_host_default_nix(cfg)
        self.assertIn('networking.hostName = "DesktopHost";', content)
        self.assertIn('northstar.features.boot.loader = "limine";', content)
        self.assertIn("boot.loader.limine.extraEntries = ''", content)
        self.assertIn("/Windows 11", content)
        self.assertIn("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi", content)
        self.assertIn("desktop.enable = true;", content)
        self.assertIn("shell = pkgs.fish;", content)

    def test_generate_host_default_nix_workstation_nvidia_prime(self):
        cfg = InstallConfig(
            hostname="Makima",
            username="reze",
            hashed_pw="$6$rezehash",
            profile=ProfileChoice.WORKSTATION,
            shell="zsh",
            bootloader=BootloaderChoice.GRUB,
            features=default_features(ProfileChoice.WORKSTATION),
            dual_boot_entries=[],
            mode=InstallMode.WHOLE_DISK,
            disk_dev="nvme0n1",
            swap_size="16G",
            fs_type="btrfs",
            root_size="100%",
            gpu_choice=GpuChoice.NVIDIA_PRIME,
            nvidia_bus_id="PCI:1:0:0",
            igpu_bus_id="PCI:5:0:0",
            igpu_type=IgpuType.AMD,
        )

        content = generate_host_default_nix(cfg)
        self.assertIn("desktop.enable = true;", content)
        self.assertIn("workstation.enable = true;", content)
        self.assertIn("northstar.nvidia.enable = true;", content)
        self.assertIn("northstar.nvidia.prime = {", content)
        self.assertIn('nvidiaBusId = "PCI:1:0:0";', content)
        self.assertIn('amdgpuBusId = "PCI:5:0:0";', content)

    def test_generate_disko_whole_disk_btrfs(self):
        cfg = InstallConfig(
            hostname="NixRig",
            disk_dev="nvme0n1",
            fs_type="btrfs",
            swap_size="16G",
            root_size="100%",
        )

        disko = generate_disko_whole_disk(cfg)
        self.assertIn("imports = [ ../../lib/disko/btrfs.nix ];", disko)
        self.assertIn('disko.devices.disk.main.device = "/dev/nvme0n1";', disko)
        self.assertIn('disko.devices.disk.main.content.partitions.swap.size = lib.mkForce "16G";', disko)

    def test_generate_disko_whole_disk_ext4(self):
        cfg = InstallConfig(
            hostname="Ext4Machine",
            disk_dev="sda",
            fs_type="ext4",
            swap_size="0",
            root_size="500G",
        )

        disko = generate_disko_whole_disk(cfg)
        self.assertIn("imports = [ ../../lib/disko/ext4.nix ];", disko)
        self.assertIn('disko.devices.disk.main.device = "/dev/sda";', disko)
        self.assertIn('disko.devices.disk.main.content.partitions.swap.size = lib.mkForce "0";', disko)
        self.assertIn('disko.devices.disk.main.content.partitions.root.size = lib.mkForce "500G";', disko)

    def test_generate_disko_partition_only_btrfs(self):
        cfg = InstallConfig(
            hostname="DualBootBtrfs",
            nixos_part="/dev/nvme0n1p3",
            efi_part="/dev/nvme0n1p1",
            fs_type="btrfs",
            swap_size="8G",
        )

        disko = generate_disko_partition_only(cfg, efi_uuid="1234-5678")
        self.assertIn('device = "/dev/nvme0n1p3";', disko)
        self.assertIn('type = "btrfs";', disko)
        self.assertIn('mountpoint = "/";', disko)
        self.assertIn('mountpoint = "/home";', disko)
        self.assertIn('mountpoint = "/nix";', disko)
        self.assertIn('mountpoint = "/var/log";', disko)
        self.assertIn('mountpoint = "/swap";', disko)
        self.assertIn('fileSystems."/boot/efi"', disko)
        self.assertIn('/dev/disk/by-uuid/1234-5678', disko)
        self.assertIn('{ device = "/swap/swapfile"; }', disko)

    def test_generate_disko_partition_only_ext4_with_swap(self):
        cfg = InstallConfig(
            hostname="DualBootExt4",
            nixos_part="/dev/sda3",
            efi_part="/dev/sda1",
            fs_type="ext4",
            swap_size="8G",
            swap_partition="/dev/sda4",
        )

        disko = generate_disko_partition_only(cfg, efi_uuid="ABCD-EF01")
        self.assertIn('device = "/dev/sda3";', disko)
        self.assertIn('format = "ext4";', disko)
        self.assertIn('mountpoint = "/";', disko)
        self.assertIn('disko.devices.disk.swap', disko)
        self.assertIn('device = "/dev/sda4";', disko)
        self.assertIn('fileSystems."/boot/efi"', disko)
        self.assertIn('/dev/disk/by-uuid/ABCD-EF01', disko)

    def test_strip_filesystems_from_hardware(self):
        raw_hw = """
# Do not modify this file!  It was generated by ‘nixos-generate-config’
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/12345";
      fsType = "btrfs";
      options = [ "subvol=root" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/67890";
      fsType = "vfat";
    };

  swapDevices = [ { device = "/dev/disk/by-uuid/abcde"; } ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
"""

        cleaned = strip_filesystems_from_hardware(raw_hw)
        self.assertNotIn('fileSystems."/"', cleaned)
        self.assertNotIn('fileSystems."/boot"', cleaned)
        self.assertNotIn("swapDevices", cleaned)
        self.assertIn('boot.kernelModules = [ "kvm-amd" ];', cleaned)
        self.assertIn("hardware.cpu.amd.updateMicrocode", cleaned)

    def test_build_profile_config(self):
        cfg_base = InstallConfig(profile=ProfileChoice.BASE)
        base_out = build_profile_config(cfg_base)
        self.assertIn("base.enable = true;", base_out)
        self.assertNotIn("desktop.enable = true;", base_out)

        cfg_desktop = InstallConfig(profile=ProfileChoice.DESKTOP)
        desktop_out = build_profile_config(cfg_desktop)
        self.assertIn("desktop.enable = true;", desktop_out)
        self.assertNotIn("workstation.enable = true;", desktop_out)

        cfg_workstation = InstallConfig(profile=ProfileChoice.WORKSTATION)
        ws_out = build_profile_config(cfg_workstation)
        self.assertIn("desktop.enable = true;", ws_out)
        self.assertIn("workstation.enable = true;", ws_out)

    def test_build_features_override(self):
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        # Default Desktop: hyprland is True, niri is False, fish is False, devtools is False
        # Let's toggle hyprland to False, and fish to True
        cfg.features = default_features(ProfileChoice.DESKTOP)
        for f in cfg.features:
            if f.id == "hyprland":
                f.enabled = False
            elif f.id == "fish":
                f.enabled = True

        override_block = build_features_override(cfg)
        self.assertIn("northstar.features = {", override_block)
        self.assertIn("hyprland.enable = false;", override_block)
        self.assertIn("fish.enable = true;", override_block)
        # Unchanged features (e.g. zsh is still True, devtools is still False) should not appear
        self.assertNotIn("zsh.enable", override_block)
        self.assertNotIn("devtools.enable", override_block)


if __name__ == "__main__":
    unittest.main()
