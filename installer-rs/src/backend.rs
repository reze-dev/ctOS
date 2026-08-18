use crate::app::{
    BootloaderChoice, GpuChoice, InstallConfig, InstallMode, ProfileChoice,
    ProgressUpdate,
};
use crate::cmd::*;
use crate::detect::{format_grub_extra_entries, format_limine_extra_entries};
use crate::state::State;
use std::fs;
use std::time::Duration;
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc;

/// Hash a password securely without shell interpolation.
pub async fn hash_password(pw: &str) -> Result<String, String> {
    // Try mkpasswd first
    if let Ok(output) = tokio::process::Command::new("mkpasswd")
        .args(["-m", "sha-512", pw])
        .output()
        .await
    {
        if output.status.success() {
            let hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !hash.is_empty() {
                return Ok(hash);
            }
        }
    }

    // Fallback: pipe password to openssl via stdin
    let mut child = tokio::process::Command::new("openssl")
        .args(["passwd", "-6", "-stdin"])
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to spawn openssl: {e}"))?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(pw.as_bytes())
            .await
            .map_err(|e| format!("Failed to write password: {e}"))?;
    }

    let output = child
        .wait_with_output()
        .await
        .map_err(|e| format!("openssl failed: {e}"))?;

    let hash = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if hash.is_empty() {
        Err("No password hashing tool found (mkpasswd, openssl)".into())
    } else {
        Ok(hash)
    }
}

pub fn build_gpu_config(cfg: &InstallConfig) -> String {
    match cfg.gpu_choice {
        GpuChoice::None => String::new(),
        GpuChoice::Nvidia => "  # NVIDIA GPU\n  northstar.nvidia.enable = true;".to_string(),
        GpuChoice::NvidiaPrime => {
            let key = cfg.igpu_type.bus_id_key();
            format!(
                "  # NVIDIA GPU\n  northstar.nvidia.enable = true;\n  northstar.nvidia.prime = {{\n    enable = true;\n    nvidiaBusId = \"{}\";\n    {key} = \"{}\";\n  }};",
                cfg.nvidia_bus_id, cfg.igpu_bus_id
            )
        }
    }
}

pub fn build_bootloader_config(cfg: &InstallConfig) -> String {
    match cfg.bootloader {
        BootloaderChoice::Grub => {
            let mut s = "  # Bootloader\n  northstar.features.boot.loader = \"grub\";\n".to_string();
            let extra = format_grub_extra_entries(&cfg.dual_boot_entries);
            if !extra.is_empty() {
                s.push_str(&format!("{extra}\n"));
            }
            s
        }
        BootloaderChoice::Limine => {
            let mut s = "  # Bootloader\n  northstar.features.boot.loader = \"limine\";\n".to_string();
            let extra = format_limine_extra_entries(&cfg.dual_boot_entries);
            if !extra.is_empty() {
                s.push_str(&format!("{extra}\n"));
            }
            s
        }
    }
}

pub fn build_profile_config(cfg: &InstallConfig) -> String {
    let mut lines = vec!["  # Northstar profiles".to_string(), "  northstar.profiles = {".to_string()];

    match cfg.profile {
        ProfileChoice::Base => {
            lines.push("    base.enable = true;".into());
        }
        ProfileChoice::Desktop => {
            lines.push("    desktop.enable = true;".into());
        }
        ProfileChoice::Workstation => {
            lines.push("    desktop.enable = true;".into());
            lines.push("    workstation.enable = true;".into());
        }
    }
    lines.push("  };".into());
    lines.join("\n")
}

pub fn build_features_override(cfg: &InstallConfig) -> String {
    let defaults = crate::app::default_features(cfg.profile);
    let mut overrides = Vec::new();

    for custom in &cfg.features {
        if let Some(def) = defaults.iter().find(|d| d.id == custom.id) {
            if def.enabled != custom.enabled {
                overrides.push(format!("    {}.enable = {};", custom.id, custom.enabled));
            }
        }
    }

    if overrides.is_empty() {
        return String::new();
    }

    format!("  # Custom feature overrides\n  northstar.features = {{\n{}\n  }};", overrides.join("\n"))
}

/// Strip fileSystems and swapDevices entries from hardware.nix output.
pub fn strip_filesystems_from_hardware(hw_text: &str) -> String {
    let mut cleaned_lines = Vec::new();
    let mut in_fs_block = false;
    let mut fs_depth: i32 = 0;
    let mut in_swap_devices = false;

    for line in hw_text.lines() {
        let stripped = line.trim();

        if in_swap_devices {
            if stripped.contains(';') {
                in_swap_devices = false;
            }
            continue;
        }

        if stripped.starts_with("swapDevices") {
            if !stripped.contains(';') {
                in_swap_devices = true;
            }
            continue;
        }

        if stripped.starts_with("fileSystems.") || stripped.starts_with("fileSystems =") {
            in_fs_block = true;
            fs_depth += stripped.matches('{').count() as i32 - stripped.matches('}').count() as i32;
            if stripped.contains(';') || (fs_depth == 0 && stripped.contains('}')) {
                in_fs_block = false;
                fs_depth = 0;
            }
            continue;
        }

        if in_fs_block {
            fs_depth += stripped.matches('{').count() as i32 - stripped.matches('}').count() as i32;
            if fs_depth <= 0 && (stripped.contains('}') || stripped.contains(';')) {
                in_fs_block = false;
                fs_depth = 0;
            }
            continue;
        }

        cleaned_lines.push(line);
    }

    let mut result = cleaned_lines.join("\n");
    while result.contains("\n\n\n") {
        result = result.replace("\n\n\n", "\n\n");
    }
    result.trim().to_string()
}

/// Generate disko.nix content for whole-disk mode.
pub fn generate_disko_whole_disk(cfg: &InstallConfig) -> String {
    let template = if cfg.fs_type == "ext4" {
        "ext4"
    } else {
        "btrfs"
    };
    let mut disko = format!(
        "# Auto-generated disko config for {}\n{{ lib, ... }}:\n{{\n  imports = [ ../../lib/disko/{template}.nix ];\n\n  disko.devices.disk.main.device = \"/dev/{}\";\n",
        cfg.hostname, cfg.disk_dev
    );

    if cfg.swap_size == "0" {
        disko += "  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = lib.mkForce \"0\";\n";
    } else if cfg.swap_size != "8G" {
        disko += &format!(
            "  disko.devices.disk.main.content.partitions.swap.size = lib.mkForce \"{}\";\n",
            cfg.swap_size
        );
    }

    if cfg.root_size != "100%" {
        disko += &format!(
            "  disko.devices.disk.main.content.partitions.root.size = lib.mkForce \"{}\";\n",
            cfg.root_size
        );
    }

    disko += "}\n";
    disko
}

/// Generate disko.nix content for partition-only mode.
pub async fn generate_disko_partition_only(cfg: &InstallConfig) -> String {
    let np = &cfg.nixos_part;
    let ep = &cfg.efi_part;

    let efi_uuid = run_capture(&format!("blkid -s UUID -o value {ep}"))
        .await
        .unwrap_or_default();

    let mut lines = vec![
        format!(
            "# Auto-generated disko config for {} (partition-only)",
            cfg.hostname
        ),
        "{".to_string(),
        format!("  disko.devices.disk.nixos = {{"),
        format!("    type = \"disk\";"),
        format!("    device = \"{np}\";"),
        format!("    content = {{"),
    ];

    if cfg.fs_type == "btrfs" {
        lines.push("      type = \"btrfs\";".into());
        lines.push("      extraArgs = [ \"-f\" ];".into());
        lines.push("      subvolumes = {".into());
        lines.push("        \"/root\" = {".into());
        lines.push("          mountpoint = \"/\";".into());
        lines.push("          mountOptions = [ \"compress=zstd\" ];".into());
        lines.push("        };".into());
        lines.push("        \"/home\" = {".into());
        lines.push("          mountpoint = \"/home\";".into());
        lines.push("          mountOptions = [ \"compress=zstd\" ];".into());
        lines.push("        };".into());
        lines.push("        \"/nix\" = {".into());
        lines.push("          mountpoint = \"/nix\";".into());
        lines.push("          mountOptions = [ \"compress=zstd\" \"noatime\" ];".into());
        lines.push("        };".into());
        lines.push("        \"/log\" = {".into());
        lines.push("          mountpoint = \"/var/log\";".into());
        lines.push("          mountOptions = [ \"compress=zstd\" ];".into());
        lines.push("        };".into());
        if cfg.swap_size != "0" {
            lines.push("        \"/swap\" = {".into());
            lines.push("          mountpoint = \"/swap\";".into());
            lines.push("        };".into());
        }
        lines.push("      };".into());
    } else {
        lines.push("      type = \"filesystem\";".into());
        lines.push("      format = \"ext4\";".into());
        lines.push("      mountpoint = \"/\";".into());
    }

    lines.push("    };".into());
    lines.push("  };".into());

    if cfg.swap_size != "0" && cfg.fs_type == "ext4" && !cfg.swap_partition.is_empty() {
        lines.push(String::new());
        lines.push("  disko.devices.disk.swap = {".into());
        lines.push("    type = \"disk\";".into());
        lines.push(format!("    device = \"{}\";", cfg.swap_partition));
        lines.push("    content = {".into());
        lines.push("      type = \"swap\";".into());
        lines.push("      discardPolicy = \"both\";".into());
        lines.push("      resumeDevice = true;".into());
        lines.push("    };".into());
        lines.push("  };".into());
    }

    lines.push(String::new());
    lines.push("  # Existing EFI partition — not managed by disko".into());

    if !efi_uuid.is_empty() {
        lines.push("  fileSystems.\"/boot/efi\" = {".into());
        lines.push(format!("    device = \"/dev/disk/by-uuid/{efi_uuid}\";"));
        lines.push("    fsType = \"vfat\";".into());
        lines.push("    options = [ \"fmask=0022\" \"dmask=0022\" ];".into());
        lines.push("  };".into());
    } else {
        lines.push("  fileSystems.\"/boot/efi\" = {".into());
        lines.push(format!("    device = \"{ep}\";"));
        lines.push("    fsType = \"vfat\";".into());
        lines.push("    options = [ \"fmask=0022\" \"dmask=0022\" ];".into());
        lines.push("  };".into());
    }

    if cfg.swap_size != "0" && cfg.fs_type == "btrfs" {
        lines.push(String::new());
        lines.push("  swapDevices = [".into());
        lines.push("    { device = \"/swap/swapfile\"; }".into());
        lines.push("  ];".into());
    }

    lines.push("}".into());
    lines.push(String::new());

    lines.join("\n")
}

pub fn generate_host_default_nix(cfg: &InstallConfig) -> String {
    let bootloader_config = build_bootloader_config(cfg);
    let profiles_config = build_profile_config(cfg);
    let features_config = build_features_override(cfg);
    let gpu_config = build_gpu_config(cfg);

    let mut blocks = Vec::new();
    if !bootloader_config.is_empty() {
        blocks.push(bootloader_config.trim_end().to_string());
    }

    let user_block = format!(
        r#"  users.users.{user} = {{
    isNormalUser = true;
    description = "{user}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.{shell};
    hashedPassword = "{pw}";
  }};"#,
        user = cfg.username,
        shell = cfg.shell,
        pw = cfg.hashed_pw,
    );
    blocks.push(user_block);

    blocks.push(profiles_config);

    if !features_config.is_empty() {
        blocks.push(features_config);
    }

    if !gpu_config.is_empty() {
        blocks.push(gpu_config);
    }

    let body = blocks.join("\n\n");

    format!(
        r#"{{
  config,
  lib,
  pkgs,
  ...
}}:

{{
  imports = [
    ./disko.nix
  ];

  home-manager.users.{user} = {{
    imports = [ ../../home ];
    home.username = lib.mkForce "{user}";
    home.homeDirectory = lib.mkForce "/home/{user}";
  }};

{body}

  networking.hostName = "{host}";
  system.stateVersion = "26.11";
}}
"#,
        user = cfg.username,
        body = body,
        host = cfg.hostname,
    )
}

pub async fn generate_config(cfg: &InstallConfig, work_dir: &str) -> Result<(), String> {
    let host_dir = format!("{work_dir}/hosts/{}", cfg.hostname);
    let _ = fs::create_dir_all(&host_dir);

    // Write disko.nix
    let disko_content = if cfg.mode == InstallMode::WholeDisk {
        generate_disko_whole_disk(cfg)
    } else {
        generate_disko_partition_only(cfg).await
    };
    fs::write(format!("{host_dir}/disko.nix"), &disko_content)
        .map_err(|e| format!("Failed to write disko.nix: {e}"))?;

    // Write default.nix
    let default_content = generate_host_default_nix(cfg);
    fs::write(format!("{host_dir}/default.nix"), &default_content)
        .map_err(|e| format!("Failed to write default.nix: {e}"))?;

    // Track files in git for Nix flakes
    run_silent("git add -A").await;
    Ok(())
}

/// Run all installation steps, sending progress updates through the channel.
pub async fn run_installation(
    cfg: InstallConfig,
    state: &mut State,
    work_dir: &str,
    tx: mpsc::UnboundedSender<ProgressUpdate>,
) {
    let send = |step: &str, msg: &str| {
        let _ = tx.send(ProgressUpdate {
            step: step.into(),
            message: msg.into(),
            done: false,
            error: None,
        });
    };
    let done = |step: &str, msg: &str| {
        let _ = tx.send(ProgressUpdate {
            step: step.into(),
            message: msg.into(),
            done: true,
            error: None,
        });
    };
    let fail = |step: &str, err: String| {
        let _ = tx.send(ProgressUpdate {
            step: step.into(),
            message: String::new(),
            done: false,
            error: Some(err),
        });
    };

    // Step 1: Generate config
    send("generate_config", "Generating system configuration...");
    if !state.should_skip("generate_config") {
        if let Err(e) = generate_config(&cfg, work_dir).await {
            fail("generate_config", e);
            return;
        }
        state.set_step("partition");
    }
    done("generate_config", "Configuration generated");

    // Step 2: Partition
    send("partition", "Partitioning disk with Disko...");
    if !state.should_skip("partition") {
        if let Err(e) = do_partition(&cfg, work_dir).await {
            fail("partition", e);
            return;
        }
        state.set_step("install_nixos");
    }
    done("partition", "Disk partitioned & formatted");

    // Step 3: Install NixOS
    send("install_nixos", "Building & installing NixOS system...");
    if !state.should_skip("install_nixos") {
        if let Err(e) = do_install_nixos(&cfg).await {
            fail("install_nixos", e);
            return;
        }
        state.set_step("copy_flake");
    }
    done("install_nixos", "NixOS system installed");

    // Step 4: Copy Flake
    send("copy_flake", "Copying configuration flake to target user...");
    if !state.should_skip("copy_flake") {
        if let Err(e) = do_copy_flake(&cfg, work_dir).await {
            fail("copy_flake", e);
            return;
        }
        state.set_step("done");
    }
    done("copy_flake", "Flake copied to target user home");

    state.clear();
}

async fn do_partition(cfg: &InstallConfig, work_dir: &str) -> Result<(), String> {
    let host_dir = format!("{work_dir}/hosts/{}", cfg.hostname);

    retry("partition", 3, Duration::from_secs(5), || async {
        run(&format!(
            r#"nix run github:nix-community/disko -- --mode disko --flake ".#{}""#,
            cfg.hostname
        ))
        .await
    })
    .await?;

    if cfg.mode == InstallMode::PartitionOnly {
        let _ = fs::create_dir_all("/mnt/boot/efi");
        if !is_mounted("/mnt/boot/efi").await {
            run(&format!("mount {} /mnt/boot/efi", cfg.efi_part)).await?;
        }

        if cfg.swap_size != "0" && cfg.fs_type == "btrfs" {
            if !path_exists("/mnt/swap/swapfile") {
                run_silent("chattr +C /mnt/swap").await;
                let _ = run("truncate -s 0 /mnt/swap/swapfile").await;
                run_silent("chattr +C /mnt/swap/swapfile").await;
                let _ = run(&format!(
                    "fallocate -l {} /mnt/swap/swapfile",
                    cfg.swap_size
                ))
                .await;
                let _ = run("chmod 600 /mnt/swap/swapfile").await;
                let _ = run("mkswap /mnt/swap/swapfile").await;
                let _ = run("swapon /mnt/swap/swapfile").await;
            }
        }

        let hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config").await?;
        let hw = strip_filesystems_from_hardware(&hw);
        let _ = fs::write(format!("{host_dir}/hardware.nix"), format!("{hw}\n"));
        run_silent("git add -A").await;
    }

    Ok(())
}

async fn do_install_nixos(cfg: &InstallConfig) -> Result<(), String> {
    retry("nixos-install", 3, Duration::from_secs(10), || {
        let host = cfg.hostname.clone();
        async move {
            run(&format!(
                r#"nixos-install --flake ".#{host}" --no-root-password"#
            ))
            .await
        }
    })
    .await
}

async fn do_copy_flake(cfg: &InstallConfig, work_dir: &str) -> Result<(), String> {
    let dest = format!("/mnt/home/{}/northstar", cfg.username);
    let hostname = cfg.hostname.clone();
    let username = cfg.username.clone();
    let wd = work_dir.to_string();

    retry("copy-flake", 3, Duration::from_secs(5), || {
        let dest = dest.clone();
        let hostname = hostname.clone();
        let username = username.clone();
        let wd = wd.clone();
        async move {
            let _ = fs::remove_dir_all(&dest);
            run(&format!("cp -a {wd}/. {dest}/")).await?;
            let _ = fs::remove_dir_all(format!("{dest}/.git"));
            run(&format!(
                r#"cd {dest} && git init && git config user.name "Northstar Installer" && git config user.email "installer@northstar.local" && git add -A && git commit -m "Initial Northstar configuration for {hostname}""#
            )).await?;

            // Fix ownership
            if let Ok(passwd) = fs::read_to_string("/mnt/etc/passwd") {
                for line in passwd.lines() {
                    let fields: Vec<&str> = line.split(':').collect();
                    if fields.len() > 3 && fields[0] == username {
                        let (uid, gid) = (fields[2], fields[3]);
                        let _ = run(&format!("chown -R {uid}:{gid} {dest}")).await;
                        return Ok(());
                    }
                }
            }
            Ok(())
        }
    }).await
}
