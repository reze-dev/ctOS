use crate::app::{DiskInfo, DualBootEntry, GpuChoice, IgpuType, PartitionInfo};
use crate::cmd::run_capture;
use serde::Deserialize;
use std::path::Path;

#[derive(Debug, Clone, Default)]
pub struct DetectedHardware {
    pub disks: Vec<DiskInfo>,
    pub recommended_disk: Option<String>,
    pub efi_partitions: Vec<(String, String, String)>, // (dev, size, uuid)
    pub detected_os: Vec<DualBootEntry>,
    pub gpu_choice: GpuChoice,
    pub nvidia_bus_id: Option<String>,
    pub igpu_bus_id: Option<String>,
    pub igpu_type: IgpuType,
}

#[derive(Debug, Deserialize)]
struct LsblkJson {
    #[serde(default)]
    blockdevices: Vec<LsblkDevice>,
}

#[derive(Debug, Deserialize)]
struct LsblkDevice {
    name: String,
    #[serde(default)]
    size: Option<String>,
    #[serde(default)]
    #[serde(rename = "type")]
    device_type: Option<String>,
    #[serde(default)]
    model: Option<String>,
    #[serde(default)]
    tran: Option<String>,
    #[serde(default)]
    mountpoint: Option<String>,
    #[serde(default)]
    fstype: Option<String>,
    #[serde(default)]
    label: Option<String>,
    #[serde(default)]
    uuid: Option<String>,
    #[serde(default)]
    children: Option<Vec<LsblkDevice>>,
}

/// Parse PCI slot string (e.g. "01:00.0" or "0000:01:00.0") into Nix format "PCI:1:0:0"
pub fn format_pci_bus_id(raw: &str) -> Option<String> {
    let clean = raw.trim();
    if clean.is_empty() {
        return None;
    }

    // Strip domain if present (e.g., "0000:01:00.0" -> "01:00.0")
    let after_domain = if clean.matches(':').count() >= 2 {
        clean.split_once(':')?.1
    } else {
        clean
    };

    let parts: Vec<&str> = after_domain.split(':').collect();
    if parts.len() != 2 {
        return None;
    }

    let bus_str = parts[0];
    let dev_fn_parts: Vec<&str> = parts[1].split('.').collect();
    if dev_fn_parts.len() != 2 {
        return None;
    }

    let dev_str = dev_fn_parts[0];
    let fn_str = dev_fn_parts[1];

    let bus = u32::from_str_radix(bus_str, 16).ok()?;
    let dev = u32::from_str_radix(dev_str, 16).ok()?;
    let func = u32::from_str_radix(fn_str, 16).ok()?;

    Some(format!("PCI:{bus}:{dev}:{func}"))
}

/// Parse lspci output lines and extract GPU bus IDs and vendors.
pub fn parse_lspci_output(output: &str) -> (GpuChoice, Option<String>, Option<String>, IgpuType) {
    let mut nvidia_bus = None;
    let mut intel_bus = None;
    let mut amd_bus = None;

    for line in output.lines() {
        let line_lower = line.to_lowercase();
        // Look for display / VGA / 3D controllers
        if line_lower.contains("vga compatible controller")
            || line_lower.contains("3d controller")
            || line_lower.contains("display controller")
        {
            let slot = line.split_whitespace().next().unwrap_or("");
            let formatted = format_pci_bus_id(slot);

            if line_lower.contains("nvidia") {
                nvidia_bus = formatted;
            } else if line_lower.contains("intel") {
                intel_bus = formatted;
            } else if line_lower.contains("amd")
                || line_lower.contains("advanced micro devices")
                || line_lower.contains("radeon")
            {
                amd_bus = formatted;
            }
        }
    }

    if let Some(nv) = nvidia_bus {
        if let Some(amd) = amd_bus {
            (GpuChoice::NvidiaPrime, Some(nv), Some(amd), IgpuType::Amd)
        } else if let Some(intel) = intel_bus {
            (
                GpuChoice::NvidiaPrime,
                Some(nv),
                Some(intel),
                IgpuType::Intel,
            )
        } else {
            (GpuChoice::Nvidia, Some(nv), None, IgpuType::Intel)
        }
    } else {
        (GpuChoice::None, None, None, IgpuType::Intel)
    }
}

/// Parse lsblk JSON output into structured DiskInfo list.
pub fn parse_lsblk_json(json_str: &str) -> Vec<DiskInfo> {
    let Ok(data) = serde_json::from_str::<LsblkJson>(json_str) else {
        return Vec::new();
    };

    let mut disks = Vec::new();
    for dev in data.blockdevices {
        let dev_type = dev.device_type.as_deref().unwrap_or("");
        // Only include whole disk devices, exclude loop, zram, etc.
        if dev_type != "disk" && !dev.name.starts_with("nvme") && !dev.name.starts_with("sd") {
            continue;
        }
        if dev.name.starts_with("loop") || dev.name.starts_with("zram") {
            continue;
        }

        let model = dev
            .model
            .unwrap_or_else(|| "Unknown Disk".into())
            .trim()
            .to_string();
        let tran = dev.tran.unwrap_or_default().to_uppercase();
        let drive_type = if dev.name.starts_with("nvme") {
            "NVMe".to_string()
        } else if !tran.is_empty() {
            tran
        } else {
            "Disk".to_string()
        };

        let mut partitions = Vec::new();
        if let Some(children) = dev.children {
            for child in children {
                partitions.push(PartitionInfo {
                    name: child.name,
                    size: child.size.unwrap_or_else(|| "?".into()),
                    fs_type: child.fstype.unwrap_or_default(),
                    mountpoint: child.mountpoint,
                    label: child.label,
                    uuid: child.uuid,
                });
            }
        }

        disks.push(DiskInfo {
            name: dev.name,
            size: dev.size.unwrap_or_else(|| "?".into()),
            model,
            drive_type,
            partitions,
        });
    }

    disks
}

/// Detect dual-boot EFI files in a mounted ESP directory.
pub fn scan_esp_for_os(esp_mount_path: &Path, esp_uuid: &str) -> Vec<DualBootEntry> {
    let mut entries = Vec::new();

    let candidates = [
        ("EFI/Microsoft/Boot/bootmgfw.efi", "Windows Boot Manager"),
        ("EFI/fedora/shimx64.efi", "Fedora Linux"),
        ("EFI/ubuntu/shimx64.efi", "Ubuntu"),
        ("EFI/arch/grubx64.efi", "Arch Linux"),
        ("EFI/debian/shimx64.efi", "Debian"),
        ("EFI/opensuse/shim.efi", "openSUSE"),
    ];

    for (rel_path, name) in candidates {
        let full_path = esp_mount_path.join(rel_path);
        if full_path.exists() {
            entries.push(DualBootEntry {
                name: name.to_string(),
                efi_path: format!("/{rel_path}"),
                disk_uuid: esp_uuid.to_string(),
                enabled: true,
            });
        }
    }

    entries
}

/// Format extraEntries block for GRUB.
pub fn format_grub_extra_entries(entries: &[DualBootEntry]) -> String {
    let enabled: Vec<&DualBootEntry> = entries.iter().filter(|e| e.enabled).collect();
    if enabled.is_empty() {
        return String::new();
    }

    let mut out = String::from("  boot.loader.grub.extraEntries = ''\n");
    for entry in enabled {
        out.push_str(&format!(
            "    menuentry \"{}\" {{\n      search --fs-uuid --set=root {}\n      chainloader {}\n    }}\n",
            entry.name, entry.disk_uuid, entry.efi_path
        ));
    }
    out.push_str("  '';");
    out
}

/// Format extraEntries block for Limine.
pub fn format_limine_extra_entries(entries: &[DualBootEntry]) -> String {
    let enabled: Vec<&DualBootEntry> = entries.iter().filter(|e| e.enabled).collect();
    if enabled.is_empty() {
        return String::new();
    }

    let mut out = String::from("  boot.loader.limine.extraEntries = ''\n");
    for entry in enabled {
        out.push_str(&format!(
            "    /{}\n    protocol: efi\n    path: boot():{}\n\n",
            entry.name, entry.efi_path
        ));
    }
    out.push_str("  '';");
    out
}

/// Run full automatic hardware detection.
pub async fn detect_all() -> DetectedHardware {
    let mut detected = DetectedHardware::default();

    // 1. Detect GPUs via lspci
    if let Ok(lspci_out) = run_capture("lspci -D 2>/dev/null || lspci 2>/dev/null").await {
        let (choice, nv_bus, igpu_bus, igpu_type) = parse_lspci_output(&lspci_out);
        detected.gpu_choice = choice;
        detected.nvidia_bus_id = nv_bus;
        detected.igpu_bus_id = igpu_bus;
        detected.igpu_type = igpu_type;
    }

    // 2. Detect Disks via lsblk JSON
    if let Ok(lsblk_out) = run_capture(
        "lsblk -J -o NAME,SIZE,TYPE,MODEL,TRAN,MOUNTPOINT,FSTYPE,LABEL,UUID 2>/dev/null",
    )
    .await
    {
        detected.disks = parse_lsblk_json(&lsblk_out);
        if let Some(first) = detected.disks.first() {
            detected.recommended_disk = Some(first.name.clone());
        }

        // Collect EFI partitions
        for disk in &detected.disks {
            for part in &disk.partitions {
                if part.fs_type.to_lowercase() == "vfat" || part.name.to_lowercase().contains("efi")
                {
                    let dev_path = format!("/dev/{}", part.name);
                    let uuid = part.uuid.clone().unwrap_or_default();
                    detected
                        .efi_partitions
                        .push((dev_path, part.size.clone(), uuid));
                }
            }
        }
    }

    // 3. Detect Dual-Boot OSes on EFI partition(s)
    let temp_esp = Path::new("/tmp/northstar-esp-scan");
    let _ = std::fs::create_dir_all(temp_esp);

    for (dev, _, uuid) in &detected.efi_partitions {
        // Try mounting read-only
        if crate::cmd::run(&format!("mount -o ro {dev} /tmp/northstar-esp-scan"))
            .await
            .is_ok()
        {
            let entries = scan_esp_for_os(temp_esp, uuid);
            detected.detected_os.extend(entries);
            let _ = crate::cmd::run("umount /tmp/northstar-esp-scan").await;
        }
    }
    let _ = std::fs::remove_dir_all(temp_esp);

    detected
}
