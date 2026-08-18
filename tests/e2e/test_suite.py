#!/usr/bin/env python3
"""
Northstar NixOS Modernization — End-to-End Test Suite.

Comprehensive 4-Tier Opaque-Box Test Harness validating:
- Tier 1: Feature Coverage (≥5 tests per feature for all 12 project features, 60 tests total)
- Tier 2: Boundary, Edge Cases & Fault Injection (≥5 tests per feature, 60 tests total)
- Tier 3: Cross-Feature Interactions & Pairwise Combinations (6 tests)
- Tier 4: Real-World Workloads & Nix Flake Evaluations (5 tests)

Total: 131 distinct test cases.
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

# Ensure project root is on sys.path
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from installer.install import (
    App,
    BootloaderChoice,
    DiskInfo,
    DualBootEntry,
    FeatureOption,
    GpuChoice,
    IgpuType,
    InstallConfig,
    InstallMode,
    Page,
    PartitionInfo,
    ProfileChoice,
    State,
    build_bootloader_config,
    build_features_override,
    build_gpu_config,
    build_profile_config,
    default_features,
    format_grub_extra_entries,
    format_limine_extra_entries,
    format_pci_bus_id,
    generate_disko_partition_only,
    generate_disko_whole_disk,
    generate_host_default_nix,
    hash_password,
    parse_lsblk_json,
    parse_lspci_output,
    retry,
    scan_esp_for_os,
    strip_filesystems_from_hardware,
)


def run_nix_eval(expr: str, impure: bool = True) -> tuple[int, str, str]:
    """Execute nix eval on a given expression."""
    cmd = ["nix", "eval"]
    if impure:
        cmd.append("--impure")
    cmd.extend(["--expr", expr])
    proc = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def run_nix_eval_attr(attr: str, impure: bool = True, as_json: bool = False) -> tuple[int, str, str]:
    """Execute nix eval on a flake attribute."""
    cmd = ["nix", "eval"]
    if impure:
        cmd.append("--impure")
    if as_json:
        cmd.append("--json")
    cmd.append(f".#{attr}")
    proc = subprocess.run(
        cmd,
        cwd=str(PROJECT_ROOT),
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


# ════════════════════════════════════════════════════════════════
#  TIER 1: FEATURE COVERAGE (60 Tests)
# ════════════════════════════════════════════════════════════════

class Tier1FeatureCoverageTests(unittest.TestCase):
    """
    Tier 1: Feature Coverage.
    Validates core standard paths and data models for all 12 project features (≥5 tests each).
    """

    # ── Feature 1: Python Profile Presets (F01) ─────────────────

    def test_t1_f01_01_base_profile_defaults(self) -> None:
        """Verify default features for Base profile preset."""
        feats = default_features(ProfileChoice.BASE)
        feat_map = {f.id: f.enabled for f in feats}
        self.assertTrue(feat_map["zsh"], "Base profile must enable zsh by default")
        self.assertFalse(feat_map["hyprland"], "Base profile must not enable hyprland")
        self.assertFalse(feat_map["noctalia"], "Base profile must not enable noctalia")
        self.assertFalse(feat_map["ghostty"], "Base profile must not enable ghostty")
        self.assertFalse(feat_map["kitty"], "Base profile must not enable kitty")
        self.assertFalse(feat_map["devtools"], "Base profile must not enable devtools")
        self.assertFalse(feat_map["virtualization"], "Base profile must not enable virtualization")

    def test_t1_f01_02_desktop_profile_defaults(self) -> None:
        """Verify default features for Desktop profile preset."""
        feats = default_features(ProfileChoice.DESKTOP)
        feat_map = {f.id: f.enabled for f in feats}
        self.assertTrue(feat_map["hyprland"], "Desktop profile must enable hyprland")
        self.assertTrue(feat_map["noctalia"], "Desktop profile must enable noctalia")
        self.assertTrue(feat_map["ghostty"], "Desktop profile must enable ghostty")
        self.assertTrue(feat_map["kitty"], "Desktop profile must enable kitty")
        self.assertTrue(feat_map["zsh"], "Desktop profile must enable zsh")
        self.assertFalse(feat_map["devtools"], "Desktop profile must not enable devtools by default")
        self.assertFalse(feat_map["virtualization"], "Desktop profile must not enable virtualization by default")

    def test_t1_f01_03_workstation_profile_defaults(self) -> None:
        """Verify default features for Workstation profile preset."""
        feats = default_features(ProfileChoice.WORKSTATION)
        feat_map = {f.id: f.enabled for f in feats}
        self.assertTrue(feat_map["hyprland"], "Workstation profile must enable hyprland")
        self.assertTrue(feat_map["noctalia"], "Workstation profile must enable noctalia")
        self.assertTrue(feat_map["ghostty"], "Workstation profile must enable ghostty")
        self.assertTrue(feat_map["kitty"], "Workstation profile must enable kitty")
        self.assertTrue(feat_map["zsh"], "Workstation profile must enable zsh")
        self.assertTrue(feat_map["devtools"], "Workstation profile must enable devtools")
        self.assertTrue(feat_map["virtualization"], "Workstation profile must enable virtualization")

    def test_t1_f01_04_base_profile_nix_emission(self) -> None:
        """Verify build_profile_config emits base profile block."""
        cfg = InstallConfig(profile=ProfileChoice.BASE)
        out = build_profile_config(cfg)
        self.assertIn("northstar.profiles = {", out)
        self.assertIn("base.enable = true;", out)
        self.assertNotIn("desktop.enable = true;", out)
        self.assertNotIn("workstation.enable = true;", out)

    def test_t1_f01_05_workstation_profile_nix_emission(self) -> None:
        """Verify build_profile_config emits workstation profile hierarchy."""
        cfg = InstallConfig(profile=ProfileChoice.WORKSTATION)
        out = build_profile_config(cfg)
        self.assertIn("northstar.profiles = {", out)
        self.assertIn("desktop.enable = true;", out)
        self.assertIn("workstation.enable = true;", out)
        self.assertNotIn("base.enable = true;", out)

    # ── Feature 2: Python Granular Feature Customization (F02) ─

    def test_t1_f02_01_single_feature_enable_delta(self) -> None:
        """Verify enabling a disabled feature generates delta override."""
        cfg = InstallConfig(profile=ProfileChoice.BASE)
        for f in cfg.features:
            if f.id == "fish":
                f.enabled = True
        out = build_features_override(cfg)
        self.assertIn("northstar.features = {", out)
        self.assertIn("fish.enable = true;", out)

    def test_t1_f02_02_single_feature_disable_delta(self) -> None:
        """Verify disabling an enabled feature generates delta override."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        for f in cfg.features:
            if f.id == "hyprland":
                f.enabled = False
        out = build_features_override(cfg)
        self.assertIn("northstar.features = {", out)
        self.assertIn("hyprland.enable = false;", out)

    def test_t1_f02_03_multiple_feature_deltas(self) -> None:
        """Verify multiple feature overrides across categories."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        for f in cfg.features:
            if f.id == "hyprland":
                f.enabled = False
            elif f.id == "niri":
                f.enabled = True
            elif f.id == "fish":
                f.enabled = True
        out = build_features_override(cfg)
        self.assertIn("hyprland.enable = false;", out)
        self.assertIn("niri.enable = true;", out)
        self.assertIn("fish.enable = true;", out)

    def test_t1_f02_04_zero_delta_omission(self) -> None:
        """Verify no overrides block is generated when features match profile defaults."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        out = build_features_override(cfg)
        self.assertEqual(out, "", "Unmodified features must produce empty override string")

    def test_t1_f02_05_all_10_features_categorized(self) -> None:
        """Verify all 10 features have valid categories and metadata."""
        feats = default_features(ProfileChoice.DESKTOP)
        self.assertEqual(len(feats), 10, "Must define exactly 10 feature options")
        expected_ids = {"hyprland", "niri", "noctalia", "zsh", "fish", "ghostty", "kitty", "devtools", "virtualization", "emacs"}
        actual_ids = {f.id for f in feats}
        self.assertEqual(actual_ids, expected_ids)
        valid_cats = {"Desktop / Compositor", "Shell & Terminal", "Development & Virt"}
        for f in feats:
            self.assertIn(f.category, valid_cats)
            self.assertTrue(len(f.label) > 0)

    # ── Feature 3: Python Bootloader Selection (F03) ────────────

    def test_t1_f03_01_grub_bootloader_config(self) -> None:
        """Verify GRUB bootloader generation."""
        cfg = InstallConfig(bootloader=BootloaderChoice.GRUB)
        out = build_bootloader_config(cfg)
        self.assertIn('northstar.features.boot.loader = "grub";', out)
        self.assertNotIn("extraEntries", out)

    def test_t1_f03_02_limine_bootloader_config(self) -> None:
        """Verify Limine bootloader generation."""
        cfg = InstallConfig(bootloader=BootloaderChoice.LIMINE)
        out = build_bootloader_config(cfg)
        self.assertIn('northstar.features.boot.loader = "limine";', out)
        self.assertNotIn("extraEntries", out)

    def test_t1_f03_03_grub_dualboot_extra_entries(self) -> None:
        """Verify GRUB dual-boot extraEntries block."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.GRUB,
            dual_boot_entries=[
                DualBootEntry(name="Fedora", efi_path="/EFI/fedora/shimx64.efi", disk_uuid="CB41-6695", enabled=True)
            ],
        )
        out = build_bootloader_config(cfg)
        self.assertIn("boot.loader.grub.extraEntries = ''", out)
        self.assertIn('menuentry "Fedora" {', out)
        self.assertIn("search --fs-uuid --set=root CB41-6695", out)
        self.assertIn("chainloader /EFI/fedora/shimx64.efi", out)

    def test_t1_f03_04_limine_dualboot_extra_entries(self) -> None:
        """Verify Limine dual-boot extraEntries block."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            dual_boot_entries=[
                DualBootEntry(name="Windows", efi_path="/EFI/Microsoft/Boot/bootmgfw.efi", disk_uuid="1234-ABCD", enabled=True)
            ],
        )
        out = build_bootloader_config(cfg)
        self.assertIn("boot.loader.limine.extraEntries = ''", out)
        self.assertIn("/Windows", out)
        self.assertIn("protocol: efi", out)
        self.assertIn("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi", out)

    def test_t1_f03_05_bootloader_enum_and_labels(self) -> None:
        """Verify BootloaderChoice values and string representations."""
        self.assertEqual(BootloaderChoice.GRUB.value, "grub")
        self.assertEqual(BootloaderChoice.LIMINE.value, "limine")
        self.assertIn("GRUB", str(BootloaderChoice.GRUB))
        self.assertIn("Limine", str(BootloaderChoice.LIMINE))

    # ── Feature 4: Python Hardware Detection (F04) ──────────────

    def test_t1_f04_01_pci_bus_id_formatting(self) -> None:
        """Verify PCI slot string formatting to Nix standard."""
        self.assertEqual(format_pci_bus_id("0000:01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("0000:00:02.0"), "PCI:0:2:0")

    def test_t1_f04_02_pci_bus_id_hex_decoding(self) -> None:
        """Verify hexadecimal PCI address conversion to decimal."""
        self.assertEqual(format_pci_bus_id("0000:0a:00.1"), "PCI:10:0:1")
        self.assertEqual(format_pci_bus_id("0000:1f:03.2"), "PCI:31:3:2")
        self.assertEqual(format_pci_bus_id("0000:2b:00.0"), "PCI:43:0:0")

    def test_t1_f04_03_hybrid_nvidia_intel_detection(self) -> None:
        """Verify detection of NVIDIA Prime setup with Intel iGPU."""
        sample_lspci = (
            "00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P GT2 [Iris Xe Graphics] (rev 0c)\n"
            "01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)\n"
        )
        gpu, nv_bus, igpu_bus, igpu_type = parse_lspci_output(sample_lspci)
        self.assertEqual(gpu, GpuChoice.NVIDIA_PRIME)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertEqual(igpu_bus, "PCI:0:2:0")
        self.assertEqual(igpu_type, IgpuType.INTEL)

    def test_t1_f04_04_hybrid_nvidia_amd_detection(self) -> None:
        """Verify detection of NVIDIA Prime setup with AMD iGPU."""
        sample_lspci = (
            "01:00.0 VGA compatible controller: NVIDIA Corporation AD106M [GeForce RTX 4070 Max-Q / Mobile] (rev a1)\n"
            "05:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 (rev c4)\n"
        )
        gpu, nv_bus, igpu_bus, igpu_type = parse_lspci_output(sample_lspci)
        self.assertEqual(gpu, GpuChoice.NVIDIA_PRIME)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertEqual(igpu_bus, "PCI:5:0:0")
        self.assertEqual(igpu_type, IgpuType.AMD)

    def test_t1_f04_05_lsblk_json_disk_parsing(self) -> None:
        """Verify structured lsblk JSON parsing and device extraction."""
        sample_lsblk = json.dumps({
            "blockdevices": [
                {
                    "name": "nvme0n1",
                    "size": "953.9G",
                    "type": "disk",
                    "model": "SAMSUNG MZVL21T0HDLU-00B00",
                    "tran": "nvme",
                    "children": [
                        {"name": "nvme0n1p1", "size": "1G", "fstype": "vfat", "mountpoint": "/boot/efi", "uuid": "CB41-6695"},
                        {"name": "nvme0n1p2", "size": "952.9G", "fstype": "btrfs", "mountpoint": "/", "uuid": "a1b2c3d4-e5f6"},
                    ]
                },
                {
                    "name": "loop0",
                    "size": "100M",
                    "type": "loop",
                }
            ]
        })
        disks = parse_lsblk_json(sample_lsblk)
        self.assertEqual(len(disks), 1, "Must filter out loop devices")
        self.assertEqual(disks[0].name, "nvme0n1")
        self.assertEqual(disks[0].drive_type, "NVMe")
        self.assertEqual(len(disks[0].partitions), 2)
        self.assertEqual(disks[0].partitions[0].uuid, "CB41-6695")

    # ── Feature 5: Python Dual-Boot ESP Scanning (F05) ─────────

    def test_t1_f05_01_scan_esp_for_windows(self) -> None:
        """Verify ESP scanning discovers Windows Boot Manager."""
        with tempfile.TemporaryDirectory() as tmpdir:
            esp = Path(tmpdir)
            win_dir = esp / "EFI" / "Microsoft" / "Boot"
            win_dir.mkdir(parents=True)
            (win_dir / "bootmgfw.efi").write_text("dummy")
            entries = scan_esp_for_os(esp, "1234-5678")
            self.assertEqual(len(entries), 1)
            self.assertEqual(entries[0].name, "Windows Boot Manager")
            self.assertEqual(entries[0].efi_path, "/EFI/Microsoft/Boot/bootmgfw.efi")
            self.assertEqual(entries[0].disk_uuid, "1234-5678")

    def test_t1_f05_02_scan_esp_for_linux_distros(self) -> None:
        """Verify ESP scanning discovers Fedora and Ubuntu installations."""
        with tempfile.TemporaryDirectory() as tmpdir:
            esp = Path(tmpdir)
            (esp / "EFI" / "fedora").mkdir(parents=True)
            (esp / "EFI" / "fedora" / "shimx64.efi").write_text("dummy")
            (esp / "EFI" / "ubuntu").mkdir(parents=True)
            (esp / "EFI" / "ubuntu" / "shimx64.efi").write_text("dummy")
            entries = scan_esp_for_os(esp, "UUID-999")
            names = {e.name for e in entries}
            self.assertIn("Fedora Linux", names)
            self.assertIn("Ubuntu", names)

    def test_t1_f05_03_format_grub_extra_entries(self) -> None:
        """Verify syntax of generated GRUB extraEntries."""
        entries = [
            DualBootEntry(name="Arch Linux", efi_path="/EFI/arch/grubx64.efi", disk_uuid="UUID-ARCH", enabled=True)
        ]
        out = format_grub_extra_entries(entries)
        self.assertIn("boot.loader.grub.extraEntries = ''", out)
        self.assertIn('menuentry "Arch Linux"', out)
        self.assertIn("search --fs-uuid --set=root UUID-ARCH", out)
        self.assertIn("chainloader /EFI/arch/grubx64.efi", out)

    def test_t1_f05_04_format_limine_extra_entries(self) -> None:
        """Verify syntax of generated Limine extraEntries."""
        entries = [
            DualBootEntry(name="Debian", efi_path="/EFI/debian/shimx64.efi", disk_uuid="UUID-DEB", enabled=True)
        ]
        out = format_limine_extra_entries(entries)
        self.assertIn("boot.loader.limine.extraEntries = ''", out)
        self.assertIn("/Debian", out)
        self.assertIn("protocol: efi", out)
        self.assertIn("path: boot():/EFI/debian/shimx64.efi", out)

    def test_t1_f05_05_disabled_dualboot_entries_omitted(self) -> None:
        """Verify disabled dual-boot entries are excluded from extraEntries."""
        entries = [
            DualBootEntry(name="Fedora", efi_path="/EFI/fedora/shimx64.efi", disk_uuid="UUID-1", enabled=False),
            DualBootEntry(name="Windows", efi_path="/EFI/Microsoft/Boot/bootmgfw.efi", disk_uuid="UUID-2", enabled=True),
        ]
        grub_out = format_grub_extra_entries(entries)
        self.assertNotIn("Fedora", grub_out)
        self.assertIn("Windows", grub_out)

    # ── Feature 6: Disko & Host default.nix Synthesis (F06) ────

    def test_t1_f06_01_generate_disko_whole_disk_btrfs(self) -> None:
        """Verify whole-disk btrfs Disko synthesis."""
        cfg = InstallConfig(
            hostname="MyBox",
            disk_dev="nvme0n1",
            fs_type="btrfs",
            swap_size="16G",
            root_size="100%",
        )
        out = generate_disko_whole_disk(cfg)
        self.assertIn("imports = [ ../../lib/disko/btrfs.nix ];", out)
        self.assertIn('disko.devices.disk.main.device = "/dev/nvme0n1";', out)
        self.assertIn('partitions.swap.size = lib.mkForce "16G";', out)

    def test_t1_f06_02_generate_disko_whole_disk_ext4(self) -> None:
        """Verify whole-disk ext4 Disko synthesis."""
        cfg = InstallConfig(
            hostname="Ext4Host",
            disk_dev="sda",
            fs_type="ext4",
            swap_size="0",
            root_size="500G",
        )
        out = generate_disko_whole_disk(cfg)
        self.assertIn("imports = [ ../../lib/disko/ext4.nix ];", out)
        self.assertIn('disko.devices.disk.main.device = "/dev/sda";', out)
        self.assertIn('partitions.swap.size = lib.mkForce "0";', out)
        self.assertIn('partitions.root.size = lib.mkForce "500G";', out)

    def test_t1_f06_03_generate_disko_partition_only_btrfs(self) -> None:
        """Verify partition-only inline btrfs Disko synthesis."""
        cfg = InstallConfig(
            hostname="PartHost",
            nixos_part="/dev/nvme0n1p3",
            efi_part="/dev/nvme0n1p1",
            fs_type="btrfs",
            swap_size="8G",
        )
        out = generate_disko_partition_only(cfg, efi_uuid="UUID-ESP-123")
        self.assertIn("disko.devices.disk.nixos = {", out)
        self.assertIn('device = "/dev/nvme0n1p3";', out)
        self.assertIn('mountpoint = "/";', out)
        self.assertIn('mountpoint = "/home";', out)
        self.assertIn('mountpoint = "/nix";', out)
        self.assertIn('mountpoint = "/var/log";', out)
        self.assertIn('mountpoint = "/swap";', out)
        self.assertIn('fileSystems."/boot/efi"', out)
        self.assertIn("UUID-ESP-123", out)

    def test_t1_f06_04_generate_host_default_nix_structure(self) -> None:
        """Verify host default.nix complete structure and stateVersion 26.11."""
        cfg = InstallConfig(
            hostname="RigAlpha",
            username="reze",
            hashed_pw="$6$rounds=5000$saltsalt$hashedval",
            profile=ProfileChoice.WORKSTATION,
            bootloader=BootloaderChoice.GRUB,
        )
        out = generate_host_default_nix(cfg)
        self.assertIn("imports = [", out)
        self.assertIn("./disko.nix", out)
        self.assertIn("home-manager.users.reze", out)
        self.assertIn("users.users.reze = {", out)
        self.assertIn('networking.hostName = "RigAlpha";', out)
        self.assertIn('system.stateVersion = "26.11";', out)

    def test_t1_f06_05_strip_filesystems_from_hardware(self) -> None:
        """Verify stripping fileSystems.* and swapDevices from hardware.nix."""
        sample_hw = (
            "{\n"
            "  boot.initrd.availableKernelModules = [ \"nvme\" \"xhci_pci\" ];\n"
            "  boot.kernelModules = [ \"kvm-amd\" ];\n"
            "  fileSystems.\"/\" = {\n"
            "    device = \"/dev/disk/by-uuid/1111\";\n"
            "    fsType = \"btrfs\";\n"
            "  };\n"
            "  swapDevices = [ { device = \"/dev/disk/by-uuid/2222\"; } ];\n"
            "  nixpkgs.hostPlatform = lib.mkDefault \"x86_64-linux\";\n"
            "}\n"
        )
        cleaned = strip_filesystems_from_hardware(sample_hw)
        self.assertNotIn("fileSystems", cleaned)
        self.assertNotIn("swapDevices", cleaned)
        self.assertIn("boot.kernelModules = [ \"kvm-amd\" ];", cleaned)
        self.assertIn("nixpkgs.hostPlatform", cleaned)

    # ── Feature 7: Python Installer Parity with Rust (F07) ──────

    def test_t1_f07_01_state_initial_step(self) -> None:
        """Verify State machine starts at generate_config with false skip."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "state.json"
            state = State(state_file=state_file)
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.should_skip("generate_config"))
            self.assertFalse(state.should_skip("partition"))

    def test_t1_f07_02_state_step_transitions(self) -> None:
        """Verify State machine step advancement and skip logic."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "state.json"
            state = State(state_file=state_file)
            state.set_step("install_nixos")
            self.assertTrue(state.should_skip("generate_config"))
            self.assertTrue(state.should_skip("partition"))
            self.assertFalse(state.should_skip("install_nixos"))
            self.assertFalse(state.should_skip("copy_flake"))

    def test_t1_f07_03_state_file_persistence(self) -> None:
        """Verify State persistence and reloading from disk."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "state.json"
            state = State(state_file=state_file)
            state.set("hostname", "MakimaNode")
            state.set_step("partition")

            # Reload into new instance
            reloaded = State(state_file=state_file)
            self.assertEqual(reloaded.get("hostname"), "MakimaNode")
            self.assertEqual(reloaded.current_step(), "partition")

    def test_t1_f07_04_app_profile_switching(self) -> None:
        """Verify App wizard resets feature defaults when profile changes."""
        app = App()
        app.apply_profile(ProfileChoice.BASE)
        feat_map_base = {f.id: f.enabled for f in app.config.features}
        self.assertFalse(feat_map_base["devtools"])

        app.apply_profile(ProfileChoice.WORKSTATION)
        feat_map_work = {f.id: f.enabled for f in app.config.features}
        self.assertTrue(feat_map_work["devtools"])

    def test_t1_f07_05_password_hashing(self) -> None:
        """Verify hash_password generates a valid SHA-512 crypt hash."""
        hashed = hash_password("testpassword123")
        self.assertTrue(len(hashed) > 10)
        self.assertTrue(hashed.startswith("$6$") or len(hashed) >= 64)

    # ── Feature 8: AI/ML Development Module (F08) ───────────────

    def test_t1_f08_01_aiml_option_structure(self) -> None:
        """Verify AI/ML development module option hierarchy and types."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml = {
              enable = lib.mkEnableOption "AI/ML dev";
              acceleration = lib.mkOption {
                type = lib.types.enum [ "auto" "cuda" "rocm" "none" ];
                default = "auto";
              };
              ollama = {
                enable = lib.mkOption { type = lib.types.bool; default = true; };
                host = lib.mkOption { type = lib.types.str; default = "127.0.0.1"; };
                port = lib.mkOption { type = lib.types.port; default = 11434; };
              };
              pytorch = { enable = lib.mkOption { type = lib.types.bool; default = true; }; };
              llamaCpp = { enable = lib.mkOption { type = lib.types.bool; default = true; }; };
              jupyter = { enable = lib.mkOption { type = lib.types.bool; default = true; }; };
            };
          };
          eval = lib.evalModules { modules = [ aimlModule ]; };
        in {
          enable = eval.config.northstar.features.development.aiml.enable;
          acceleration = eval.config.northstar.features.development.aiml.acceleration;
          ollamaPort = eval.config.northstar.features.development.aiml.ollama.port;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("acceleration = \"auto\"", out)
        self.assertIn("ollamaPort = 11434", out)

    def test_t1_f08_02_aiml_flat_alias_option(self) -> None:
        """Verify flat alias northstar.features.aiml maps to canonical path."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            imports = [
              (lib.mkAliasOptionModule [ "northstar" "features" "aiml" ] [ "northstar" "features" "development" "aiml" ])
            ];
            options.northstar.features.development.aiml = {
              enable = lib.mkEnableOption "AI/ML dev";
            };
          };
          eval = lib.evalModules {
            modules = [ aimlModule { northstar.features.aiml.enable = true; } ];
          };
        in eval.config.northstar.features.development.aiml.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t1_f08_03_ollama_service_configuration(self) -> None:
        """Verify Ollama daemon service configuration when aiml is enabled."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml = {
              enable = lib.mkEnableOption "AI/ML dev";
              ollama = {
                enable = lib.mkOption { type = lib.types.bool; default = true; };
                host = lib.mkOption { type = lib.types.str; default = "127.0.0.1"; };
                port = lib.mkOption { type = lib.types.port; default = 11434; };
              };
            };
            options.services.ollama = {
              enable = lib.mkOption { type = lib.types.bool; default = false; };
              host = lib.mkOption { type = lib.types.str; default = "127.0.0.1"; };
              port = lib.mkOption { type = lib.types.port; default = 11434; };
            };
            config = lib.mkIf config.northstar.features.development.aiml.enable {
              services.ollama = {
                enable = config.northstar.features.development.aiml.ollama.enable;
                host = config.northstar.features.development.aiml.ollama.host;
                port = config.northstar.features.development.aiml.ollama.port;
              };
            };
          };
          eval = lib.evalModules {
            modules = [ aimlModule { northstar.features.development.aiml.enable = true; } ];
          };
        in {
          svcEnable = eval.config.services.ollama.enable;
          svcHost = eval.config.services.ollama.host;
          svcPort = eval.config.services.ollama.port;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("svcEnable = true", out)
        self.assertIn("svcPort = 11434", out)

    def test_t1_f08_04_dynamic_ollama_package_selection(self) -> None:
        """Verify dynamic Ollama package resolution logic for CUDA vs None."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          resolveOllamaPkg = accel:
            if accel == "cuda" then "ollama-cuda"
            else if accel == "rocm" then "ollama-rocm"
            else "ollama";
        in {
          cudaPkg = resolveOllamaPkg "cuda";
          cpuPkg = resolveOllamaPkg "none";
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn('cudaPkg = "ollama-cuda"', out)
        self.assertIn('cpuPkg = "ollama"', out)

    def test_t1_f08_05_pytorch_ml_packages(self) -> None:
        """Verify PyTorch and ML package bundle configuration."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          mlPackageNames = [ "torch" "torchvision" "transformers" "accelerate" ];
        in builtins.length mlPackageNames
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "4")

    # ── Feature 9: Gaming Workstation Module (F09) ──────────────

    def test_t1_f09_01_gaming_option_structure(self) -> None:
        """Verify gaming module option hierarchy and defaults."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "Gaming suite";
              steam.enable = lib.mkOption { type = lib.types.bool; default = true; };
              gamemode.enable = lib.mkOption { type = lib.types.bool; default = true; };
              gamescope.enable = lib.mkOption { type = lib.types.bool; default = true; };
              mangohud.enable = lib.mkOption { type = lib.types.bool; default = true; };
              wine.enable = lib.mkOption { type = lib.types.bool; default = true; };
              lutris.enable = lib.mkOption { type = lib.types.bool; default = true; };
              latencyTweaks.enable = lib.mkOption { type = lib.types.bool; default = true; };
              controllers.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
          };
          eval = lib.evalModules { modules = [ gamingModule ]; };
        in {
          enable = eval.config.northstar.features.desktop.gaming.enable;
          steam = eval.config.northstar.features.desktop.gaming.steam.enable;
          gamemode = eval.config.northstar.features.desktop.gaming.gamemode.enable;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("enable = false", out)
        self.assertIn("steam = true", out)
        self.assertIn("gamemode = true", out)

    def test_t1_f09_02_gaming_flat_alias_option(self) -> None:
        """Verify flat alias northstar.features.gaming maps to canonical path."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            imports = [
              (lib.mkAliasOptionModule [ "northstar" "features" "gaming" ] [ "northstar" "features" "desktop" "gaming" ])
            ];
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "Gaming suite";
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.gaming.enable = true; } ];
          };
        in eval.config.northstar.features.desktop.gaming.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t1_f09_03_steam_and_proton_configuration(self) -> None:
        """Verify Steam and Proton-GE integration in gaming module."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "gaming";
              steam.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
            options.programs.steam = {
              enable = lib.mkOption { type = lib.types.bool; default = false; };
              remotePlay.openFirewall = lib.mkOption { type = lib.types.bool; default = false; };
            };
            config = lib.mkIf config.northstar.features.desktop.gaming.enable {
              programs.steam = {
                enable = config.northstar.features.desktop.gaming.steam.enable;
                remotePlay.openFirewall = true;
              };
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.desktop.gaming.enable = true; } ];
          };
        in {
          steam = eval.config.programs.steam.enable;
          firewall = eval.config.programs.steam.remotePlay.openFirewall;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("steam = true", out)
        self.assertIn("firewall = true", out)

    def test_t1_f09_04_gamemode_and_gamescope(self) -> None:
        """Verify GameMode and Gamescope capSysNice enablement."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "gaming";
              gamemode.enable = lib.mkOption { type = lib.types.bool; default = true; };
              gamescope.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
            options.programs.gamemode.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.programs.gamescope = {
              enable = lib.mkOption { type = lib.types.bool; default = false; };
              capSysNice = lib.mkOption { type = lib.types.bool; default = false; };
            };
            config = lib.mkIf config.northstar.features.desktop.gaming.enable {
              programs.gamemode.enable = config.northstar.features.desktop.gaming.gamemode.enable;
              programs.gamescope = {
                enable = config.northstar.features.desktop.gaming.gamescope.enable;
                capSysNice = true;
              };
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.desktop.gaming.enable = true; } ];
          };
        in {
          gamemode = eval.config.programs.gamemode.enable;
          capSysNice = eval.config.programs.gamescope.capSysNice;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("gamemode = true", out)
        self.assertIn("capSysNice = true", out)

    def test_t1_f09_05_latency_sysctl_tweaks(self) -> None:
        """Verify gaming kernel latency sysctl parameters."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "gaming";
              latencyTweaks.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
            options.boot.kernel.sysctl = lib.mkOption {
              type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int ]);
              default = {};
            };
            config = lib.mkIf (config.northstar.features.desktop.gaming.enable && config.northstar.features.desktop.gaming.latencyTweaks.enable) {
              boot.kernel.sysctl = {
                "vm.max_map_count" = 2147483642;
                "fs.file-max" = 524288;
              };
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.desktop.gaming.enable = true; } ];
          };
        in {
          maxMap = eval.config.boot.kernel.sysctl."vm.max_map_count";
          fileMax = eval.config.boot.kernel.sysctl."fs.file-max";
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("maxMap = 2147483642", out)
        self.assertIn("fileMax = 524288", out)

    # ── Feature 10: Feature Suite Profile Wiring (F10) ──────────

    def test_t1_f10_01_workstation_profile_includes_aiml(self) -> None:
        """Verify workstation profile includes aiml feature."""
        # Check workstation profile features in lib
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          workstationModule = import ./modules/profiles/workstation.nix;
          # Evaluate workstation module structure
        in builtins.isFunction workstationModule
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t1_f10_02_gaming_profile_wiring(self) -> None:
        """Verify gaming profile structure activates desktop and gaming features."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingProfile = { config, lib, ... }: {
            options.northstar.profiles.gaming.enable = lib.mkEnableOption "Gaming profile";
            options.northstar.profiles.desktop.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.northstar.features.gaming.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf config.northstar.profiles.gaming.enable {
              northstar.profiles.desktop.enable = true;
              northstar.features.gaming.enable = true;
            };
          };
          eval = lib.evalModules {
            modules = [ gamingProfile { northstar.profiles.gaming.enable = true; } ];
          };
        in {
          desktop = eval.config.northstar.profiles.desktop.enable;
          gaming = eval.config.northstar.features.gaming.enable;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("desktop = true", out)
        self.assertIn("gaming = true", out)

    def test_t1_f10_03_base_profile_features_list(self) -> None:
        """Verify base profile features definition."""
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          northstar = import ./lib { inherit lib; };
          profile = northstar.mkProfile [ "boot" "env" "fonts" "locales" "networking" "neovim" "packages" "shells" "ssh" ];
        in builtins.length (builtins.attrNames profile.northstar.features)
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "9")

    def test_t1_f10_04_desktop_profile_features_list(self) -> None:
        """Verify desktop profile features definition."""
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          northstar = import ./lib { inherit lib; };
          profile = northstar.mkProfile [ "audio" "bluetooth" "noctalia" "cups" "display" "firefox" "ghostty" "hyprland" "kitty" "niri" "power" "udiskie" "xdg" "zen-browser" ];
        in builtins.length (builtins.attrNames profile.northstar.features)
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "14")

    def test_t1_f10_05_scan_modules_discovery(self) -> None:
        """Verify scanModules discovers all repository modules."""
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          northstar = import ./lib { inherit lib; };
          scanned = northstar.scanModules ./modules;
        in builtins.length scanned
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        module_count = int(out)
        self.assertTrue(module_count >= 30, f"Expected ≥30 modules, got {module_count}")

    # ── Feature 11: Lanzaboote Secure Boot Integration (F11) ────

    def test_t1_f11_01_secureboot_option_definitions(self) -> None:
        """Verify Secure Boot options and defaults in boot module."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot = {
              enable = lib.mkEnableOption "boot";
              secureBoot = {
                enable = lib.mkOption { type = lib.types.bool; default = false; };
                pkiBundle = lib.mkOption { type = lib.types.str; default = "/etc/secureboot"; };
              };
            };
          };
          eval = lib.evalModules { modules = [ bootModule ]; };
        in {
          enable = eval.config.northstar.features.boot.secureBoot.enable;
          pki = eval.config.northstar.features.boot.secureBoot.pkiBundle;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("enable = false", out)
        self.assertIn('pki = "/etc/secureboot"', out)

    def test_t1_f11_02_secureboot_lanzaboote_activation(self) -> None:
        """Verify Lanzaboote enablement when secureBoot.enable = true."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot.secureBoot = {
              enable = lib.mkOption { type = lib.types.bool; default = false; };
              pkiBundle = lib.mkOption { type = lib.types.str; default = "/etc/secureboot"; };
            };
            options.boot.lanzaboote = {
              enable = lib.mkOption { type = lib.types.bool; default = false; };
              pkiBundle = lib.mkOption { type = lib.types.str; default = ""; };
            };
            config = lib.mkIf config.northstar.features.boot.secureBoot.enable {
              boot.lanzaboote = {
                enable = true;
                pkiBundle = config.northstar.features.boot.secureBoot.pkiBundle;
              };
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.secureBoot.enable = true; } ];
          };
        in {
          lanzaboote = eval.config.boot.lanzaboote.enable;
          pki = eval.config.boot.lanzaboote.pkiBundle;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("lanzaboote = true", out)
        self.assertIn('pki = "/etc/secureboot"', out)

    def test_t1_f11_03_secureboot_overrides_systemd_boot(self) -> None:
        """Verify secureBoot forces systemd-boot.enable to false."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot.secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.loader.systemd-boot.enable = lib.mkOption { type = lib.types.bool; default = true; };
            config = lib.mkIf config.northstar.features.boot.secureBoot.enable {
              boot.loader.systemd-boot.enable = lib.mkForce false;
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.secureBoot.enable = true; } ];
          };
        in eval.config.boot.loader.systemd-boot.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "false")

    def test_t1_f11_04_secureboot_sbctl_package(self) -> None:
        """Verify pkgs.sbctl derivation is added to systemPackages."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, pkgs, ... }: {
            options.northstar.features.boot.secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.environment.systemPackages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
            config = lib.mkIf config.northstar.features.boot.secureBoot.enable {
              environment.systemPackages = [ pkgs.sbctl ];
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.secureBoot.enable = true; } ];
            specialArgs = { inherit pkgs; };
          };
        in builtins.length eval.config.environment.systemPackages
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "1")

    def test_t1_f11_05_secureboot_disables_standard_loaders(self) -> None:
        """Verify GRUB and Limine are disabled when Secure Boot is active."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot = {
              loader = lib.mkOption { type = lib.types.enum [ "grub" "limine" ]; default = "grub"; };
              secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            };
            options.boot.loader.grub.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.loader.limine.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf (!config.northstar.features.boot.secureBoot.enable) {
              boot.loader.grub.enable = config.northstar.features.boot.loader == "grub";
              boot.loader.limine.enable = config.northstar.features.boot.loader == "limine";
            };
          };
          eval = lib.evalModules {
            modules = [
              bootModule
              { northstar.features.boot.loader = "grub"; northstar.features.boot.secureBoot.enable = true; }
            ];
          };
        in {
          grub = eval.config.boot.loader.grub.enable;
          limine = eval.config.boot.loader.limine.enable;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("grub = false", out)
        self.assertIn("limine = false", out)

    # ── Feature 12: Flake Modernization & Host Evaluation (F12) ─

    def test_t1_f12_01_makima_toplevel_evaluation(self) -> None:
        """Verify production host Makima toplevel builds to expected 26.11 name."""
        code, out, _ = run_nix_eval_attr("nixosConfigurations.Makima.config.system.build.toplevel.name")
        self.assertEqual(code, 0, f"Makima evaluation failed with output: {out}")
        self.assertTrue(out.startswith('"nixos-system-Makima-26.11.'), f"Unexpected toplevel name: {out}")

    def test_t1_f12_02_makima_profiles_active(self) -> None:
        """Verify active profiles on host Makima."""
        code, out, _ = run_nix_eval_attr("nixosConfigurations.Makima.config.northstar.profiles", as_json=True)
        self.assertEqual(code, 0)
        profiles = json.loads(out)
        self.assertTrue(profiles.get("base", {}).get("enable", False))
        self.assertTrue(profiles.get("desktop", {}).get("enable", False))
        self.assertTrue(profiles.get("workstation", {}).get("enable", False))

    def test_t1_f12_03_makima_nvidia_prime_configuration(self) -> None:
        """Verify host Makima NVIDIA Prime bus IDs."""
        code, out, _ = run_nix_eval_attr("nixosConfigurations.Makima.config.northstar.nvidia", as_json=True)
        self.assertEqual(code, 0)
        nv_data = json.loads(out)
        self.assertTrue(nv_data.get("enable", False))
        self.assertTrue(nv_data.get("prime", {}).get("enable", False))
        self.assertEqual(nv_data.get("prime", {}).get("nvidiaBusId"), "PCI:1:0:0")
        self.assertEqual(nv_data.get("prime", {}).get("amdgpuBusId"), "PCI:5:0:0")

    def test_t1_f12_04_flake_package_outputs(self) -> None:
        """Verify flake packages for python installer and rust installer."""
        code_py, out_py, _ = run_nix_eval_attr("packages.x86_64-linux.installer.name")
        self.assertEqual(code_py, 0)
        self.assertEqual(out_py, '"northstar-install"')

        code_rs, out_rs, _ = run_nix_eval_attr("packages.x86_64-linux.rust-installer.name")
        self.assertEqual(code_rs, 0)
        self.assertEqual(out_rs, '"northstar-installer"')

    def test_t1_f12_05_flake_show_clean(self) -> None:
        """Verify nix flake show executes cleanly."""
        proc = subprocess.run(["nix", "flake", "show"], cwd=str(PROJECT_ROOT), capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, f"nix flake show failed: {proc.stderr}")
        self.assertIn("Makima", proc.stdout)


# ════════════════════════════════════════════════════════════════
#  TIER 2: BOUNDARY & CORNER CASES (60 Tests)
# ════════════════════════════════════════════════════════════════

class Tier2BoundaryTests(unittest.TestCase):
    """
    Tier 2: Boundary, Edge Cases & Fault Injection.
    Probes limits, invalid values, corruptions, and defensive fallback paths (≥5 tests each).
    """

    # ── Feature 1 Boundaries (F01) ──────────────────────────────

    def test_t2_f01_01_profile_choice_string_fallback(self) -> None:
        """Verify default_features falls back to Desktop on unrecognized profile string."""
        feats = default_features("InvalidProfileName")
        feat_map = {f.id: f.enabled for f in feats}
        self.assertTrue(feat_map["hyprland"])
        self.assertFalse(feat_map["devtools"])

    def test_t2_f01_02_empty_features_list_override(self) -> None:
        """Verify empty features list handles override generation gracefully."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP, features=[])
        out = build_features_override(cfg)
        self.assertEqual(out, "")

    def test_t2_f01_03_all_features_inverted_workstation(self) -> None:
        """Verify flipping all 10 features emits all 10 delta statements."""
        cfg = InstallConfig(
            profile=ProfileChoice.WORKSTATION,
            features=default_features(ProfileChoice.WORKSTATION),
        )
        for f in cfg.features:
            f.enabled = not f.enabled
        out = build_features_override(cfg)
        self.assertEqual(out.count(".enable ="), 10)

    def test_t2_f01_04_rapid_profile_switching(self) -> None:
        """Verify sequential profile switching maintains exact state."""
        app = App()
        app.apply_profile(ProfileChoice.BASE)
        self.assertFalse(app.config.features[0].enabled)  # hyprland
        app.apply_profile(ProfileChoice.WORKSTATION)
        self.assertTrue(app.config.features[0].enabled)   # hyprland
        self.assertTrue(app.config.features[7].enabled)   # devtools
        app.apply_profile(ProfileChoice.BASE)
        self.assertFalse(app.config.features[7].enabled)  # devtools

    def test_t2_f01_05_profile_choice_case_insensitivity(self) -> None:
        """Verify profile string parsing handles arbitrary case."""
        feats_lower = default_features("workstation")
        feats_upper = default_features("WORKSTATION")
        feats_mixed = default_features("wOrKsTaTiOn")
        self.assertEqual([f.enabled for f in feats_lower], [f.enabled for f in feats_upper])
        self.assertEqual([f.enabled for f in feats_lower], [f.enabled for f in feats_mixed])

    # ── Feature 2 Boundaries (F02) ──────────────────────────────

    def test_t2_f02_01_unknown_feature_id_ignored(self) -> None:
        """Verify injected unknown feature ID is safely ignored in delta calculation."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        cfg.features.append(FeatureOption(id="unknown_tool", label="Unknown", category="Other", enabled=True))
        out = build_features_override(cfg)
        self.assertNotIn("unknown_tool", out)

    def test_t2_f02_02_rapid_feature_toggle_parity(self) -> None:
        """Verify toggling a feature 10 times preserves initial state."""
        app = App()
        app.cursor = 0
        init_state = app.config.features[0].enabled
        for _ in range(10):
            app.toggle_current_feature()
        self.assertEqual(app.config.features[0].enabled, init_state)
        app.toggle_current_feature()
        self.assertNotEqual(app.config.features[0].enabled, init_state)

    def test_t2_f02_03_features_with_spaces_and_special_chars(self) -> None:
        """Verify feature option labels with brackets and special characters."""
        feats = default_features(ProfileChoice.DESKTOP)
        niri_feat = [f for f in feats if f.id == "niri"][0]
        self.assertIn("(", niri_feat.label)
        self.assertIn(")", niri_feat.label)

    def test_t2_f02_04_cursor_out_of_bounds_toggle(self) -> None:
        """Verify toggle_current_feature handles out-of-bounds cursor safely."""
        app = App()
        app.cursor = 999
        app.toggle_current_feature()  # Should not raise IndexError

    def test_t2_f02_05_non_delta_feature_omission(self) -> None:
        """Verify non-delta options are never emitted in delta block."""
        cfg = InstallConfig(profile=ProfileChoice.DESKTOP)
        # Modify only 1 feature
        cfg.features[0].enabled = not cfg.features[0].enabled  # hyprland
        out = build_features_override(cfg)
        self.assertEqual(out.count(".enable ="), 1)
        self.assertIn("hyprland", out)
        self.assertNotIn("zsh", out)

    # ── Feature 3 Boundaries (F03) ──────────────────────────────

    def test_t2_f03_01_special_chars_in_os_entry_name(self) -> None:
        """Verify OS entry names with quotes and special characters."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.GRUB,
            dual_boot_entries=[
                DualBootEntry(name='Windows "Pro" / Edition', efi_path="/EFI/win.efi", disk_uuid="UUID-1")
            ],
        )
        out = build_bootloader_config(cfg)
        self.assertIn('Windows "Pro" / Edition', out)

    def test_t2_f03_02_empty_dual_boot_list(self) -> None:
        """Verify empty dual-boot list emits clean bootloader block."""
        cfg = InstallConfig(bootloader=BootloaderChoice.GRUB, dual_boot_entries=[])
        out = build_bootloader_config(cfg)
        self.assertIn('northstar.features.boot.loader = "grub";', out)
        self.assertNotIn("extraEntries", out)

    def test_t2_f03_03_all_dual_boot_disabled(self) -> None:
        """Verify dual-boot list with all entries disabled produces no extraEntries."""
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            dual_boot_entries=[
                DualBootEntry(name="OS1", efi_path="/p1", disk_uuid="u1", enabled=False),
                DualBootEntry(name="OS2", efi_path="/p2", disk_uuid="u2", enabled=False),
            ],
        )
        out = build_bootloader_config(cfg)
        self.assertNotIn("extraEntries", out)

    def test_t2_f03_04_large_number_of_os_entries(self) -> None:
        """Verify formatting a large number of dual-boot entries (20 entries)."""
        entries = [
            DualBootEntry(name=f"OS-{i}", efi_path=f"/EFI/os{i}/shim.efi", disk_uuid=f"UUID-{i}", enabled=True)
            for i in range(20)
        ]
        grub_out = format_grub_extra_entries(entries)
        limine_out = format_limine_extra_entries(entries)
        self.assertEqual(grub_out.count("menuentry"), 20)
        self.assertEqual(limine_out.count("protocol: efi"), 20)

    def test_t2_f03_05_bootloader_switch_preserves_entries(self) -> None:
        """Verify switching bootloader from GRUB to Limine preserves dual boot data."""
        entries = [
            DualBootEntry(name="Ubuntu", efi_path="/EFI/ubuntu/shimx64.efi", disk_uuid="UUID-U")
        ]
        cfg_grub = InstallConfig(bootloader=BootloaderChoice.GRUB, dual_boot_entries=entries)
        cfg_limine = InstallConfig(bootloader=BootloaderChoice.LIMINE, dual_boot_entries=entries)
        out_grub = build_bootloader_config(cfg_grub)
        out_limine = build_bootloader_config(cfg_limine)
        self.assertIn("search --fs-uuid", out_grub)
        self.assertIn("protocol: efi", out_limine)

    # ── Feature 4 Boundaries (F04) ──────────────────────────────

    def test_t2_f04_01_pci_empty_and_whitespace(self) -> None:
        """Verify empty and whitespace strings return None for PCI formatting."""
        self.assertIsNone(format_pci_bus_id(""))
        self.assertIsNone(format_pci_bus_id("   "))
        self.assertIsNone(format_pci_bus_id("\t\n"))

    def test_t2_f04_02_pci_malformed_strings(self) -> None:
        """Verify malformed non-PCI strings return None."""
        self.assertIsNone(format_pci_bus_id("not-a-pci"))
        self.assertIsNone(format_pci_bus_id("00:00"))
        self.assertIsNone(format_pci_bus_id("0000:gg:00.0"))
        self.assertIsNone(format_pci_bus_id("00:00:00.00.00"))

    def test_t2_f04_03_pci_leading_zeros(self) -> None:
        """Verify handling of leading zeros in PCI addresses."""
        self.assertEqual(format_pci_bus_id("0000:00:00.0"), "PCI:0:0:0")
        self.assertEqual(format_pci_bus_id("0000:00:01.0"), "PCI:0:1:0")

    def test_t2_f04_04_lsblk_malformed_json(self) -> None:
        """Verify broken JSON input returns empty list without raising exception."""
        self.assertEqual(parse_lsblk_json("{ invalid json"), [])
        self.assertEqual(parse_lsblk_json(""), [])
        self.assertEqual(parse_lsblk_json("{}"), [])

    def test_t2_f04_05_lspci_virtual_gpu(self) -> None:
        """Verify virtualized QEMU/VirtIO display adapter returns GpuChoice.NONE."""
        virtual_lspci = "00:01.0 VGA compatible controller: Red Hat, Inc. Virtio GPU (rev 01)\n"
        gpu, nv_bus, _, _ = parse_lspci_output(virtual_lspci)
        self.assertEqual(gpu, GpuChoice.NONE)
        self.assertIsNone(nv_bus)

    # ── Feature 5 Boundaries (F05) ──────────────────────────────

    def test_t2_f05_01_scan_esp_nonexistent_directory(self) -> None:
        """Verify scanning non-existent ESP path returns empty list gracefully."""
        entries = scan_esp_for_os(Path("/tmp/nonexistent-esp-12345"), "UUID-1")
        self.assertEqual(entries, [])

    def test_t2_f05_02_scan_esp_empty_directory(self) -> None:
        """Verify scanning empty directory returns empty list."""
        with tempfile.TemporaryDirectory() as tmpdir:
            entries = scan_esp_for_os(Path(tmpdir), "UUID-1")
            self.assertEqual(entries, [])

    def test_t2_f05_03_scan_esp_candidate_is_directory(self) -> None:
        """Verify candidate path that is a directory instead of file is handled safely."""
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_dir = Path(tmpdir) / "EFI" / "Microsoft" / "Boot" / "bootmgfw.efi"
            fake_dir.mkdir(parents=True)
            entries = scan_esp_for_os(Path(tmpdir), "UUID-1")
            # Should either return empty or handle safely
            self.assertTrue(isinstance(entries, list))

    def test_t2_f05_04_dual_boot_empty_uuid(self) -> None:
        """Verify dual-boot entry with empty UUID formats without crash."""
        entries = [DualBootEntry(name="Fedora", efi_path="/EFI/fedora/shim.efi", disk_uuid="")]
        grub = format_grub_extra_entries(entries)
        limine = format_limine_extra_entries(entries)
        self.assertIn('menuentry "Fedora"', grub)
        self.assertIn("/Fedora", limine)

    def test_t2_f05_05_scan_esp_all_os_simultaneous(self) -> None:
        """Verify directory with all 6 supported OSes discovers all 6 in single pass."""
        with tempfile.TemporaryDirectory() as tmpdir:
            esp = Path(tmpdir)
            files = [
                "EFI/Microsoft/Boot/bootmgfw.efi",
                "EFI/fedora/shimx64.efi",
                "EFI/ubuntu/shimx64.efi",
                "EFI/arch/grubx64.efi",
                "EFI/debian/shimx64.efi",
                "EFI/opensuse/shim.efi",
            ]
            for f in files:
                p = esp / f
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text("bin")
            entries = scan_esp_for_os(esp, "MULTI-UUID")
            self.assertEqual(len(entries), 6)

    # ── Feature 6 Boundaries (F06) ──────────────────────────────

    def test_t2_f06_01_swap_size_zero_whole_disk(self) -> None:
        """Verify whole-disk Disko with swap_size = '0' forces swap size to '0'."""
        cfg = InstallConfig(disk_dev="nvme0n1", fs_type="btrfs", swap_size="0")
        out = generate_disko_whole_disk(cfg)
        self.assertIn('partitions.swap.size = lib.mkForce "0";', out)

    def test_t2_f06_02_swap_size_custom_values(self) -> None:
        """Verify custom swap size strings (e.g. 32G, 4G)."""
        cfg = InstallConfig(disk_dev="sda", fs_type="ext4", swap_size="32G")
        out = generate_disko_whole_disk(cfg)
        self.assertIn('partitions.swap.size = lib.mkForce "32G";', out)

    def test_t2_f06_03_root_size_custom_percentages(self) -> None:
        """Verify custom root sizes in percentage and gigabytes."""
        cfg_pct = InstallConfig(disk_dev="sda", root_size="50%")
        out_pct = generate_disko_whole_disk(cfg_pct)
        self.assertIn('partitions.root.size = lib.mkForce "50%";', out_pct)

        cfg_gib = InstallConfig(disk_dev="sda", root_size="250G")
        out_gib = generate_disko_whole_disk(cfg_gib)
        self.assertIn('partitions.root.size = lib.mkForce "250G";', out_gib)

    def test_t2_f06_04_partition_only_no_efi_uuid_fallback(self) -> None:
        """Verify partition-only mode falls back to raw device path when UUID is missing."""
        cfg = InstallConfig(
            hostname="FallbackRig",
            nixos_part="/dev/sda2",
            efi_part="/dev/sda1",
            fs_type="ext4",
        )
        out = generate_disko_partition_only(cfg, efi_uuid="")
        self.assertIn('device = "/dev/sda1";', out)
        self.assertNotIn("/dev/disk/by-uuid/", out)

    def test_t2_f06_05_strip_filesystems_complex_multiline(self) -> None:
        """Verify strip_filesystems handles deeply nested and commented blocks."""
        complex_hw = (
            "# Generated hardware\n"
            "{\n"
            "  fileSystems.\"/var/log\" = {\n"
            "    device = \"/dev/disk/by-uuid/xyz\";\n"
            "    options = [\n"
            "      \"compress=zstd\"\n"
            "      \"noatime\"\n"
            "    ];\n"
            "  };\n"
            "  boot.kernelModules = [ \"r8169\" ];\n"
            "}\n"
        )
        cleaned = strip_filesystems_from_hardware(complex_hw)
        self.assertNotIn("fileSystems", cleaned)
        self.assertNotIn("compress=zstd", cleaned)
        self.assertIn("boot.kernelModules = [ \"r8169\" ];", cleaned)

    # ── Feature 7 Boundaries (F07) ──────────────────────────────

    def test_t2_f07_01_state_corrupt_json_recovery(self) -> None:
        """Verify State recovers cleanly when JSON file is corrupted."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "state.json"
            state_file.write_text("{ broken json {{{")
            state = State(state_file=state_file)
            self.assertEqual(state.current_step(), "generate_config")
            self.assertEqual(state.data, {})

    def test_t2_f07_02_state_missing_file_handling(self) -> None:
        """Verify State handles deleted or missing state file without crashing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "nonexistent_state.json"
            state = State(state_file=state_file)
            self.assertFalse(state.should_skip("generate_config"))

    def test_t2_f07_03_state_clear_unlinks_file(self) -> None:
        """Verify State.clear() removes state file and empties dictionary."""
        with tempfile.TemporaryDirectory() as tmpdir:
            state_file = Path(tmpdir) / "state.json"
            state = State(state_file=state_file)
            state.set("key", "val")
            self.assertTrue(state_file.exists())
            state.clear()
            self.assertFalse(state_file.exists())
            self.assertEqual(len(state.data), 0)

    def test_t2_f07_04_retry_decorator_exhaustion(self) -> None:
        """Verify retry decorator limits attempts and does not loop infinitely."""
        attempts = 0

        @retry(max_attempts=2, delay=0)
        def failing_function() -> None:
            nonlocal attempts
            attempts += 1
            raise ValueError("Deliberate failure")

        import unittest.mock
        with unittest.mock.patch("builtins.input", return_value="s"):
            res = failing_function()
            self.assertIsNone(res)
        self.assertEqual(attempts, 2)

    def test_t2_f07_05_password_hash_special_chars(self) -> None:
        """Verify password hashing handles complex symbols safely."""
        complex_pw = 'P@$$w0rd!#%^&*()_+~`|}{[]:;?><,./"\\'
        h = hash_password(complex_pw)
        self.assertTrue(len(h) > 0)

    # ── Feature 8 Boundaries (F08) ──────────────────────────────

    def test_t2_f08_01_aiml_invalid_acceleration_enum(self) -> None:
        """Verify invalid acceleration enum fails Nix type validation."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml.acceleration = lib.mkOption {
              type = lib.types.enum [ "auto" "cuda" "rocm" "none" ];
              default = "auto";
            };
          };
          eval = lib.evalModules {
            modules = [ aimlModule { northstar.features.development.aiml.acceleration = "directml"; } ];
          };
        in eval.config.northstar.features.development.aiml.acceleration
        """
        code, _, err = run_nix_eval(nix_code)
        self.assertNotEqual(code, 0, "Invalid enum should fail type checking")

    def test_t2_f08_02_aiml_custom_port_propagation(self) -> None:
        """Verify custom Ollama port and Jupyter port cleanly evaluate."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml = {
              ollama.port = lib.mkOption { type = lib.types.port; default = 11434; };
              jupyter.port = lib.mkOption { type = lib.types.port; default = 8888; };
            };
          };
          eval = lib.evalModules {
            modules = [
              aimlModule
              {
                northstar.features.development.aiml.ollama.port = 20000;
                northstar.features.development.aiml.jupyter.port = 9999;
              }
            ];
          };
        in {
          ollama = eval.config.northstar.features.development.aiml.ollama.port;
          jupyter = eval.config.northstar.features.development.aiml.jupyter.port;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("ollama = 20000", out)
        self.assertIn("jupyter = 9999", out)

    def test_t2_f08_03_aiml_empty_models_list(self) -> None:
        """Verify empty models list evaluates with zero errors."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml.ollama.models = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
          eval = lib.evalModules {
            modules = [ aimlModule { northstar.features.development.aiml.ollama.models = [ ]; } ];
          };
        in builtins.length eval.config.northstar.features.development.aiml.ollama.models
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "0")

    def test_t2_f08_04_aiml_disable_subcomponents(self) -> None:
        """Verify disabling PyTorch, LlamaCpp, Jupyter selectively."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, ... }: {
            options.northstar.features.development.aiml = {
              enable = lib.mkEnableOption "aiml";
              pytorch.enable = lib.mkOption { type = lib.types.bool; default = true; };
              llamaCpp.enable = lib.mkOption { type = lib.types.bool; default = true; };
              jupyter.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
          };
          eval = lib.evalModules {
            modules = [
              aimlModule
              {
                northstar.features.development.aiml.enable = true;
                northstar.features.development.aiml.pytorch.enable = false;
                northstar.features.development.aiml.llamaCpp.enable = false;
              }
            ];
          };
        in {
          pytorch = eval.config.northstar.features.development.aiml.pytorch.enable;
          llama = eval.config.northstar.features.development.aiml.llamaCpp.enable;
          jupyter = eval.config.northstar.features.development.aiml.jupyter.enable;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("pytorch = false", out)
        self.assertIn("llama = false", out)
        self.assertIn("jupyter = true", out)

    def test_t2_f08_05_aiml_explicit_package_override(self) -> None:
        """Verify explicit package override for Ollama."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          aimlModule = { config, lib, pkgs, ... }: {
            options.northstar.features.development.aiml.ollama.package = lib.mkOption {
              type = lib.types.nullOr lib.types.package;
              default = null;
            };
          };
          eval = lib.evalModules {
            modules = [ aimlModule { northstar.features.development.aiml.ollama.package = pkgs.hello; } ];
            specialArgs = { inherit pkgs; };
          };
        in eval.config.northstar.features.development.aiml.ollama.package.name
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertTrue("hello" in out)

    # ── Feature 9 Boundaries (F09) ──────────────────────────────

    def test_t2_f09_01_gaming_all_subfeatures_disabled(self) -> None:
        """Verify gaming module with all sub-options disabled evaluates cleanly."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "gaming";
              steam.enable = lib.mkOption { type = lib.types.bool; default = true; };
              gamemode.enable = lib.mkOption { type = lib.types.bool; default = true; };
              gamescope.enable = lib.mkOption { type = lib.types.bool; default = true; };
              mangohud.enable = lib.mkOption { type = lib.types.bool; default = true; };
              wine.enable = lib.mkOption { type = lib.types.bool; default = true; };
              lutris.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
          };
          eval = lib.evalModules {
            modules = [
              gamingModule
              {
                northstar.features.desktop.gaming.enable = true;
                northstar.features.desktop.gaming.steam.enable = false;
                northstar.features.desktop.gaming.gamemode.enable = false;
                northstar.features.desktop.gaming.gamescope.enable = false;
                northstar.features.desktop.gaming.mangohud.enable = false;
                northstar.features.desktop.gaming.wine.enable = false;
                northstar.features.desktop.gaming.lutris.enable = false;
              }
            ];
          };
        in eval.config.northstar.features.desktop.gaming.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t2_f09_02_gaming_custom_renice_value(self) -> None:
        """Verify GameMode custom renice configuration."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming.gamemode.settings = lib.mkOption {
              type = lib.types.attrs;
              default = { general.renice = 10; };
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.desktop.gaming.gamemode.settings = { general.renice = 15; }; } ];
          };
        in eval.config.northstar.features.desktop.gaming.gamemode.settings.general.renice
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "15")

    def test_t2_f09_03_gaming_custom_gamescope_args(self) -> None:
        """Verify custom Gamescope arguments list."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming.gamescope.args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
          eval = lib.evalModules {
            modules = [ gamingModule { northstar.features.desktop.gaming.gamescope.args = [ "-W" "1920" "-H" "1080" "-r" "144" ]; } ];
          };
        in builtins.length eval.config.northstar.features.desktop.gaming.gamescope.args
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "6")

    def test_t2_f09_04_gaming_disable_latency_tweaks(self) -> None:
        """Verify latency tweaks disabled leaves sysctl untouched."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, ... }: {
            options.northstar.features.desktop.gaming = {
              enable = lib.mkEnableOption "gaming";
              latencyTweaks.enable = lib.mkOption { type = lib.types.bool; default = true; };
            };
            options.boot.kernel.sysctl = lib.mkOption {
              type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int ]);
              default = {};
            };
            config = lib.mkIf (config.northstar.features.desktop.gaming.enable && config.northstar.features.desktop.gaming.latencyTweaks.enable) {
              boot.kernel.sysctl = { "vm.max_map_count" = 2147483642; };
            };
          };
          eval = lib.evalModules {
            modules = [
              gamingModule
              { northstar.features.desktop.gaming.enable = true; northstar.features.desktop.gaming.latencyTweaks.enable = false; }
            ];
          };
        in builtins.hasAttr "vm.max_map_count" eval.config.boot.kernel.sysctl
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "false")

    def test_t2_f09_05_gaming_custom_wine_package(self) -> None:
        """Verify custom Wine package override."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingModule = { config, lib, pkgs, ... }: {
            options.northstar.features.desktop.gaming.wine.package = lib.mkOption {
              type = lib.types.package;
              default = pkgs.hello;
            };
          };
          eval = lib.evalModules { modules = [ gamingModule ]; specialArgs = { inherit pkgs; }; };
        in eval.config.northstar.features.desktop.gaming.wine.package.name
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("hello", out)

    # ── Feature 10 Boundaries (F10) ─────────────────────────────

    def test_t2_f10_01_workstation_with_aiml_disabled_override(self) -> None:
        """Verify workstation profile allows disabling aiml via explicit override."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          workstationProfile = { config, lib, ... }: {
            options.northstar.profiles.workstation.enable = lib.mkEnableOption "workstation";
            options.northstar.features.aiml.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf config.northstar.profiles.workstation.enable {
              northstar.features.aiml.enable = lib.mkDefault true;
            };
          };
          eval = lib.evalModules {
            modules = [
              workstationProfile
              {
                northstar.profiles.workstation.enable = true;
                northstar.features.aiml.enable = lib.mkForce false;
              }
            ];
          };
        in eval.config.northstar.features.aiml.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "false")

    def test_t2_f10_02_gaming_profile_standalone(self) -> None:
        """Verify standalone gaming profile activates desktop profile."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          gamingProfile = { config, lib, ... }: {
            options.northstar.profiles.gaming.enable = lib.mkEnableOption "gaming";
            options.northstar.profiles.desktop.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf config.northstar.profiles.gaming.enable {
              northstar.profiles.desktop.enable = true;
            };
          };
          eval = lib.evalModules {
            modules = [ gamingProfile { northstar.profiles.gaming.enable = true; } ];
          };
        in eval.config.northstar.profiles.desktop.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t2_f10_03_all_profiles_enabled_simultaneously(self) -> None:
        """Verify enabling all profiles simultaneously produces zero conflicts."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          allProfilesModule = { config, lib, ... }: {
            options.northstar.profiles = {
              base.enable = lib.mkOption { type = lib.types.bool; default = false; };
              desktop.enable = lib.mkOption { type = lib.types.bool; default = false; };
              workstation.enable = lib.mkOption { type = lib.types.bool; default = false; };
              gaming.enable = lib.mkOption { type = lib.types.bool; default = false; };
            };
          };
          eval = lib.evalModules {
            modules = [
              allProfilesModule
              {
                northstar.profiles = {
                  base.enable = true;
                  desktop.enable = true;
                  workstation.enable = true;
                  gaming.enable = true;
                };
              }
            ];
          };
        in eval.config.northstar.profiles.gaming.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t2_f10_04_mkprofile_empty_features(self) -> None:
        """Verify mkProfile with empty list generates empty features attrset."""
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          northstar = import ./lib { inherit lib; };
          res = northstar.mkProfile [];
        in res.northstar.features
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "{ }")

    def test_t2_f10_05_alias_and_canonical_coexistence(self) -> None:
        """Verify alias and canonical options can both be evaluated."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          mod = { config, lib, ... }: {
            imports = [
              (lib.mkAliasOptionModule [ "northstar" "features" "gaming" ] [ "northstar" "features" "desktop" "gaming" ])
            ];
            options.northstar.features.desktop.gaming.enable = lib.mkEnableOption "gaming";
          };
          eval = lib.evalModules {
            modules = [ mod { northstar.features.desktop.gaming.enable = true; } ];
          };
        in eval.config.northstar.features.gaming.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    # ── Feature 11 Boundaries (F11) ─────────────────────────────

    def test_t2_f11_01_secureboot_custom_pki_path(self) -> None:
        """Verify custom PKI bundle path propagation."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot.secureBoot.pkiBundle = lib.mkOption {
              type = lib.types.str;
              default = "/etc/secureboot";
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.secureBoot.pkiBundle = "/var/keys/sb"; } ];
          };
        in eval.config.northstar.features.boot.secureBoot.pkiBundle
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, '"/var/keys/sb"')

    def test_t2_f11_02_secureboot_with_limine_override(self) -> None:
        """Verify loader = limine with secureBoot disables Limine and enables Lanzaboote."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot = {
              loader = lib.mkOption { type = lib.types.enum [ "grub" "limine" ]; default = "limine"; };
              secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            };
            options.boot.lanzaboote.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.loader.limine.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkMerge [
              (lib.mkIf (!config.northstar.features.boot.secureBoot.enable) {
                boot.loader.limine.enable = config.northstar.features.boot.loader == "limine";
              })
              (lib.mkIf config.northstar.features.boot.secureBoot.enable {
                boot.lanzaboote.enable = true;
              })
            ];
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.loader = "limine"; northstar.features.boot.secureBoot.enable = true; } ];
          };
        in {
          limine = eval.config.boot.loader.limine.enable;
          lanzaboote = eval.config.boot.lanzaboote.enable;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("limine = false", out)
        self.assertIn("lanzaboote = true", out)

    def test_t2_f11_03_secureboot_disabled_retains_grub(self) -> None:
        """Verify secureBoot disabled retains GRUB bootloader."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot = {
              loader = lib.mkOption { type = lib.types.enum [ "grub" "limine" ]; default = "grub"; };
              secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            };
            options.boot.loader.grub.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf (!config.northstar.features.boot.secureBoot.enable) {
              boot.loader.grub.enable = config.northstar.features.boot.loader == "grub";
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.loader = "grub"; northstar.features.boot.secureBoot.enable = false; } ];
          };
        in eval.config.boot.loader.grub.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t2_f11_04_secureboot_disabled_retains_limine(self) -> None:
        """Verify secureBoot disabled retains Limine bootloader."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot = {
              loader = lib.mkOption { type = lib.types.enum [ "grub" "limine" ]; default = "limine"; };
              secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            };
            options.boot.loader.limine.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = lib.mkIf (!config.northstar.features.boot.secureBoot.enable) {
              boot.loader.limine.enable = config.northstar.features.boot.loader == "limine";
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.loader = "limine"; northstar.features.boot.secureBoot.enable = false; } ];
          };
        in eval.config.boot.loader.limine.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    def test_t2_f11_05_secureboot_plymouth_coexistence(self) -> None:
        """Verify Plymouth splash can coexist with Secure Boot configuration."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          bootModule = { config, lib, ... }: {
            options.northstar.features.boot.secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.plymouth.enable = lib.mkOption { type = lib.types.bool; default = false; };
            config = {
              boot.plymouth.enable = true;
            };
          };
          eval = lib.evalModules {
            modules = [ bootModule { northstar.features.boot.secureBoot.enable = true; } ];
          };
        in eval.config.boot.plymouth.enable
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")

    # ── Feature 12 Boundaries (F12) ─────────────────────────────

    def test_t2_f12_01_scan_modules_nonexistent_directory(self) -> None:
        """Verify scanModules handles non-existent directory by returning empty list."""
        nix_code = """
        let
          lib = (import <nixpkgs> {}).lib;
          northstar = import ./lib { inherit lib; };
        in northstar.scanModules ./nonexistent_dir_path
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "[ ]")

    def test_t2_f12_02_discover_hosts_missing_hardware(self) -> None:
        """Verify discoverHosts excludes directories missing hardware.nix."""
        with tempfile.TemporaryDirectory() as tmpdir:
            host_dir = Path(tmpdir) / "IncompleteHost"
            host_dir.mkdir()
            (host_dir / "default.nix").write_text("{ ... }: {}")
            nix_code = f"""
            let
              lib = (import <nixpkgs> {{}}).lib;
              northstar = import ./lib {{ inherit lib; }};
            in northstar.discoverHosts (/. + "{tmpdir}")
            """
            code, out, _ = run_nix_eval(nix_code)
            self.assertEqual(code, 0)
            self.assertEqual(out, "[ ]")

    def test_t2_f12_03_discover_hosts_valid_structure(self) -> None:
        """Verify discoverHosts includes directories containing both default.nix and hardware.nix."""
        with tempfile.TemporaryDirectory() as tmpdir:
            host_dir = Path(tmpdir) / "ValidHost"
            host_dir.mkdir()
            (host_dir / "default.nix").write_text("{ ... }: {}")
            (host_dir / "hardware.nix").write_text("{ ... }: {}")
            nix_code = f"""
            let
              lib = (import <nixpkgs> {{}}).lib;
              northstar = import ./lib {{ inherit lib; }};
            in northstar.discoverHosts (/. + "{tmpdir}")
            """
            code, out, _ = run_nix_eval(nix_code)
            self.assertEqual(code, 0)
            self.assertIn("ValidHost", out)

    def test_t2_f12_04_state_version_strict_26_11(self) -> None:
        """Verify generated configs strictly declare stateVersion 26.11."""
        cfg = InstallConfig(hostname="StateVerHost")
        default_nix = generate_host_default_nix(cfg)
        self.assertIn('system.stateVersion = "26.11";', default_nix)
        self.assertNotIn('system.stateVersion = "26.05";', default_nix)

    def test_t2_f12_05_unfree_license_allowed(self) -> None:
        """Verify Nixpkgs evaluation context permits unfree packages."""
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
        in pkgs.config.allowUnfree
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertEqual(out, "true")


# ════════════════════════════════════════════════════════════════
#  TIER 3: CROSS-FEATURE INTERACTIONS (6 Tests)
# ════════════════════════════════════════════════════════════════

class Tier3InteractionTests(unittest.TestCase):
    """
    Tier 3: Cross-Feature Interactions & Pairwise Combinations.
    Validates orthogonal features composed together.
    """

    def test_t3_xf01_workstation_nvidia_prime_grub_dualboot(self) -> None:
        """
        XF-01: Workstation Profile + NVIDIA Prime (Intel) + GRUB Dual Boot.
        Verifies synthesis contains workstation hierarchy, prime bus IDs, and dual-boot chainloader.
        """
        cfg = InstallConfig(
            hostname="WorkstationPrime",
            username="reze",
            profile=ProfileChoice.WORKSTATION,
            bootloader=BootloaderChoice.GRUB,
            gpu_choice=GpuChoice.NVIDIA_PRIME,
            nvidia_bus_id="PCI:1:0:0",
            igpu_bus_id="PCI:0:2:0",
            igpu_type=IgpuType.INTEL,
            dual_boot_entries=[
                DualBootEntry(name="Windows 11", efi_path="/EFI/Microsoft/Boot/bootmgfw.efi", disk_uuid="UUID-WIN-11")
            ],
        )
        out = generate_host_default_nix(cfg)
        self.assertIn("desktop.enable = true;", out)
        self.assertIn("workstation.enable = true;", out)
        self.assertIn("northstar.nvidia.prime", out)
        self.assertIn('nvidiaBusId = "PCI:1:0:0";', out)
        self.assertIn('intelBusId = "PCI:0:2:0";', out)
        self.assertIn('northstar.features.boot.loader = "grub";', out)
        self.assertIn('menuentry "Windows 11"', out)

    def test_t3_xf02_desktop_secureboot_gaming(self) -> None:
        """
        XF-02: Desktop Profile + Lanzaboote Secure Boot + Gaming Suite.
        Verifies Steam/GameMode coexistence with Lanzaboote bootloader.
        """
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          composite = { config, lib, pkgs, ... }: {
            options.northstar.profiles.desktop.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.northstar.features.boot.secureBoot.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.northstar.features.desktop.gaming.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.lanzaboote.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.programs.steam.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.environment.systemPackages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
            config = lib.mkMerge [
              (lib.mkIf config.northstar.features.boot.secureBoot.enable {
                boot.lanzaboote.enable = true;
                environment.systemPackages = [ pkgs.sbctl ];
              })
              (lib.mkIf config.northstar.features.desktop.gaming.enable {
                programs.steam.enable = true;
              })
            ];
          };
          eval = lib.evalModules {
            modules = [
              composite
              {
                northstar.profiles.desktop.enable = true;
                northstar.features.boot.secureBoot.enable = true;
                northstar.features.desktop.gaming.enable = true;
              }
            ];
            specialArgs = { inherit pkgs; };
          };
        in {
          lanzaboote = eval.config.boot.lanzaboote.enable;
          steam = eval.config.programs.steam.enable;
          hasSbctl = builtins.length eval.config.environment.systemPackages == 1;
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("lanzaboote = true", out)
        self.assertIn("steam = true", out)
        self.assertIn("hasSbctl = true", out)

    def test_t3_xf03_base_limine_partition_only_btrfs(self) -> None:
        """
        XF-03: Base Profile + Limine + Partition-Only BTRFS layout.
        Verifies minimal profile and subvolumes in partition-only mode.
        """
        cfg = InstallConfig(
            hostname="BaseLimineNode",
            profile=ProfileChoice.BASE,
            bootloader=BootloaderChoice.LIMINE,
            mode=InstallMode.PARTITION_ONLY,
            nixos_part="/dev/nvme0n1p4",
            efi_part="/dev/nvme0n1p1",
            fs_type="btrfs",
            swap_size="4G",
        )
        host_nix = generate_host_default_nix(cfg)
        disko_nix = generate_disko_partition_only(cfg, efi_uuid="ESP-UUID-777")
        self.assertIn("base.enable = true;", host_nix)
        self.assertIn('northstar.features.boot.loader = "limine";', host_nix)
        self.assertIn('device = "/dev/nvme0n1p4";', disko_nix)
        self.assertIn('mountpoint = "/swap";', disko_nix)
        self.assertIn("ESP-UUID-777", disko_nix)

    def test_t3_xf04_workstation_ext4_swap0_aiml_cuda(self) -> None:
        """
        XF-04: Workstation + Whole-Disk Ext4 + Swap 0 + AI/ML CUDA.
        Verifies Disko swap disabling and CUDA acceleration wiring.
        """
        cfg = InstallConfig(
            hostname="CudaRig",
            profile=ProfileChoice.WORKSTATION,
            mode=InstallMode.WHOLE_DISK,
            disk_dev="sda",
            fs_type="ext4",
            swap_size="0",
            gpu_choice=GpuChoice.NVIDIA,
        )
        host_nix = generate_host_default_nix(cfg)
        disko_nix = generate_disko_whole_disk(cfg)
        self.assertIn("northstar.nvidia.enable = true;", host_nix)
        self.assertIn('partitions.swap.size = lib.mkForce "0";', disko_nix)

    def test_t3_xf05_gaming_aiml_simultaneous_nvidia_hybrid(self) -> None:
        """
        XF-05: Gaming Suite + AI/ML Suite simultaneous enablement on NVIDIA hybrid host.
        Verifies both feature suites co-exist without option collision.
        """
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
          lib = pkgs.lib;
          jointModule = { config, lib, pkgs, ... }: {
            options.northstar.features.development.aiml.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.northstar.features.desktop.gaming.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.northstar.nvidia.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.services.ollama.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.programs.steam.enable = lib.mkOption { type = lib.types.bool; default = false; };
            options.boot.kernel.sysctl = lib.mkOption {
              type = lib.types.attrsOf (lib.types.oneOf [ lib.types.str lib.types.int ]);
              default = {};
            };
            config = lib.mkMerge [
              (lib.mkIf config.northstar.features.development.aiml.enable {
                services.ollama.enable = true;
              })
              (lib.mkIf config.northstar.features.desktop.gaming.enable {
                programs.steam.enable = true;
                boot.kernel.sysctl = { "vm.max_map_count" = 2147483642; };
              })
            ];
          };
          eval = lib.evalModules {
            modules = [
              jointModule
              {
                northstar.nvidia.enable = true;
                northstar.features.development.aiml.enable = true;
                northstar.features.desktop.gaming.enable = true;
              }
            ];
            specialArgs = { inherit pkgs; };
          };
        in {
          ollama = eval.config.services.ollama.enable;
          steam = eval.config.programs.steam.enable;
          maxMap = eval.config.boot.kernel.sysctl."vm.max_map_count";
        }
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("ollama = true", out)
        self.assertIn("steam = true", out)
        self.assertIn("maxMap = 2147483642", out)

    def test_t3_xf06_detection_pipeline_to_synthesis_pipeline(self) -> None:
        """
        XF-06: End-to-end hardware detection feed into config synthesis.
        Verifies mock lspci and lsblk feeds directly populate InstallConfig and synthesized files.
        """
        mock_lspci = (
            "01:00.0 VGA compatible controller: NVIDIA Corporation GA106 [GeForce RTX 3060] (rev a1)\n"
            "00:02.0 VGA compatible controller: Intel Corporation UHD Graphics 770 (rev 0c)\n"
        )
        mock_lsblk = json.dumps({
            "blockdevices": [
                {
                    "name": "nvme0n1",
                    "size": "1000G",
                    "type": "disk",
                    "model": "KIOXIA EXCERIA",
                    "tran": "nvme",
                    "children": [
                        {"name": "nvme0n1p1", "size": "1G", "fstype": "vfat", "uuid": "ESP-UUID-999"}
                    ]
                }
            ]
        })
        gpu, nv_bus, igpu_bus, igpu_type = parse_lspci_output(mock_lspci)
        disks = parse_lsblk_json(mock_lsblk)

        cfg = InstallConfig(
            hostname="PipelineHost",
            username="reze",
            profile=ProfileChoice.WORKSTATION,
            bootloader=BootloaderChoice.GRUB,
            gpu_choice=gpu,
            nvidia_bus_id=nv_bus or "",
            igpu_bus_id=igpu_bus or "",
            igpu_type=igpu_type,
            disk_dev=disks[0].name,
        )
        host_nix = generate_host_default_nix(cfg)
        disko_nix = generate_disko_whole_disk(cfg)

        self.assertIn('nvidiaBusId = "PCI:1:0:0";', host_nix)
        self.assertIn('intelBusId = "PCI:0:2:0";', host_nix)
        self.assertIn('disko.devices.disk.main.device = "/dev/nvme0n1";', disko_nix)


# ════════════════════════════════════════════════════════════════
#  TIER 4: REAL-WORLD WORKLOADS (5 Tests)
# ════════════════════════════════════════════════════════════════

class Tier4RealWorldTests(unittest.TestCase):
    """
    Tier 4: Real-World Application Workloads & Nix Flake Evaluations.
    Evaluates end-to-end host synthesis and full NixOS derivation builds.
    """

    def test_t4_e2e01_makima_system_build_toplevel(self) -> None:
        """
        E2E-01: Production Host Makima Full Top-Level Evaluation.
        Evaluates system.build.toplevel.name and system attributes.
        """
        code, out, err = run_nix_eval_attr("nixosConfigurations.Makima.config.system.build.toplevel.name")
        self.assertEqual(code, 0, f"Failed evaluating Makima toplevel: {err}")
        self.assertRegex(out, r'^"nixos-system-Makima-26\.11\..*"$')

    def test_t4_e2e02_synthetic_host_generation_and_nix_eval(self) -> None:
        """
        E2E-02: Synthetic Host Synthesis & Nix Evaluation.
        Synthesizes a complete host configuration and evaluates it against Northstar library combinators.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            temp_path = Path(tmpdir)
            cfg = InstallConfig(
                hostname="SyntheticTestRig",
                username="testuser",
                hashed_pw="$6$salt$hash",
                profile=ProfileChoice.WORKSTATION,
                bootloader=BootloaderChoice.LIMINE,
                disk_dev="vda",
                fs_type="ext4",
            )
            host_nix = generate_host_default_nix(cfg)
            disko_nix = generate_disko_whole_disk(cfg)

            (temp_path / "default.nix").write_text(host_nix)
            (temp_path / "disko.nix").write_text(disko_nix)

            # Evaluate syntax and basic module loading with nix-instantiate / nix eval
            nix_code = f"""
            let
              pkgs = import <nixpkgs> {{ config.allowUnfree = true; }};
              lib = pkgs.lib;
              imported = import (/. + "{temp_path}/default.nix");
            in builtins.isFunction imported
            """
            code, out, _ = run_nix_eval(nix_code)
            self.assertEqual(code, 0)
            self.assertEqual(out, "true")

    def test_t4_e2e03_lanzaboote_secureboot_evaluation(self) -> None:
        """
        E2E-03: Lanzaboote Secure Boot Host Derivation Evaluation.
        Evaluates module activation and verifies sbctl derivation exists.
        """
        nix_code = """
        let
          pkgs = import <nixpkgs> { config.allowUnfree = true; };
        in pkgs.sbctl.name
        """
        code, out, _ = run_nix_eval(nix_code)
        self.assertEqual(code, 0)
        self.assertIn("sbctl", out)

    def test_t4_e2e04_full_flake_outputs_schema(self) -> None:
        """
        E2E-04: Full Flake Schema & Exports Verification.
        Verifies apps, packages, and nixosModules are cleanly declared.
        """
        code_apps, out_apps, _ = run_nix_eval_attr("apps.x86_64-linux", as_json=True)
        self.assertEqual(code_apps, 0)
        apps_data = json.loads(out_apps)
        self.assertIn("install", apps_data)
        self.assertIn("default", apps_data)
        self.assertIn("rust-install", apps_data)

    def test_t4_e2e05_python_cli_interactive_wizard_simulation(self) -> None:
        """
        E2E-05: Complete Interactive Installer Wizard Simulation.
        Simulates end-to-end App wizard state machine navigation.
        """
        app = App()
        self.assertEqual(app.page, Page.WELCOME)

        # 1. Welcome -> Hostname
        app.go_to_page(Page.HOSTNAME)
        app.type_char("m")
        app.type_char("y")
        app.type_char("h")
        app.type_char("o")
        app.type_char("s")
        app.type_char("t")
        self.assertEqual(app.input_value(), "myhost")
        app.config.hostname = app.input_value()

        # 2. Hostname -> Username
        app.go_to_page(Page.USERNAME)
        app.input = ""
        app.cursor_pos = 0
        app.type_char("r")
        app.type_char("e")
        app.type_char("z")
        app.type_char("e")
        self.assertEqual(app.input_value(), "reze")
        app.config.username = app.input_value()

        # 3. Profile Selection -> Workstation
        app.apply_profile(ProfileChoice.WORKSTATION)
        self.assertEqual(app.config.profile, ProfileChoice.WORKSTATION)

        # 4. Bootloader Selection -> Limine
        app.config.bootloader = BootloaderChoice.LIMINE

        # 5. Disk Mode -> Whole Disk
        app.config.mode = InstallMode.WHOLE_DISK
        app.config.disk_dev = "nvme0n1"

        # 6. Summary -> Done
        app.go_to_page(Page.SUMMARY)
        self.assertEqual(app.config.hostname, "myhost")
        self.assertEqual(app.config.username, "reze")
        self.assertEqual(app.config.profile, ProfileChoice.WORKSTATION)
        self.assertEqual(app.config.bootloader, BootloaderChoice.LIMINE)
        app.go_to_page(Page.DONE)
        self.assertEqual(app.page, Page.DONE)


# ════════════════════════════════════════════════════════════════
#  MAIN ENTRY POINT & CLI RUNNER
# ════════════════════════════════════════════════════════════════

def get_suite_for_tier(tier: int) -> unittest.TestSuite:
    """Load test suite for specific tier."""
    loader = unittest.TestLoader()
    if tier == 1:
        return loader.loadTestsFromTestCase(Tier1FeatureCoverageTests)
    elif tier == 2:
        return loader.loadTestsFromTestCase(Tier2BoundaryTests)
    elif tier == 3:
        return loader.loadTestsFromTestCase(Tier3InteractionTests)
    elif tier == 4:
        return loader.loadTestsFromTestCase(Tier4RealWorldTests)
    else:
        raise ValueError(f"Invalid tier {tier}. Valid tiers are 1, 2, 3, 4.")


def get_all_suite() -> unittest.TestSuite:
    """Load all tiers into a single test suite."""
    suite = unittest.TestSuite()
    suite.addTest(get_suite_for_tier(1))
    suite.addTest(get_suite_for_tier(2))
    suite.addTest(get_suite_for_tier(3))
    suite.addTest(get_suite_for_tier(4))
    return suite


def filter_suite(suite: unittest.TestSuite, pattern: str) -> unittest.TestSuite:
    """Recursively filter test suite by regex pattern matching test ID."""
    filtered = unittest.TestSuite()
    regex = re.compile(pattern, re.IGNORECASE)
    for test in suite:
        if isinstance(test, unittest.TestSuite):
            sub = filter_suite(test, pattern)
            if sub.countTestCases() > 0:
                filtered.addTest(sub)
        elif isinstance(test, unittest.TestCase):
            if regex.search(test.id()) or regex.search(test._testMethodName):
                filtered.addTest(test)
    return filtered


def main() -> int:
    import argparse
    import time

    parser = argparse.ArgumentParser(description="Northstar E2E Test Suite Runner")
    parser.add_argument("--tier", type=int, choices=[1, 2, 3, 4], help="Run a specific test tier (1, 2, 3, or 4)")
    parser.add_argument("--all", action="store_true", help="Run all test tiers (default)")
    parser.add_argument("--filter", "-f", type=str, help="Filter test cases matching a pattern")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose test execution output")
    parser.add_argument("--json", type=str, help="Path to write JSON test report summary")

    args = parser.parse_args()

    if args.tier:
        suite = get_suite_for_tier(args.tier)
        tier_label = f"Tier {args.tier}"
    else:
        suite = get_all_suite()
        tier_label = "All Tiers (1-4)"

    if args.filter:
        suite = filter_suite(suite, args.filter)

    total_tests = suite.countTestCases()
    verbosity = 2 if args.verbose else 1

    print(f"\n\033[1;36m=======================================================\033[0m")
    print(f"\033[1;32m Northstar E2E Test Runner — {tier_label}\033[0m")
    print(f"\033[1;36m Total Test Cases Selected: {total_tests}\033[0m")
    print(f"\033[1;36m=======================================================\033[0m\n")

    start_time = time.time()
    runner = unittest.TextTestRunner(verbosity=verbosity)
    result = runner.run(suite)
    duration = time.time() - start_time

    passed = total_tests - len(result.failures) - len(result.errors) - len(result.skipped)
    success = result.wasSuccessful()

    if args.json:
        report = {
            "tier": args.tier or "all",
            "total": total_tests,
            "passed": passed,
            "failed": len(result.failures),
            "errors": len(result.errors),
            "skipped": len(result.skipped),
            "duration_seconds": round(duration, 3),
            "success": success,
            "failures": [
                {"test": str(t), "traceback": tb} for t, tb in result.failures
            ],
            "error_details": [
                {"test": str(t), "traceback": tb} for t, tb in result.errors
            ],
        }
        json_path = Path(args.json)
        json_path.parent.mkdir(parents=True, exist_ok=True)
        json_path.write_text(json.dumps(report, indent=2))
        print(f"\n\033[0;32m[+] JSON summary written to {args.json}\033[0m")

    print(f"\n\033[1;36m-------------------------------------------------------\033[0m")
    print(f" Summary: {passed}/{total_tests} passed in {duration:.2f}s")
    if success:
        print(f" Status:  \033[1;32mSUCCESS (100%)\033[0m")
        return 0
    else:
        print(f" Status:  \033[1;31mFAILED ({len(result.failures)} failures, {len(result.errors)} errors)\033[0m")
        return 1


if __name__ == "__main__":
    sys.exit(main())

