"""
Unit tests for hardware detection and bus ID formatting.
Directly mirrors installer-rs/tests/hardware_detection_tests.rs.
"""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

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


class TestHardwareDetection(unittest.TestCase):
    def test_format_pci_bus_id_standard(self):
        self.assertEqual(format_pci_bus_id("0000:01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("01:00.0"), "PCI:1:0:0")
        self.assertEqual(format_pci_bus_id("0000:00:02.0"), "PCI:0:2:0")

    def test_format_pci_bus_id_hex_conversion(self):
        self.assertEqual(format_pci_bus_id("0000:0a:00.1"), "PCI:10:0:1")
        self.assertEqual(format_pci_bus_id("0000:1f:03.2"), "PCI:31:3:2")

    def test_format_pci_bus_id_invalid(self):
        self.assertIsNone(format_pci_bus_id(""))
        self.assertIsNone(format_pci_bus_id("invalid"))
        self.assertIsNone(format_pci_bus_id("00:00"))

    def test_parse_lspci_hybrid_nvidia_intel(self):
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
        output = """
01:00.0 VGA compatible controller: NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)
"""
        choice, nv_bus, igpu_bus, _ = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NVIDIA)
        self.assertEqual(nv_bus, "PCI:1:0:0")
        self.assertIsNone(igpu_bus)

    def test_parse_lspci_intel_only(self):
        output = """
00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P Integrated Graphics Controller (rev 0c)
"""
        choice, nv_bus, igpu_bus, _ = parse_lspci_output(output)
        self.assertEqual(choice, GpuChoice.NONE)
        self.assertIsNone(nv_bus)
        self.assertIsNone(igpu_bus)

    def test_parse_lsblk_json(self):
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
        # Null JSON
        self.assertEqual(parse_lsblk_json("null"), [])
        # Array JSON
        self.assertEqual(parse_lsblk_json("[1, 2]"), [])
        # String JSON
        self.assertEqual(parse_lsblk_json('"string"'), [])
        # Empty string
        self.assertEqual(parse_lsblk_json(""), [])
        # Number JSON
        self.assertEqual(parse_lsblk_json("42"), [])
        # Boolean JSON
        self.assertEqual(parse_lsblk_json("true"), [])
        # Invalid JSON syntax
        self.assertEqual(parse_lsblk_json("{not valid json}"), [])
        # Null blockdevices
        self.assertEqual(parse_lsblk_json('{"blockdevices": null}'), [])
        # Blockdevices containing non-dict items
        self.assertEqual(parse_lsblk_json('{"blockdevices": [1, null, "foo", {}]}'), [])
        # Blockdevices with malformed child items
        disks = parse_lsblk_json('{"blockdevices": [{"name": "sda", "type": "disk", "children": [null, 42, {"name": "sda1", "fstype": "ext4", "size": "100G"}]}]}')
        self.assertEqual(len(disks), 1)
        self.assertEqual(disks[0].name, "sda")
        self.assertEqual(len(disks[0].partitions), 1)
        self.assertEqual(disks[0].partitions[0].name, "sda1")
        self.assertEqual(disks[0].partitions[0].fs_type, "ext4")

    def test_dual_boot_extra_entries_grub(self):
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
        # Disabled entry should not appear
        self.assertNotIn("Windows 11", grub_cfg)

    def test_dual_boot_extra_entries_limine(self):
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
        mock_run.return_value = unittest.mock.MagicMock(returncode=1)

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
