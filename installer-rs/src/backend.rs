use crate::app::{InstallConfig, ProgressUpdate};
use crate::cmd::*;
use crate::state::State;
use std::fs;
use std::time::Duration;
use tokio::sync::mpsc;

/// Hash a password using mkpasswd or openssl.
pub async fn hash_password(pw: &str) -> Result<String, String> {
    let cmds = [
        format!("mkpasswd -m sha-512 '{pw}'"),
        format!("echo '{pw}' | openssl passwd -6 -stdin"),
    ];
    for cmd in &cmds {
        if let Ok(out) = run_capture(cmd).await {
            if !out.is_empty() {
                return Ok(out);
            }
        }
    }
    Err("No password hashing tool found (mkpasswd, openssl)".into())
}

fn build_gpu_config(cfg: &InstallConfig) -> String {
    if cfg.gpu_choice == "1" {
        return String::new();
    }
    let mut lines = vec![
        "\n  # NVIDIA GPU".to_string(),
        "  cryonix.nvidia.enable = true;".to_string(),
    ];
    if cfg.gpu_choice == "3" {
        lines.push("  cryonix.nvidia.prime = {".into());
        lines.push("    enable = true;".into());
        lines.push(format!("    nvidiaBusId = \"{}\";", cfg.nvidia_bus_id));
        let key = if cfg.igpu_type == "amd" {
            "amdgpuBusId"
        } else {
            "intelBusId"
        };
        lines.push(format!("    {key} = \"{}\";", cfg.igpu_bus_id));
        lines.push("  };".into());
    }
    lines.join("\n")
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

    if cfg.mode == "whole-disk" {
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
            let data = fs::read_to_string(format!("{host_dir}/default.nix")).unwrap_or_default();
            let patched = data.replacen("imports = [", "imports = [\n    ./disko-fs.nix", 1);
            fs::write(format!("{host_dir}/default.nix"), patched).map_err(|e| e.to_string())?;
        }
    } else {
        let boot = "\n  # Boot — use existing EFI bootloader (dual-boot safe)\n  boot.loader = {\n    efi = {\n      canTouchEfiVariables = true;\n      efiSysMountPoint = \"/boot/efi\";\n    };\n    grub = {\n      enable = true;\n      device = \"nodev\";\n      efiSupport = true;\n      useOSProber = true;\n    };\n  };\n\n";
        write_host_config(&host_dir, cfg, &gpu_config, "    ./filesystems.nix", boot);
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
        if cfg.mode == "whole-disk" {
            return run(&format!(
                r#"nix run github:nix-community/disko -- --mode disko --flake ".#{}""#,
                cfg.hostname
            ))
            .await;
        }

        let np = &cfg.nixos_part;
        let ep = &cfg.efi_part;
        let swap = &cfg.swap_size;

        // Format
        if !has_filesystem(np).await || get_filesystem(np).await != "btrfs" {
            run(&format!("mkfs.btrfs -f {np}")).await?;
        }

        // Subvolumes
        if !is_mounted("/mnt").await {
            run(&format!("mount {np} /mnt")).await?;
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

        // Mount
        if !is_mounted("/mnt").await {
            run(&format!("mount -o subvol=@root,compress=zstd {np} /mnt")).await?;
        }
        for d in &["home", "nix", "var/log", "boot/efi"] {
            let _ = fs::create_dir_all(format!("/mnt/{d}"));
        }
        let mounts = [
            (format!("-o subvol=@home,compress=zstd {np}"), "/mnt/home"),
            (
                format!("-o subvol=@nix,compress=zstd,noatime {np}"),
                "/mnt/nix",
            ),
            (format!("-o subvol=@log,compress=zstd {np}"), "/mnt/var/log"),
            (ep.clone(), "/mnt/boot/efi"),
        ];
        for (opts, mp) in &mounts {
            if !is_mounted(mp).await {
                run(&format!("mount {opts} {mp}")).await?;
            }
        }

        // Swapfile
        if swap != "0" && !path_exists("/mnt/swap/swapfile") {
            let _ = fs::create_dir_all("/mnt/swap");
            if !is_mounted("/mnt/swap").await {
                let _ = run(&format!("mount -o subvol=@swap {np} /mnt/swap")).await;
            }
            run_silent("chattr +C /mnt/swap").await;
            let _ = run("truncate -s 0 /mnt/swap/swapfile").await;
            run_silent("chattr +C /mnt/swap/swapfile").await;
            let _ = run(&format!("fallocate -l {swap} /mnt/swap/swapfile")).await;
            let _ = run("chmod 600 /mnt/swap/swapfile").await;
            let _ = run("mkswap /mnt/swap/swapfile").await;
            let _ = run("swapon /mnt/swap/swapfile").await;
        }

        // UUIDs + filesystems.nix
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

        let _ = fs::write(format!("{}/filesystems.nix", host_dir), fs_nix);

        let hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config").await?;
        let _ = fs::write(format!("{}/hardware.nix", host_dir), format!("{hw}\n"));
        run_silent("git add .").await;
        Ok(())
    })
    .await
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
    let dest = format!("/mnt/home/{}/cryonix", cfg.username);
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
                r#"cd {dest} && git init && git add . && git commit -m "Initial Cryonix configuration for {hostname}""#
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
