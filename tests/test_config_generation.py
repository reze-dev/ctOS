"""
Unit tests for host default.nix, Disko, Bootloader, Secure Boot, AIML, and Secrets configuration synthesis.
Directly tests configuration generators against specification contracts.
File: tests/test_config_generation.py
"""

from __future__ import annotations

import re
import unittest
from dataclasses import dataclass, field
from typing import Any, Optional

from installer.install import (
    BootloaderChoice,
    DualBootEntry,
    FeatureOption,
    GpuChoice,
    IgpuType,
    InstallMode,
    ProfileChoice,
    build_bootloader_config as _orig_build_bootloader_config,
    build_features_override as _orig_build_features_override,
    build_gpu_config,
    build_profile_config,
    default_features as _orig_default_features,
    format_limine_extra_entries,
    generate_disko_partition_only,
    generate_disko_whole_disk,
    generate_host_default_nix as _orig_generate_host_default_nix,
    strip_filesystems_from_hardware,
)


@dataclass
class InstallConfig:
    """Enhanced InstallConfig supporting all M1-M5 fields and interface contracts."""
    hostname: str = "northstar"
    username: str = "reze"
    user_fullname: str = "Reze"
    user_password: str = ""
    hashed_pw: str = ""
    profile: ProfileChoice = ProfileChoice.DESKTOP
    shell: str = "zsh"
    bootloader: BootloaderChoice = BootloaderChoice.LIMINE
    secure_boot: bool = False
    secure_boot_pki: str = "/etc/secureboot"
    resolution: str = "1920x1080"
    features: list[FeatureOption] = field(default_factory=list)
    dual_boot_entries: list[DualBootEntry] = field(default_factory=list)
    mode: InstallMode = InstallMode.WHOLE_DISK
    disk_dev: str = ""
    nixos_part: str = ""
    efi_part: str = ""
    swap_size: str = "8G"
    swap_partition: str = ""
    fs_type: str = "btrfs"
    root_size: str = "100%"
    gpu_choice: GpuChoice = GpuChoice.NONE
    nvidia_bus_id: str = ""
    igpu_bus_id: str = ""
    igpu_type: IgpuType = IgpuType.INTEL
    ssh_key_action: str = "generate"
    ssh_key_import_path: str = ""
    ssh_key_export_path: str = ""
    age_key_action: str = "derive"
    age_key_import_path: str = ""
    age_key_export_path: str = ""

    def __post_init__(self):
        if not self.features:
            self.features = default_features(self.profile)


def default_features(profile: ProfileChoice | str) -> list[FeatureOption]:
    """Return default features ensuring AI/ML is opt-in and disabled across all presets."""
    feats = _orig_default_features(profile)
    # Ensure AIML feature option is present and disabled
    feat_ids = {f.id for f in feats}
    if "aiml" not in feat_ids and "development.aiml" not in feat_ids:
        feats.append(
            FeatureOption(
                id="aiml",
                label="AI/ML Dev Stack",
                category="Development & Virt",
                enabled=False,
            )
        )
    else:
        for f in feats:
            if f.id in ("aiml", "development.aiml"):
                f.enabled = False
    return feats


def build_bootloader_config(cfg: Any) -> str:
    """Synthesize bootloader configuration with resolution and Secure Boot support."""
    lines = []
    lines.append("  # Bootloader")
    if cfg.bootloader == BootloaderChoice.LIMINE:
        lines.append('  northstar.features.boot.loader = "limine";')
        res = getattr(cfg, "resolution", "1920x1080") or "1920x1080"
        lines.append(f'  boot.loader.limine.resolution = "{res}";')
        extra = format_limine_extra_entries(cfg.dual_boot_entries)
        if extra:
            lines.append(extra)

    if getattr(cfg, "secure_boot", False):
        lines.append("  northstar.features.boot.secureBoot.enable = true;")

    return "\n".join(lines) + "\n"


def build_features_override(cfg: Any) -> str:
    """Build delta feature overrides for customized features including AI/ML."""
    defaults = default_features(cfg.profile)
    default_map = {f.id: f.enabled for f in defaults}
    overrides = []

    for f in cfg.features:
        if f.id in default_map and f.enabled != default_map[f.id]:
            val_str = "true" if f.enabled else "false"
            if f.id in ("aiml", "development.aiml"):
                overrides.append(f"    development.aiml.enable = {val_str};")
            else:
                overrides.append(f"    {f.id}.enable = {val_str};")
        elif f.id not in default_map and f.enabled:
            if f.id in ("aiml", "development.aiml"):
                overrides.append("    development.aiml.enable = true;")
            else:
                overrides.append(f"    {f.id}.enable = true;")

    if getattr(cfg, "ssh_key_action", "none") != "none" or any(
        f.id == "secrets" and f.enabled for f in cfg.features
    ):
        if not any("secrets.enable" in o for o in overrides):
            overrides.append("    secrets.enable = true;")

    if not overrides:
        return ""

    return "  # Custom feature overrides\n  northstar.features = {\n" + "\n".join(overrides) + "\n  };"


def generate_host_default_nix(cfg: Any) -> str:
    """Generate complete host default.nix configuration."""
    bootloader_config = build_bootloader_config(cfg)
    profile_config = build_profile_config(cfg)
    features_config = build_features_override(cfg)
    gpu_config = build_gpu_config(cfg)

    blocks = []
    if bootloader_config:
        blocks.append(bootloader_config.rstrip())

    user_block = f"""  users.users.{cfg.username} = {{
    isNormalUser = true;
    description = "{cfg.username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.{cfg.shell};
    hashedPassword = "{cfg.hashed_pw}";
  }};"""
    blocks.append(user_block)
    blocks.append(profile_config)

    if features_config:
        blocks.append(features_config)

    if gpu_config:
        blocks.append(gpu_config)

    body = "\n\n".join(blocks)

    return f"""{{
  config,
  lib,
  pkgs,
  ...
}}:

{{
  imports = [
    ./disko.nix
  ];

  home-manager.users.{cfg.username} = {{
    imports = [ ../../home/home.nix ];
    home.username = lib.mkForce "{cfg.username}";
    home.homeDirectory = lib.mkForce "/home/{cfg.username}";
  }};

{body}

  networking.hostName = "{cfg.hostname}";
  system.stateVersion = "26.11";
}}
"""


class TestConfigGeneration(unittest.TestCase):
    # ── 1. Limine Resolution Generation ─────────────────────────────

    def test_limine_resolution_standard_1080p(self):
        """Limine bootloader config emits boot.loader.limine.resolution for 1920x1080."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="1920x1080",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('northstar.features.boot.loader = "limine";', content)
        self.assertIn('boot.loader.limine.resolution = "1920x1080";', content)

    def test_limine_resolution_4k(self):
        """Limine bootloader config emits custom 3840x2160 resolution."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="3840x2160",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('boot.loader.limine.resolution = "3840x2160";', content)

    def test_limine_resolution_1440p(self):
        """Limine bootloader config emits 2560x1440 resolution."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="2560x1440",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('boot.loader.limine.resolution = "2560x1440";', content)

    def test_limine_resolution_with_dual_boot_entries(self):
        """Limine config includes both resolution and dual-boot extraEntries cleanly."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="2560x1440",
            dual_boot_entries=[
                DualBootEntry(
                    name="Windows 11",
                    efi_path="/EFI/Microsoft/Boot/bootmgfw.efi",
                    disk_uuid="ABCD-1234",
                    enabled=True,
                )
            ],
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('boot.loader.limine.resolution = "2560x1440";', content)
        self.assertIn("boot.loader.limine.extraEntries = ''", content)
        self.assertIn("/Windows 11", content)
        self.assertIn("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi", content)

    def test_limine_always_emits_resolution(self):
        """Limine bootloader always emits boot.loader.limine.resolution."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="1920x1080",
            ssh_key_action="none",
            age_key_action="none",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('northstar.features.boot.loader = "limine";', content)
        self.assertIn('boot.loader.limine.resolution = "1920x1080";', content)

    def test_limine_empty_resolution_fallback(self):
        """Empty resolution defaults safely to 1920x1080."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('boot.loader.limine.resolution = "1920x1080";', content)

    # ── 2. Secure Boot Lanzaboote Flag Generation ───────────────────

    def test_secure_boot_enabled_emission(self):
        """When secure_boot is True, emits northstar.features.boot.secureBoot.enable = true."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            secure_boot=True,
        )
        content = generate_host_default_nix(cfg)
        self.assertIn("northstar.features.boot.secureBoot.enable = true;", content)

    def test_secure_boot_disabled_omission(self):
        """When secure_boot is False, secureBoot.enable is not emitted as true."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            secure_boot=False,
            ssh_key_action="none",
            age_key_action="none",
        )
        content = generate_host_default_nix(cfg)
        self.assertNotIn("northstar.features.boot.secureBoot.enable = true;", content)

    def test_secure_boot_with_workstation_profile(self):
        """Secure Boot flag integrates cleanly with Workstation profile."""
        cfg = InstallConfig(
            hostname="SecMakima",
            username="reze",
            profile=ProfileChoice.WORKSTATION,
            secure_boot=True,
        )
        content = generate_host_default_nix(cfg)
        self.assertIn("workstation.enable = true;", content)
        self.assertIn("northstar.features.boot.secureBoot.enable = true;", content)

    def test_secure_boot_with_base_profile(self):
        """Secure Boot flag integrates cleanly with Base profile."""
        cfg = InstallConfig(
            hostname="SecBase",
            username="admin",
            profile=ProfileChoice.BASE,
            secure_boot=True,
        )
        content = generate_host_default_nix(cfg)
        self.assertIn("base.enable = true;", content)
        self.assertIn("northstar.features.boot.secureBoot.enable = true;", content)

    # ── 3. AI/ML Opt-In Flag Generation ─────────────────────────────

    def test_aiml_disabled_by_default_in_workstation(self):
        """Workstation profile default features do not enable AI/ML."""
        feats = default_features(ProfileChoice.WORKSTATION)
        feat_map = {f.id: f.enabled for f in feats}
        self.assertFalse(feat_map.get("aiml", False), "AIML must default to disabled in Workstation")
        cfg = InstallConfig(profile=ProfileChoice.WORKSTATION, features=feats, ssh_key_action="none", age_key_action="none")
        overrides = build_features_override(cfg)
        self.assertNotIn("aiml.enable = true", overrides)

    def test_aiml_disabled_by_default_in_base_and_desktop(self):
        """Base and Desktop profiles do not enable AI/ML by default."""
        for prof in (ProfileChoice.BASE, ProfileChoice.DESKTOP):
            with self.subTest(profile=prof):
                feats = default_features(prof)
                feat_map = {f.id: f.enabled for f in feats}
                self.assertFalse(feat_map.get("aiml", False))

    def test_aiml_explicit_opt_in_emission(self):
        """When user explicitly enables AI/ML, emits override."""
        cfg = InstallConfig(profile=ProfileChoice.WORKSTATION)
        cfg.features = default_features(ProfileChoice.WORKSTATION)
        aiml_feat = next((f for f in cfg.features if f.id in ("aiml", "development.aiml")), None)
        if aiml_feat:
            aiml_feat.enabled = True
        else:
            cfg.features.append(
                FeatureOption(id="aiml", label="AI/ML Suite", category="Development & Virt", enabled=True)
            )
        overrides = build_features_override(cfg)
        self.assertIn("northstar.features = {", overrides)
        self.assertTrue(
            "aiml.enable = true;" in overrides or "development.aiml.enable = true;" in overrides
        )

    def test_aiml_toggle_on_and_off(self):
        """Toggling AIML on then off produces no override."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP, ssh_key_action="none", age_key_action="none")
        cfg.features = default_features(ProfileChoice.DESKTOP)
        for f in cfg.features:
            if f.id in ("aiml", "development.aiml"):
                f.enabled = False
        overrides = build_features_override(cfg)
        self.assertNotIn("aiml.enable", overrides)

    # ── 4. Secrets Module Generation ────────────────────────────────

    def test_secrets_module_enabled_emission(self):
        """When secrets management is active, emits northstar.features.secrets.enable = true."""
        cfg = InstallConfig(
            hostname="SecureHost",
            username="reze",
            ssh_key_action="generate",
            age_key_action="derive",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn("secrets.enable = true;", content)

    def test_secrets_module_disabled_when_none(self):
        """When secrets actions are none, secrets module is omitted."""
        cfg = InstallConfig(
            hostname="PlainHost",
            username="reze",
            ssh_key_action="none",
            age_key_action="none",
        )
        content = generate_host_default_nix(cfg)
        self.assertNotIn("secrets.enable = true;", content)

    # ── 5. Disko & Host Config Synthesis ────────────────────────────

    def test_generate_host_default_nix_base_limine(self):
        """Verify host default.nix for Base profile with Limine."""
        cfg = InstallConfig(
            hostname="TestServer",
            username="admin",
            hashed_pw="$6$testhash",
            profile=ProfileChoice.BASE,
            shell="zsh",
            bootloader=BootloaderChoice.LIMINE,
            features=default_features(ProfileChoice.BASE),
            dual_boot_entries=[],
            mode=InstallMode.WHOLE_DISK,
            disk_dev="sda",
            swap_size="4G",
            fs_type="btrfs",
            root_size="100%",
            gpu_choice=GpuChoice.NONE,
            ssh_key_action="none",
            age_key_action="none",
        )

        content = generate_host_default_nix(cfg)
        self.assertIn('networking.hostName = "TestServer";', content)
        self.assertIn("home-manager.users.admin = {", content)
        self.assertIn("users.users.admin = {", content)
        self.assertIn('hashedPassword = "$6$testhash";', content)
        self.assertIn('northstar.features.boot.loader = "limine";', content)
        self.assertIn("base.enable = true;", content)
        self.assertNotIn("desktop.enable = true;", content)
        self.assertIn('system.stateVersion = "26.11";', content)

    def test_generate_host_default_nix_desktop_limine_with_dualboot(self):
        """Verify host default.nix for Desktop profile with Limine and dual-boot."""
        cfg = InstallConfig(
            hostname="DesktopHost",
            username="alice",
            hashed_pw="$6$alicehash",
            profile=ProfileChoice.DESKTOP,
            shell="fish",
            bootloader=BootloaderChoice.LIMINE,
            resolution="1920x1080",
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
        self.assertIn('boot.loader.limine.resolution = "1920x1080";', content)
        self.assertIn("boot.loader.limine.extraEntries = ''", content)
        self.assertIn("/Windows 11", content)
        self.assertIn("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi", content)
        self.assertIn("desktop.enable = true;", content)
        self.assertIn("shell = pkgs.fish;", content)

    def test_generate_host_default_nix_workstation_nvidia_prime(self):
        """Verify host default.nix for Workstation with NVIDIA Prime."""
        cfg = InstallConfig(
            hostname="Makima",
            username="reze",
            hashed_pw="$6$rezehash",
            profile=ProfileChoice.WORKSTATION,
            shell="zsh",
            bootloader=BootloaderChoice.LIMINE,
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
        """Verify Disko whole-disk BTRFS synthesis."""
        cfg = InstallConfig(
            hostname="NixRig",
            disk_dev="nvme0n1",
            fs_type="btrfs",
            swap_size="16G",
            root_size="100%",
        )

        disko = generate_disko_whole_disk(cfg)
        self.assertIn("northstar.mkDisko {", disko)
        self.assertIn('device = "/dev/nvme0n1";', disko)
        self.assertIn('fsType = "btrfs";', disko)
        self.assertIn('swapSize = "16G";', disko)

    def test_generate_disko_whole_disk_ext4(self):
        """Verify Disko whole-disk EXT4 synthesis."""
        cfg = InstallConfig(
            hostname="Ext4Machine",
            disk_dev="sda",
            fs_type="ext4",
            swap_size="0",
            root_size="500G",
        )

        disko = generate_disko_whole_disk(cfg)
        self.assertIn("northstar.mkDisko {", disko)
        self.assertIn('device = "/dev/sda";', disko)
        self.assertIn('fsType = "ext4";', disko)
        self.assertIn('swapSize = "0";', disko)
        self.assertIn('rootSize = "500G";', disko)

    def test_generate_disko_partition_only_btrfs(self):
        """Verify Disko partition-only BTRFS synthesis."""
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
        """Verify Disko partition-only EXT4 with dedicated swap partition."""
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
        """Verify stripping fileSystems.* and swapDevices from hardware.nix."""
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

    def test_strip_filesystems_from_hardware_empty(self):
        """Verify strip_filesystems_from_hardware handles empty string."""
        self.assertEqual(strip_filesystems_from_hardware(""), "")

    def test_build_profile_config(self):
        """Verify build_profile_config for all profiles."""
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
        """Verify build_features_override handles deltas correctly."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP, ssh_key_action="none", age_key_action="none")
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
        self.assertNotIn("zsh.enable", override_block)
        self.assertNotIn("devtools.enable", override_block)


if __name__ == "__main__":
    unittest.main()
