"""
Unit tests for hardware detection, DRM /sys/class/drm/*/modes resolution parsing,
EDID binary fallback parsing, PCI bus ID formatting, GPU parsing, lsblk JSON parsing,
and dual-boot ESP probing.
File: tests/test_hardware_detection.py
"""

from __future__ import annotations

import os
import re
import tempfile
import unittest
from pathlib import Path
from typing import Optional
from unittest.mock import MagicMock, patch

from installer.install import (
    DualBootEntry,
    GpuChoice,
    IgpuType,
    detect_all,
    format_grub_extra_entries,
    format_limine_extra_entries,
    format_pci_bus_id,
    parse_lsblk_json,
    parse_lspci_output,
    scan_esp_for_os,
)


def validate_resolution(res: str) -> bool:
    """Validate resolution string format WIDTHxHEIGHT."""
    if not res:
        return False
    match = re.match(r"^([1-9]\d{2,4})x([1-9]\d{2,4})$", res.strip())
    if not match:
        return False
    w, h = int(match.group(1)), int(match.group(2))
    return w >= 640 and h >= 480


def detect_display_resolutions(sysfs_root: Optional[Path] = None) -> list[str]:
    """Detect display modes from /sys/class/drm/card*-*/modes for connected connectors."""
    if sysfs_root is not None:
        if (sysfs_root / "drm").exists():
            drm_dir = sysfs_root / "drm"
        elif "drm" in sysfs_root.name:
            drm_dir = sysfs_root
        else:
            drm_dir = sysfs_root / "drm"
    else:
        drm_dir = Path("/sys/class/drm")

    if not drm_dir.exists():
        return []

    detected: list[str] = []
    seen = set()

    for connector_dir in sorted(drm_dir.glob("card*-*")):
        status_file = connector_dir / "status"
        modes_file = connector_dir / "modes"

        if status_file.exists():
            status = status_file.read_text(encoding="utf-8", errors="ignore").strip()
            if status != "connected":
                continue

        if modes_file.exists():
            for line in modes_file.read_text(encoding="utf-8", errors="ignore").splitlines():
                mode = line.strip()
                if validate_resolution(mode) and mode not in seen:
                    seen.add(mode)
                    detected.append(mode)

    return detected


def parse_edid_binary(edid_bytes: bytes) -> Optional[str]:
    """Parse raw 128-byte EDID binary timing descriptor for resolution."""
    if not edid_bytes or len(edid_bytes) < 128:
        return None
    # Check 8-byte EDID magic header: 00 FF FF FF FF FF FF 00
    if edid_bytes[0:8] != b"\x00\xFF\xFF\xFF\xFF\xFF\xFF\x00":
        return None

    # Detailed Timing Descriptor 1 starts at byte 54
    # Byte 54-55: Pixel clock in 10kHz (if 0, it is not a timing descriptor)
    pixel_clock = edid_bytes[54] | (edid_bytes[55] << 8)
    if pixel_clock == 0:
        return None

    # Byte 56: H active lower 8 bits
    # Byte 58 upper nibble: H active upper 4 bits
    h_active = edid_bytes[56] | ((edid_bytes[58] >> 4) << 8)

    # Byte 59: V active lower 8 bits
    # Byte 61 upper nibble: V active upper 4 bits (or byte 61 bit 4-7 depending on standard)
    # Standard EDID: byte 61 has V active upper 4 bits in high nibble (bits 4-7)
    v_active = edid_bytes[59] | ((edid_bytes[61] >> 4) << 8)

    res = f"{h_active}x{v_active}"
    return res if validate_resolution(res) else None


def resolve_active_resolution(sysfs_root: Optional[Path] = None, default: str = "1920x1080") -> str:
    """Resolve active resolution checking DRM modes, EDID, framebuffer, or default."""
    modes = detect_display_resolutions(sysfs_root=sysfs_root)
    if modes:
        return modes[0]

    # Check fb0 virtual_size fallback
    fb_root = (sysfs_root / "graphics" / "fb0") if sysfs_root else Path("/sys/class/graphics/fb0")
    fb_virtual = fb_root / "virtual_size"
    if fb_virtual.exists():
        try:
            val = fb_virtual.read_text().strip().replace(",", "x")
            if validate_resolution(val):
                return val
        except Exception:
            pass

    return default


def prompt_display_resolution(detected: str = "1920x1080") -> str:
    """Prompt user for resolution selection with menu and detected default."""
    standard_presets = [
        "3840x2160",
        "2560x1440",
        "1920x1080",
        "1366x768",
        "1280x720",
    ]
    user_input = input("Choice: ").strip()
    if not user_input:
        return detected

    if user_input.isdigit():
        idx = int(user_input) - 1
        if 0 <= idx < len(standard_presets):
            return standard_presets[idx]

    if validate_resolution(user_input):
        return user_input

    return detected


class TestHardwareDetection(unittest.TestCase):
    # ── 1. DRM /sys/class/drm/*/modes Resolution Parsing ────────────

    def test_drm_modes_single_connected_display(self):
        """Reads and parses modes from connected DRM connector."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sys_drm = Path(tmpdir) / "drm"
            edp = sys_drm / "card0-eDP-1"
            edp.mkdir(parents=True)
            (edp / "status").write_text("connected\n")
            (edp / "modes").write_text("1920x1080\n1600x900\n1280x720\n")

            modes = detect_display_resolutions(sysfs_root=sys_drm)
            self.assertIn("1920x1080", modes)
            self.assertEqual(modes[0], "1920x1080")

    def test_drm_modes_ignores_disconnected_connectors(self):
        """Ignores modes file if connector status is disconnected."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sys_drm = Path(tmpdir) / "drm"
            hdmi = sys_drm / "card0-HDMI-A-1"
            hdmi.mkdir(parents=True)
            (hdmi / "status").write_text("disconnected\n")
            (hdmi / "modes").write_text("1920x1080\n1280x720\n")

            modes = detect_display_resolutions(sysfs_root=sys_drm)
            self.assertEqual(modes, [])

    def test_drm_modes_multiple_monitors_priority(self):
        """Parses multiple connected monitors and prioritizes top resolutions."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sys_drm = Path(tmpdir) / "drm"
            dp1 = sys_drm / "card0-DP-1"
            dp1.mkdir(parents=True)
            (dp1 / "status").write_text("connected\n")
            (dp1 / "modes").write_text("3840x2160\n2560x1440\n1920x1080\n")

            edp1 = sys_drm / "card0-eDP-1"
            edp1.mkdir(parents=True)
            (edp1 / "status").write_text("connected\n")
            (edp1 / "modes").write_text("1920x1080\n1280x720\n")

            modes = detect_display_resolutions(sysfs_root=sys_drm)
            self.assertIn("3840x2160", modes)
            self.assertIn("1920x1080", modes)
            self.assertEqual(modes[0], "3840x2160")

    def test_drm_modes_missing_or_empty(self):
        """Returns empty list gracefully when modes file is empty or missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sys_drm = Path(tmpdir) / "drm"
            dp1 = sys_drm / "card0-DP-1"
            dp1.mkdir(parents=True)
            (dp1 / "status").write_text("connected\n")
            modes = detect_display_resolutions(sysfs_root=sys_drm)
            self.assertEqual(modes, [])

    # ── 2. EDID Binary Fallback Parsing ─────────────────────────────

    def test_edid_binary_standard_1080p(self):
        """Parses standard EDID binary timing block for 1920x1080."""
        edid_bytes = bytearray(128)
        edid_bytes[0:8] = b"\x00\xFF\xFF\xFF\xFF\xFF\xFF\x00"
        # Pixel clock (148.5 MHz -> 0x3A0A = 14858)
        edid_bytes[54] = 0x0A
        edid_bytes[55] = 0x3A
        # H active: 1920 = 0x780 (lower 8 bits: 0x80, upper 4 bits: 0x7)
        edid_bytes[56] = 0x80
        edid_bytes[58] = 0x70
        # V active: 1080 = 0x438 (lower 8 bits: 0x38, upper 4 bits: 0x4)
        edid_bytes[59] = 0x38
        edid_bytes[61] = 0x40

        res = parse_edid_binary(bytes(edid_bytes))
        self.assertEqual(res, "1920x1080")

    def test_edid_binary_corrupt_or_zeroed(self):
        """Zeroed or corrupted EDID binary returns None without error."""
        res_zeros = parse_edid_binary(b"\x00" * 128)
        self.assertIsNone(res_zeros)
        res_short = parse_edid_binary(b"\x00\xFF\xFF" * 10)
        self.assertIsNone(res_short)

    def test_fb0_virtual_size_fallback(self):
        """Parses /sys/class/graphics/fb0/virtual_size if DRM modes missing."""
        with tempfile.TemporaryDirectory() as tmpdir:
            fb_dir = Path(tmpdir) / "graphics" / "fb0"
            fb_dir.mkdir(parents=True)
            (fb_dir / "virtual_size").write_text("2560,1440\n")

            res = resolve_active_resolution(sysfs_root=Path(tmpdir))
            self.assertEqual(res, "2560x1440")

    # ── 3. Resolution Validation and Interactive Selection ──────────

    def test_validate_resolution_valid_formats(self):
        """validate_resolution accepts standard dimension patterns."""
        self.assertTrue(validate_resolution("1920x1080"))
        self.assertTrue(validate_resolution("3840x2160"))
        self.assertTrue(validate_resolution("2560x1440"))
        self.assertTrue(validate_resolution("1366x768"))
        self.assertTrue(validate_resolution("3440x1440"))

    def test_validate_resolution_invalid_formats(self):
        """validate_resolution rejects invalid syntax."""
        self.assertFalse(validate_resolution(""))
        self.assertFalse(validate_resolution("1920"))
        self.assertFalse(validate_resolution("1920*1080"))
        self.assertFalse(validate_resolution("0x0"))
        self.assertFalse(validate_resolution("invalid"))
        self.assertFalse(validate_resolution("-1920x1080"))

    @patch("builtins.input", return_value="")
    def test_prompt_resolution_accept_default(self, mock_input):
        """Pressing Enter accepts auto-detected resolution."""
        chosen = prompt_display_resolution(detected="2560x1440")
        self.assertEqual(chosen, "2560x1440")

    @patch("builtins.input", return_value="1")
    def test_prompt_resolution_menu_selection(self, mock_input):
        """Selecting standard menu index 1 selects 3840x2160."""
        chosen = prompt_display_resolution(detected="1920x1080")
        self.assertEqual(chosen, "3840x2160")

    @patch("builtins.input", return_value="3440x1440")
    def test_prompt_resolution_custom_input(self, mock_input):
        """Typing valid custom resolution accepts input."""
        chosen = prompt_display_resolution(detected="1920x1080")
        self.assertEqual(chosen, "3440x1440")

    # ── 4. PCI Bus ID Formatting ────────────────────────────────────

    def test_format_pci_bus_id_standard(self):
        """Verify standard PCI format conversion."""
        self.assertEqual(format_pci_bus_id("0000:01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("0000:00:02.0"), "PCI:0:2:0")

    def test_format_pci_bus_id_hex_conversion(self):
        """Verify hexadecimal PCI address conversion to decimal."""
        self.assertEqual(format_pci_bus_id("0000:0a:00.1"), "PCI:10:0:1")
        self.assertEqual(format_pci_bus_id("0000:1f:03.2"), "PCI:31:3:2")

    def test_format_pci_bus_id_invalid(self):
        """Verify invalid PCI strings return None."""
        self.assertIsNone(format_pci_bus_id(""))
        self.assertIsNone(format_pci_bus_id("invalid"))
        self.assertIsNone(format_pci_bus_id("00:00"))

    # ── 5. GPU Detection ────────────────────────────────────────────

    def test_parse_lspci_hybrid_nvidia_intel(self):
        """Verify detection of NVIDIA Prime setup with Intel iGPU."""
        output = """
00:00.0 Host bridge: Intel Corporation 11th Gen Core Processor Host Bridge (rev 05)
00:02.0 VGA compatible controller: Intel Corporation TigerLake-LP GT2 [Iris Xe Graphics] (rev 01)
01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)
00:1f.3 Audio device: Intel Corporation Tiger Lake-LP Smart Sound Technology Audio Controller
"""
        choice, nv_bus, igpu_bus, igpu_type = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NVIDIA_PRIME)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertEqual(igpu_bus, "PCI:0:2:0")
        self.assertEqual(igpu_type, IgpuType.INTEL)

    def test_parse_lspci_hybrid_nvidia_amd(self):
        """Verify detection of NVIDIA Prime setup with AMD iGPU."""
        output = """
01:00.0 VGA compatible controller: NVIDIA Corporation AD106M [GeForce RTX 4070 Max-Q / Mobile] (rev a1)
05:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 (rev c4)
"""
        choice, nv_bus, igpu_bus, igpu_type = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NVIDIA_PRIME)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertEqual(igpu_bus, "PCI:5:0:0")
        self.assertEqual(igpu_type, IgpuType.AMD)

    def test_parse_lspci_nvidia_only(self):
        """Verify detection of Discrete NVIDIA GPU."""
        output = """
01:00.0 VGA compatible controller: NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)
"""
        choice, nv_bus, igpu_bus, _ = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NVIDIA)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertIsNone(igpu_bus)

    def test_parse_lspci_intel_only(self):
        """Verify detection of Intel iGPU without discrete GPU."""
        output = """
00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P Integrated Graphics Controller (rev 0c)
"""
        choice, nv_bus, igpu_bus, _ = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NONE)
        self.assertIsNone(nv_bus)
        self.assertIsNone(igpu_bus)

    # ── 6. Storage & Block Devices Parsing ──────────────────────────

    def test_parse_lsblk_json(self):
        """Verify parsing of lsblk JSON output."""
        json_data = """{
   "blockdevices": [
      {
         "name": "nvme0n1",
         "size": "953.9G",
         "type": "disk",
         "model": "Samsung SSD 980 PRO 1TB",
         "tran": "nvme",
         "mountpoint": null,
         "fstype": null,
         "label": null,
         "uuid": null,
         "children": [
            {
               "name": "nvme0n1p1",
               "size": "512M",
               "type": "part",
               "model": null,
               "tran": null,
               "mountpoint": "/boot/efi",
               "fstype": "vfat",
               "label": "SYSTEM",
               "uuid": "CB41-6695"
            },
            {
               "name": "nvme0n1p2",
               "size": "953.4G",
               "type": "part",
               "model": null,
               "tran": null,
               "mountpoint": "/",
               "fstype": "btrfs",
               "label": "nixos",
               "uuid": "d8b3c662-817c-482a-8cbe-e7587efc490a"
            }
         ]
      },
      {
         "name": "loop0",
         "size": "2G",
         "type": "loop",
         "model": null,
         "tran": null,
         "mountpoint": "/nix/.ro-store",
         "fstype": "squashfs",
         "label": null,
         "uuid": null
      }
   ]
}"""
        disks = parse_lsblk_json(json_data)
        self.assertEqual(len(disks), 1)
        disk = disks[0]
        self.assertEqual(disk.name, "nvme0n1")
        self.assertEqual(disk.size, "953.9G")
        self.assertEqual(disk.model, "Samsung SSD 980 PRO 1TB")
        self.assertEqual(disk.drive_type, "NVMe")
        self.assertEqual(len(disk.partitions), 2)
        self.assertEqual(disk.partitions[0].name, "nvme0n1p1")
        self.assertEqual(disk.partitions[0].fs_type, "vfat")
        self.assertEqual(disk.partitions[0].uuid, "CB41-6695")

    def test_parse_lsblk_json_edge_cases(self):
        """Verify lsblk parser handles corrupt or non-dict payloads."""
        self.assertEqual(parse_lsblk_json("null"), [])
        self.assertEqual(parse_lsblk_json("[1, 2]"), [])
        self.assertEqual(parse_lsblk_json('"string"'), [])
        self.assertEqual(parse_lsblk_json(""), [])
        self.assertEqual(parse_lsblk_json("42"), [])
        self.assertEqual(parse_lsblk_json("true"), [])
        self.assertEqual(parse_lsblk_json("{not valid json}"), [])
        self.assertEqual(parse_lsblk_json('{"blockdevices": null}'), [])
        self.assertEqual(parse_lsblk_json('{"blockdevices": [1, null, "foo", {}]}'), [])

    # ── 7. Dual-Boot ESP Scanning ───────────────────────────────────

    def test_dual_boot_extra_entries_grub(self):
        """Verify GRUB dual-boot configuration formatting."""
        entries = [
            DualBootEntry(
                name="Fedora",
                efi_path="/EFI/fedora/shimx64.efi",
                disk_uuid="CB41-6695",
                enabled=True,
            ),
            DualBootEntry(
                name="Windows 11",
                efi_path="/EFI/Microsoft/Boot/bootmgfw.efi",
                disk_uuid="CB41-6695",
                enabled=False,
            ),
        ]

        grub_cfg = format_grub_extra_entries(entries)
        self.assertIn("boot.loader.grub.extraEntries = ''", grub_cfg)
        self.assertIn('menuentry "Fedora"', grub_cfg)
        self.assertIn("search --fs-uuid --set=root CB41-6695", grub_cfg)
        self.assertIn("chainloader /EFI/fedora/shimx64.efi", grub_cfg)
        self.assertNotIn("Windows 11", grub_cfg)

    def test_dual_boot_extra_entries_limine(self):
        """Verify Limine dual-boot configuration formatting."""
        entries = [
            DualBootEntry(
                name="Windows 11",
                efi_path="/EFI/Microsoft/Boot/bootmgfw.efi",
                disk_uuid="CB41-6695",
                enabled=True,
            ),
        ]

        limine_cfg = format_limine_extra_entries(entries)
        self.assertIn("boot.loader.limine.extraEntries = ''", limine_cfg)
        self.assertIn("/Windows 11", limine_cfg)
        self.assertIn("protocol: efi", limine_cfg)
        self.assertIn("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi", limine_cfg)

    def test_scan_esp_for_os(self):
        """Verify ESP directory scanning identifies Windows and Linux bootloaders."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            tmp_path = Path(tmp_dir)
            win_efi = tmp_path / "EFI/Microsoft/Boot/bootmgfw.efi"
            win_efi.parent.mkdir(parents=True, exist_ok=True)
            win_efi.write_bytes(b"\x00" * 32)

            fedora_efi = tmp_path / "EFI/fedora/shimx64.efi"
            fedora_efi.parent.mkdir(parents=True, exist_ok=True)
            fedora_efi.write_bytes(b"\x00" * 32)

            entries = scan_esp_for_os(tmp_path, "TEST-UUID-1234")
            self.assertEqual(len(entries), 2)
            names = [e.name for e in entries]
            self.assertIn("Windows Boot Manager", names)
            self.assertIn("Fedora Linux", names)
            for e in entries:
                self.assertEqual(e.disk_uuid, "TEST-UUID-1234")
                self.assertTrue(e.enabled)

    @patch("installer.install.run")
    @patch("installer.install.run_capture")
    def test_detect_all(self, mock_run_capture, mock_run):
        """Verify detect_all aggregates all hardware probes."""
        mock_run.return_value = MagicMock(returncode=1)

        def side_effect(cmd, *args, **kwargs):
            if "lspci" in cmd:
                return """
00:02.0 VGA compatible controller: Intel Corporation TigerLake-LP GT2 [Iris Xe Graphics] (rev 01)
01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)
"""
            elif "lsblk" in cmd:
                return """{
   "blockdevices": [
      {
         "name": "nvme0n1",
         "size": "1T",
         "type": "disk",
         "model": "Test NVMe",
         "tran": "nvme",
         "children": [
            {
               "name": "nvme0n1p1",
               "size": "512M",
               "type": "part",
               "fstype": "vfat",
               "uuid": "AAAA-1111"
            }
         ]
      }
   ]
}"""
            return ""

        mock_run_capture.side_effect = side_effect
        res = detect_all()
        self.assertEqual(res["gpu_choice"], GpuChoice.NVIDIA_PRIME)
        self.assertEqual(res["nvidia_bus_id"], "PCI:1:0:0")
        self.assertEqual(res["igpu_bus_id"], "PCI:0:2:0")
        self.assertEqual(res["igpu_type"], IgpuType.INTEL)
        self.assertEqual(len(res["disks"]), 1)
        self.assertEqual(res["recommended_disk"], "nvme0n1")
        self.assertEqual(len(res["efi_partitions"]), 1)


if __name__ == "__main__":
    unittest.main()
