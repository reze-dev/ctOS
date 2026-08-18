use northstar_installer::app::{DualBootEntry, GpuChoice, IgpuType};
use northstar_installer::detect::{
    format_grub_extra_entries, format_limine_extra_entries, format_pci_bus_id, parse_lsblk_json,
    parse_lspci_output,
};

#[test]
fn test_format_pci_bus_id_standard() {
    assert_eq!(format_pci_bus_id("0000:01:00.0"), Some("PCI:1:0:0".to_string()));
    assert_eq!(format_pci_bus_id("01:00.0"), Some("PCI:1:0:0".to_string()));
    assert_eq!(format_pci_bus_id("0000:00:02.0"), Some("PCI:0:2:0".to_string()));
}

#[test]
fn test_format_pci_bus_id_hex_conversion() {
    assert_eq!(format_pci_bus_id("0000:0a:00.1"), Some("PCI:10:0:1".to_string()));
    assert_eq!(format_pci_bus_id("0000:1f:03.2"), Some("PCI:31:3:2".to_string()));
}

#[test]
fn test_format_pci_bus_id_invalid() {
    assert_eq!(format_pci_bus_id(""), None);
    assert_eq!(format_pci_bus_id("invalid"), None);
    assert_eq!(format_pci_bus_id("00:00"), None);
}

#[test]
fn test_parse_lspci_hybrid_nvidia_intel() {
    let output = r#"
00:00.0 Host bridge: Intel Corporation 11th Gen Core Processor Host Bridge (rev 05)
00:02.0 VGA compatible controller: Intel Corporation TigerLake-LP GT2 [Iris Xe Graphics] (rev 01)
01:00.0 3D controller: NVIDIA Corporation GA107M [GeForce RTX 3050 Mobile] (rev a1)
00:1f.3 Audio device: Intel Corporation Tiger Lake-LP Smart Sound Technology Audio Controller
"#;

    let (choice, nv_bus, igpu_bus, igpu_type) = parse_lspci_output(output);
    assert_eq!(choice, GpuChoice::NvidiaPrime);
    assert_eq!(nv_bus, Some("PCI:1:0:0".to_string()));
    assert_eq!(igpu_bus, Some("PCI:0:2:0".to_string()));
    assert_eq!(igpu_type, IgpuType::Intel);
}

#[test]
fn test_parse_lspci_hybrid_nvidia_amd() {
    let output = r#"
01:00.0 VGA compatible controller: NVIDIA Corporation AD106M [GeForce RTX 4070 Max-Q / Mobile] (rev a1)
05:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1 (rev c4)
"#;

    let (choice, nv_bus, igpu_bus, igpu_type) = parse_lspci_output(output);
    assert_eq!(choice, GpuChoice::NvidiaPrime);
    assert_eq!(nv_bus, Some("PCI:1:0:0".to_string()));
    assert_eq!(igpu_bus, Some("PCI:5:0:0".to_string()));
    assert_eq!(igpu_type, IgpuType::Amd);
}

#[test]
fn test_parse_lspci_nvidia_only() {
    let output = r#"
01:00.0 VGA compatible controller: NVIDIA Corporation AD104 [GeForce RTX 4070] (rev a1)
"#;

    let (choice, nv_bus, igpu_bus, _) = parse_lspci_output(output);
    assert_eq!(choice, GpuChoice::Nvidia);
    assert_eq!(nv_bus, Some("PCI:1:0:0".to_string()));
    assert_eq!(igpu_bus, None);
}

#[test]
fn test_parse_lspci_intel_only() {
    let output = r#"
00:02.0 VGA compatible controller: Intel Corporation Alder Lake-P Integrated Graphics Controller (rev 0c)
"#;

    let (choice, nv_bus, igpu_bus, _) = parse_lspci_output(output);
    assert_eq!(choice, GpuChoice::None);
    assert_eq!(nv_bus, None);
    assert_eq!(igpu_bus, None);
}

#[test]
fn test_parse_lsblk_json() {
    let json = r#"{
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
}"#;

    let disks = parse_lsblk_json(json);
    assert_eq!(disks.len(), 1);
    let disk = &disks[0];
    assert_eq!(disk.name, "nvme0n1");
    assert_eq!(disk.size, "953.9G");
    assert_eq!(disk.model, "Samsung SSD 980 PRO 1TB");
    assert_eq!(disk.drive_type, "NVMe");
    assert_eq!(disk.partitions.len(), 2);
    assert_eq!(disk.partitions[0].name, "nvme0n1p1");
    assert_eq!(disk.partitions[0].fs_type, "vfat");
    assert_eq!(disk.partitions[0].uuid, Some("CB41-6695".to_string()));
}

#[test]
fn test_dual_boot_extra_entries_grub() {
    let entries = vec![
        DualBootEntry {
            name: "Fedora".to_string(),
            efi_path: "/EFI/fedora/shimx64.efi".to_string(),
            disk_uuid: "CB41-6695".to_string(),
            enabled: true,
        },
        DualBootEntry {
            name: "Windows 11".to_string(),
            efi_path: "/EFI/Microsoft/Boot/bootmgfw.efi".to_string(),
            disk_uuid: "CB41-6695".to_string(),
            enabled: false,
        },
    ];

    let grub_cfg = format_grub_extra_entries(&entries);
    assert!(grub_cfg.contains("boot.loader.grub.extraEntries = ''"));
    assert!(grub_cfg.contains("menuentry \"Fedora\""));
    assert!(grub_cfg.contains("search --fs-uuid --set=root CB41-6695"));
    assert!(grub_cfg.contains("chainloader /EFI/fedora/shimx64.efi"));
    // Disabled entry should not appear
    assert!(!grub_cfg.contains("Windows 11"));
}

#[test]
fn test_dual_boot_extra_entries_limine() {
    let entries = vec![
        DualBootEntry {
            name: "Windows 11".to_string(),
            efi_path: "/EFI/Microsoft/Boot/bootmgfw.efi".to_string(),
            disk_uuid: "CB41-6695".to_string(),
            enabled: true,
        },
    ];

    let limine_cfg = format_limine_extra_entries(&entries);
    assert!(limine_cfg.contains("boot.loader.limine.extraEntries = ''"));
    assert!(limine_cfg.contains("/Windows 11"));
    assert!(limine_cfg.contains("protocol: efi"));
    assert!(limine_cfg.contains("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi"));
}
