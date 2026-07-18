use crate::app::{GpuChoice, InstallConfig, InstallMode, ProgressUpdate};
use crate::cmd::*;
use crate::state::State;
use std::fs;
use std::time::Duration;
use tokio::io::AsyncWriteExt;
use tokio::sync::mpsc;

/// Hash a password securely without shell interpolation.
pub async fn hash_password(pw: &str) -> Result<String, String> {
    // Try mkpasswd first (no shell — pass password as argument directly)
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

    // Fallback: pipe password to openssl via stdin (no shell interpolation)
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
        // Drop stdin to close it and signal EOF
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

fn build_gpu_config(cfg: &InstallConfig) -> String {
    match cfg.gpu_choice {
        GpuChoice::None => String::new(),
        GpuChoice::Nvidia => "\n  # NVIDIA GPU\n  northstar.nvidia.enable = true;".to_string(),
        GpuChoice::NvidiaPrime => {
            let key = cfg.igpu_type.bus_id_key();
            format!(
                "\n  # NVIDIA GPU\n  northstar.nvidia.enable = true;\n  northstar.nvidia.prime = {{\n    enable = true;\n    nvidiaBusId = \"{}\";\n    {key} = \"{}\";\n  }};",
                cfg.nvidia_bus_id, cfg.igpu_bus_id
            )
        }
    }
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
    send("generate_config", "Generating configuration...");
    if !state.should_skip("generate_config") {
        if let Err(e) = generate_config(&cfg, work_dir).await {
            fail("generate_config", e);
            return;
        }
        state.set_step("partition");
    }
    done("generate_config", "Configuration generated");

    // Step 2: Partition
    send("partition", "Partitioning disk...");
    if !state.should_skip("partition") {
        if let Err(e) = do_partition(&cfg, work_dir).await {
            fail("partition", e);
            return;
        }
        state.set_step("install_nixos");
    }
    done("partition", "Disk partitioned");

    // Step 3: Install NixOS
    send(
        "install_nixos",
        "Installing NixOS (this may take a while)...",
    );
    if !state.should_skip("install_nixos") {
        if let Err(e) = do_install_nixos(&cfg).await {
            fail("install_nixos", e);
            return;
        }
        state.set_step("copy_flake");
    }
    done("install_nixos", "NixOS installed");

    // Step 4: Copy flake
    send("copy_flake", "Copying flake to installed system...");
    if !state.should_skip("copy_flake") {
        if let Err(e) = do_copy_flake(&cfg, work_dir).await {
            fail("copy_flake", e);
            return;
        }
        state.set_step("done");
    }
    done("copy_flake", "Flake copied");
}

async fn generate_config(cfg: &InstallConfig, work_dir: &str) -> Result<(), String> {
    let host_dir = format!("{work_dir}/hosts/{}", cfg.hostname);
    fs::create_dir_all(&host_dir).map_err(|e| e.to_string())?;

    let gpu_config = build_gpu_config(cfg);

    match cfg.mode {
        InstallMode::WholeDisk => {
            let hw = run_capture("nixos-generate-config --show-hardware-config")
                .await
                .map_err(|e| format!("hardware config: {e}"))?;
            fs::write(format!("{host_dir}/hardware.nix"), format!("{hw}\n"))
                .map_err(|e| e.to_string())?;

            let mut disko = format!(
                "# Auto-generated disko config for {}\n{{\n  disko.devices.disk.main.device = \"/dev/{}\";\n",
                cfg.hostname, cfg.disk_dev
            );
            if cfg.swap_size == "0" {
                disko += "  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = \"0\";\n";
            } else if cfg.swap_size != "8G" {
                disko += &format!(
                    "  disko.devices.disk.main.content.partitions.swap.size = \"{}\";\n",
                    cfg.swap_size
                );
            }
            disko += "}\n";
            fs::write(format!("{host_dir}/disko.nix"), &disko).map_err(|e| e.to_string())?;

            write_host_config(&host_dir, cfg, &gpu_config, "    ./disko.nix", "");

            if cfg.fs_type == "ext4" {
                let ext4 = "{\n  disko.devices.disk.main.content.partitions.root.content = {\n    type = \"filesystem\";\n    format = \"ext4\";\n    mountpoint = \"/\";\n  };\n}\n";
                fs::write(format!("{host_dir}/disko-fs.nix"), ext4).map_err(|e| e.to_string())?;
                let data =
                    fs::read_to_string(format!("{host_dir}/default.nix")).unwrap_or_default();
                let patched = data.replacen("imports = [", "imports = [\n    ./disko-fs.nix", 1);
                fs::write(format!("{host_dir}/default.nix"), patched).map_err(|e| e.to_string())?;
            }
        }
        InstallMode::PartitionOnly => {
            let boot = "\n  # Boot — use existing EFI bootloader (dual-boot safe)\n  boot.loader = {\n    efi = {\n      canTouchEfiVariables = true;\n      efiSysMountPoint = \"/boot/efi\";\n    };\n    grub = {\n      enable = true;\n      device = \"nodev\";\n      efiSupport = true;\n      useOSProber = true;\n    };\n  };\n\n";
            write_host_config(&host_dir, cfg, &gpu_config, "    ./filesystems.nix", boot);
        }
    }

    run_silent("git add .").await;
    Ok(())
}

fn write_host_config(
    host_dir: &str,
    cfg: &InstallConfig,
    gpu_config: &str,
    imports: &str,
    boot_config: &str,
) {
    let content = format!(
        r#"{{
  config,
  lib,
  pkgs,
  ...
}}:

{{
  imports = [
{imports}
  ];

  home-manager.users.{user} = {{
    imports = [ ../../home ];
    home.username = lib.mkForce "{user}";
    home.homeDirectory = lib.mkForce "/home/{user}";
  }};

  users.users.{user} = {{
    isNormalUser = true;
    description = "{user}";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "{pw}";
  }};
{gpu}

  networking.hostName = "{host}";
{boot}  system.stateVersion = "26.05";
}}
"#,
        user = cfg.username,
        pw = cfg.hashed_pw,
        gpu = gpu_config,
        host = cfg.hostname,
        boot = boot_config,
    );
    let _ = fs::write(format!("{host_dir}/default.nix"), content);
}

async fn do_partition(cfg: &InstallConfig, work_dir: &str) -> Result<(), String> {
    let host_dir = format!("{work_dir}/hosts/{}", cfg.hostname);

    retry("partition", 3, Duration::from_secs(5), || async {
        match cfg.mode {
            InstallMode::WholeDisk => {
                run(&format!(
                    r#"nix run github:nix-community/disko -- --mode disko --flake ".#{}""#,
                    cfg.hostname
                ))
                .await
            }
            InstallMode::PartitionOnly => partition_only_setup(cfg, &host_dir).await,
        }
    })
    .await
}

/// Partition-only setup: format, create subvolumes, mount, and generate config.
async fn partition_only_setup(cfg: &InstallConfig, host_dir: &str) -> Result<(), String> {
    let np = &cfg.nixos_part;
    let ep = &cfg.efi_part;
    let swap = &cfg.swap_size;

    format_btrfs(np).await?;
    create_subvolumes(np, swap).await?;
    mount_all(np, ep).await?;
    setup_swap(np, swap).await?;
    generate_filesystems_nix(cfg, host_dir).await?;

    let hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config").await?;
    let _ = fs::write(format!("{host_dir}/hardware.nix"), format!("{hw}\n"));
    run_silent("git add .").await;
    Ok(())
}

/// Format the NixOS partition as btrfs if needed.
async fn format_btrfs(partition: &str) -> Result<(), String> {
    if !has_filesystem(partition).await || get_filesystem(partition).await != "btrfs" {
        run(&format!("mkfs.btrfs -f {partition}")).await?;
    }
    Ok(())
}

/// Create btrfs subvolumes on the partition.
async fn create_subvolumes(partition: &str, swap: &str) -> Result<(), String> {
    if !is_mounted("/mnt").await {
        run(&format!("mount {partition} /mnt")).await?;
    }
    let mut subvols = vec!["@root", "@home", "@nix", "@log"];
    if swap != "0" {
        subvols.push("@swap");
    }
    for sv in &subvols {
        if !subvolume_exists("/mnt", sv).await {
            run(&format!("btrfs subvolume create /mnt/{sv}")).await?;
        }
    }
    let _ = run("umount /mnt").await;
    Ok(())
}

/// Mount all btrfs subvolumes and the EFI partition.
async fn mount_all(partition: &str, efi: &str) -> Result<(), String> {
    if !is_mounted("/mnt").await {
        run(&format!(
            "mount -o subvol=@root,compress=zstd {partition} /mnt"
        ))
        .await?;
    }
    for d in &["home", "nix", "var/log", "boot/efi"] {
        let _ = fs::create_dir_all(format!("/mnt/{d}"));
    }
    let mounts = [
        (
            format!("-o subvol=@home,compress=zstd {partition}"),
            "/mnt/home",
        ),
        (
            format!("-o subvol=@nix,compress=zstd,noatime {partition}"),
            "/mnt/nix",
        ),
        (
            format!("-o subvol=@log,compress=zstd {partition}"),
            "/mnt/var/log",
        ),
        (efi.to_string(), "/mnt/boot/efi"),
    ];
    for (opts, mp) in &mounts {
        if !is_mounted(mp).await {
            run(&format!("mount {opts} {mp}")).await?;
        }
    }
    Ok(())
}

/// Set up the btrfs swapfile.
async fn setup_swap(partition: &str, swap: &str) -> Result<(), String> {
    if swap == "0" || path_exists("/mnt/swap/swapfile") {
        return Ok(());
    }
    let _ = fs::create_dir_all("/mnt/swap");
    if !is_mounted("/mnt/swap").await {
        let _ = run(&format!("mount -o subvol=@swap {partition} /mnt/swap")).await;
    }
    run_silent("chattr +C /mnt/swap").await;
    let _ = run("truncate -s 0 /mnt/swap/swapfile").await;
    run_silent("chattr +C /mnt/swap/swapfile").await;
    let _ = run(&format!("fallocate -l {swap} /mnt/swap/swapfile")).await;
    let _ = run("chmod 600 /mnt/swap/swapfile").await;
    let _ = run("mkswap /mnt/swap/swapfile").await;
    let _ = run("swapon /mnt/swap/swapfile").await;
    Ok(())
}

/// Generate the filesystems.nix file with UUID-based mounts.
async fn generate_filesystems_nix(cfg: &InstallConfig, host_dir: &str) -> Result<(), String> {
    let np = &cfg.nixos_part;
    let ep = &cfg.efi_part;
    let swap = &cfg.swap_size;

    let nixos_uuid = run_capture(&format!("blkid -s UUID -o value {np}"))
        .await
        .unwrap_or_default();
    let efi_uuid = run_capture(&format!("blkid -s UUID -o value {ep}"))
        .await
        .unwrap_or_default();

    let swap_config = if swap != "0" {
        format!(
            r#"

  fileSystems."/swap" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  }};

  swapDevices = [
    {{ device = "/swap/swapfile"; }}
  ];"#
        )
    } else {
        String::new()
    };

    let fs_nix = format!(
        r#"# Auto-generated filesystem configuration for {host}
{{
  fileSystems."/" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  }};

  fileSystems."/home" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  }};

  fileSystems."/nix" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  }};

  fileSystems."/var/log" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" ];
  }};

  fileSystems."/boot/efi" = {{
    device = "/dev/disk/by-uuid/{efi_uuid}";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  }};
{swap_config}
}}
"#,
        host = cfg.hostname
    );

    let _ = fs::write(format!("{host_dir}/filesystems.nix"), fs_nix);
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
                r#"cd {dest} && git init && git add . && git commit -m "Initial Northstar configuration for {hostname}""#
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
