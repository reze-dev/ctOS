use northstar_installer::app::{
    BootloaderChoice, DualBootEntry, GpuChoice, IgpuType, InstallConfig, InstallMode, ProfileChoice,
};
use northstar_installer::backend::{
    generate_disko_whole_disk, generate_host_default_nix, strip_filesystems_from_hardware,
};

#[test]
fn test_generate_host_default_nix_base_grub() {
    let cfg = InstallConfig {
        hostname: "TestServer".to_string(),
        username: "admin".to_string(),
        hashed_pw: "$6$testhash".to_string(),
        profile: ProfileChoice::Base,
        shell: "zsh".to_string(),
        bootloader: BootloaderChoice::Grub,
        features: northstar_installer::app::default_features(ProfileChoice::Base),
        dual_boot_entries: Vec::new(),
        mode: InstallMode::WholeDisk,
        disk_dev: "sda".to_string(),
        nixos_part: String::new(),
        efi_part: String::new(),
        swap_size: "4G".to_string(),
        swap_partition: String::new(),
        fs_type: "btrfs".to_string(),
        root_size: "100%".to_string(),
        gpu_choice: GpuChoice::None,
        nvidia_bus_id: String::new(),
        igpu_bus_id: String::new(),
        igpu_type: IgpuType::Intel,
    };

    let content = generate_host_default_nix(&cfg);
    assert!(content.contains("networking.hostName = \"TestServer\";"));
    assert!(content.contains("home-manager.users.admin = {"));
    assert!(content.contains("users.users.admin = {"));
    assert!(content.contains("hashedPassword = \"$6$testhash\";"));
    assert!(content.contains("northstar.features.boot.loader = \"grub\";"));
    assert!(content.contains("base.enable = true;"));
    assert!(!content.contains("desktop.enable = true;"));
}

#[test]
fn test_generate_host_default_nix_desktop_limine_with_dualboot() {
    let cfg = InstallConfig {
        hostname: "DesktopHost".to_string(),
        username: "alice".to_string(),
        hashed_pw: "$6$alicehash".to_string(),
        profile: ProfileChoice::Desktop,
        shell: "fish".to_string(),
        bootloader: BootloaderChoice::Limine,
        features: northstar_installer::app::default_features(ProfileChoice::Desktop),
        dual_boot_entries: vec![DualBootEntry {
            name: "Windows 11".to_string(),
            efi_path: "/EFI/Microsoft/Boot/bootmgfw.efi".to_string(),
            disk_uuid: "ABCD-1234".to_string(),
            enabled: true,
        }],
        mode: InstallMode::WholeDisk,
        disk_dev: "nvme0n1".to_string(),
        nixos_part: String::new(),
        efi_part: String::new(),
        swap_size: "8G".to_string(),
        swap_partition: String::new(),
        fs_type: "btrfs".to_string(),
        root_size: "100%".to_string(),
        gpu_choice: GpuChoice::None,
        nvidia_bus_id: String::new(),
        igpu_bus_id: String::new(),
        igpu_type: IgpuType::Intel,
    };

    let content = generate_host_default_nix(&cfg);
    assert!(content.contains("networking.hostName = \"DesktopHost\";"));
    assert!(content.contains("northstar.features.boot.loader = \"limine\";"));
    assert!(content.contains("boot.loader.limine.extraEntries = ''"));
    assert!(content.contains("/Windows 11"));
    assert!(content.contains("path: boot():/EFI/Microsoft/Boot/bootmgfw.efi"));
    assert!(content.contains("desktop.enable = true;"));
}

#[test]
fn test_generate_host_default_nix_workstation_nvidia_prime() {
    let cfg = InstallConfig {
        hostname: "Makima".to_string(),
        username: "reze".to_string(),
        hashed_pw: "$6$rezehash".to_string(),
        profile: ProfileChoice::Workstation,
        shell: "zsh".to_string(),
        bootloader: BootloaderChoice::Grub,
        features: northstar_installer::app::default_features(ProfileChoice::Workstation),
        dual_boot_entries: Vec::new(),
        mode: InstallMode::WholeDisk,
        disk_dev: "nvme0n1".to_string(),
        nixos_part: String::new(),
        efi_part: String::new(),
        swap_size: "16G".to_string(),
        swap_partition: String::new(),
        fs_type: "btrfs".to_string(),
        root_size: "100%".to_string(),
        gpu_choice: GpuChoice::NvidiaPrime,
        nvidia_bus_id: "PCI:1:0:0".to_string(),
        igpu_bus_id: "PCI:5:0:0".to_string(),
        igpu_type: IgpuType::Amd,
    };

    let content = generate_host_default_nix(&cfg);
    assert!(content.contains("desktop.enable = true;"));
    assert!(content.contains("workstation.enable = true;"));
    assert!(content.contains("northstar.nvidia.enable = true;"));
    assert!(content.contains("northstar.nvidia.prime = {"));
    assert!(content.contains("nvidiaBusId = \"PCI:1:0:0\";"));
    assert!(content.contains("amdgpuBusId = \"PCI:5:0:0\";"));
}

#[test]
fn test_generate_disko_whole_disk_btrfs() {
    let cfg = InstallConfig {
        hostname: "NixRig".to_string(),
        disk_dev: "nvme0n1".to_string(),
        fs_type: "btrfs".to_string(),
        swap_size: "16G".to_string(),
        root_size: "100%".to_string(),
        ..Default::default()
    };

    let disko = generate_disko_whole_disk(&cfg);
    assert!(disko.contains("imports = [ ../../lib/disko/btrfs.nix ];"));
    assert!(disko.contains("disko.devices.disk.main.device = \"/dev/nvme0n1\";"));
    assert!(disko.contains("disko.devices.disk.main.content.partitions.swap.size = lib.mkForce \"16G\";"));
}

#[test]
fn test_generate_disko_whole_disk_ext4() {
    let cfg = InstallConfig {
        hostname: "Ext4Machine".to_string(),
        disk_dev: "sda".to_string(),
        fs_type: "ext4".to_string(),
        swap_size: "0".to_string(),
        root_size: "500G".to_string(),
        ..Default::default()
    };

    let disko = generate_disko_whole_disk(&cfg);
    assert!(disko.contains("imports = [ ../../lib/disko/ext4.nix ];"));
    assert!(disko.contains("disko.devices.disk.main.device = \"/dev/sda\";"));
    assert!(disko.contains("disko.devices.disk.main.content.partitions.swap.size = lib.mkForce \"0\";"));
    assert!(disko.contains("disko.devices.disk.main.content.partitions.root.size = lib.mkForce \"500G\";"));
}

#[test]
fn test_strip_filesystems_from_hardware() {
    let raw_hw = r#"
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
"#;

    let cleaned = strip_filesystems_from_hardware(raw_hw);
    assert!(!cleaned.contains("fileSystems.\"/\""));
    assert!(!cleaned.contains("fileSystems.\"/boot\""));
    assert!(!cleaned.contains("swapDevices"));
    assert!(cleaned.contains("boot.kernelModules = [ \"kvm-amd\" ];"));
    assert!(cleaned.contains("hardware.cpu.amd.updateMicrocode"));
}
