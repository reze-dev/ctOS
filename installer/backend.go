package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// InstallConfig holds all user-collected configuration for installation.
type InstallConfig struct {
	Hostname    string
	Username    string
	HashedPW    string
	Mode        string // "whole-disk" or "partition-only"
	DiskDev     string
	NixosPart   string
	EFIPart     string
	SwapSize    string
	FSType      string
	GPUChoice   string // "1"=none, "2"=nvidia, "3"=prime
	NvidiaBusID string
	IGPUBusID   string
	IGPUType    string // "intel" or "amd"
}

// ProgressUpdate is sent from the backend to the TUI during installation.
type ProgressUpdate struct {
	Step    string
	Message string
	Done    bool
	Error   error
}

// HashPassword hashes a password using mkpasswd or openssl.
func HashPassword(pw string) (string, error) {
	for _, cmd := range []string{
		fmt.Sprintf("mkpasswd -m sha-512 '%s'", pw),
		fmt.Sprintf("echo '%s' | openssl passwd -6 -stdin", pw),
	} {
		out, err := RunCapture(cmd)
		if err == nil && out != "" {
			return out, nil
		}
	}
	return "", fmt.Errorf("no password hashing tool found (mkpasswd, openssl)")
}

// BuildGpuConfig returns Nix config lines for GPU setup.
func BuildGpuConfig(gpuChoice, nvBus, igpuType, igpuBus string) string {
	if gpuChoice == "1" {
		return ""
	}
	lines := []string{"\n  # NVIDIA GPU", "  snowflake.nvidia.enable = true;"}
	if gpuChoice == "3" {
		lines = append(lines, "  snowflake.nvidia.prime = {")
		lines = append(lines, "    enable = true;")
		lines = append(lines, fmt.Sprintf(`    nvidiaBusId = "%s";`, nvBus))
		busKey := "intelBusId"
		if igpuType == "amd" {
			busKey = "amdgpuBusId"
		}
		lines = append(lines, fmt.Sprintf(`    %s = "%s";`, busKey, igpuBus))
		lines = append(lines, "  };")
	}
	return strings.Join(lines, "\n")
}

// RunInstallation runs all installation steps and sends progress to the channel.
func RunInstallation(cfg InstallConfig, state *State, workDir string, progress chan<- ProgressUpdate) {
	defer close(progress)

	send := func(step, msg string) {
		progress <- ProgressUpdate{Step: step, Message: msg}
	}
	done := func(step, msg string) {
		progress <- ProgressUpdate{Step: step, Message: msg, Done: true}
	}
	fail := func(step string, err error) {
		progress <- ProgressUpdate{Step: step, Error: err}
	}

	// Step 1: Generate configuration
	send("generate_config", "Generating configuration...")
	if !state.ShouldSkip("generate_config") {
		if err := generateConfig(cfg, workDir); err != nil {
			fail("generate_config", err)
			return
		}
		state.SetStep("partition")
	}
	done("generate_config", "Configuration generated")

	// Step 2: Partition disk
	send("partition", "Partitioning disk...")
	if !state.ShouldSkip("partition") {
		if err := doPartition(cfg, workDir); err != nil {
			fail("partition", err)
			return
		}
		state.SetStep("install_nixos")
	}
	done("partition", "Disk partitioned")

	// Step 3: Install NixOS
	send("install_nixos", "Installing NixOS (this may take a while)...")
	if !state.ShouldSkip("install_nixos") {
		if err := doInstallNixOS(cfg); err != nil {
			fail("install_nixos", err)
			return
		}
		state.SetStep("copy_flake")
	}
	done("install_nixos", "NixOS installed")

	// Step 4: Copy flake
	send("copy_flake", "Copying flake to installed system...")
	if !state.ShouldSkip("copy_flake") {
		if err := doCopyFlake(cfg, workDir); err != nil {
			fail("copy_flake", err)
			return
		}
		state.SetStep("done")
	}
	done("copy_flake", "Flake copied")
}

// ── Config Generation ──────────────────────────────────────────────

func generateConfig(cfg InstallConfig, workDir string) error {
	hostDir := filepath.Join(workDir, "hosts", cfg.Hostname)
	os.MkdirAll(hostDir, 0755)

	gpuConfig := BuildGpuConfig(cfg.GPUChoice, cfg.NvidiaBusID, cfg.IGPUType, cfg.IGPUBusID)

	if cfg.Mode == "whole-disk" {
		hw, err := RunCapture("nixos-generate-config --show-hardware-config")
		if err != nil {
			return fmt.Errorf("hardware config: %w", err)
		}
		os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hw+"\n"), 0644)

		disko := fmt.Sprintf("# Auto-generated disko config for %s\n{\n  disko.devices.disk.main.device = \"/dev/%s\";\n", cfg.Hostname, cfg.DiskDev)
		if cfg.SwapSize == "0" {
			disko += "  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = \"0\";\n"
		} else if cfg.SwapSize != "8G" {
			disko += fmt.Sprintf("  disko.devices.disk.main.content.partitions.swap.size = \"%s\";\n", cfg.SwapSize)
		}
		disko += "}\n"
		os.WriteFile(filepath.Join(hostDir, "disko.nix"), []byte(disko), 0644)

		writeHostConfig(hostDir, cfg.Username, cfg.Hostname, cfg.HashedPW, gpuConfig, "    ./disko.nix", "")

		if cfg.FSType == "ext4" {
			ext4 := "{\n  disko.devices.disk.main.content.partitions.root.content = {\n    type = \"filesystem\";\n    format = \"ext4\";\n    mountpoint = \"/\";\n  };\n}\n"
			os.WriteFile(filepath.Join(hostDir, "disko-fs.nix"), []byte(ext4), 0644)
			data, _ := os.ReadFile(filepath.Join(hostDir, "default.nix"))
			patched := strings.Replace(string(data), "imports = [", "imports = [\n    ./disko-fs.nix", 1)
			os.WriteFile(filepath.Join(hostDir, "default.nix"), []byte(patched), 0644)
		}
	} else {
		bootConfig := "\n  # Boot — use existing EFI bootloader (dual-boot safe)\n  boot.loader = {\n    efi = {\n      canTouchEfiVariables = true;\n      efiSysMountPoint = \"/boot/efi\";\n    };\n    grub = {\n      enable = true;\n      device = \"nodev\";\n      efiSupport = true;\n      useOSProber = true;\n    };\n  };\n\n"
		writeHostConfig(hostDir, cfg.Username, cfg.Hostname, cfg.HashedPW, gpuConfig, "    ./filesystems.nix", bootConfig)
	}

	RunSilent("git add .")
	return nil
}

func writeHostConfig(hostDir, user, hostname, hashedPw, gpuConfig, imports, bootConfig string) {
	content := fmt.Sprintf(`{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
%s
  ];

  home-manager.users.%s = {
    imports = [ ../../home ];
    home.username = lib.mkForce "%s";
    home.homeDirectory = lib.mkForce "/home/%s";
  };

  users.users.%s = {
    isNormalUser = true;
    description = "%s";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "%s";
  };
%s

  networking.hostName = "%s";
%s  system.stateVersion = "26.05";
}
`, imports, user, user, user, user, user, hashedPw, gpuConfig, hostname, bootConfig)
	os.WriteFile(filepath.Join(hostDir, "default.nix"), []byte(content), 0644)
}

// ── Partitioning ───────────────────────────────────────────────────

func doPartition(cfg InstallConfig, workDir string) error {
	return Retry("partition", 3, 5*time.Second, func() error {
		hostDir := filepath.Join(workDir, "hosts", cfg.Hostname)

		if cfg.Mode == "whole-disk" {
			return Run(fmt.Sprintf(`nix run github:nix-community/disko -- --mode disko --flake ".#%s"`, cfg.Hostname))
		}

		nixosPart := cfg.NixosPart
		efiPart := cfg.EFIPart
		swap := cfg.SwapSize

		// Format
		if HasFilesystem(nixosPart) && GetFilesystem(nixosPart) == "btrfs" {
			// already formatted
		} else {
			if err := Run(fmt.Sprintf("mkfs.btrfs -f %s", nixosPart)); err != nil {
				return err
			}
		}

		// Subvolumes
		if !IsMounted("/mnt") {
			if err := Run(fmt.Sprintf("mount %s /mnt", nixosPart)); err != nil {
				return err
			}
		}

		subvols := []string{"@root", "@home", "@nix", "@log"}
		if swap != "0" {
			subvols = append(subvols, "@swap")
		}
		for _, sv := range subvols {
			if !SubvolumeExists("/mnt", sv) {
				if err := Run(fmt.Sprintf("btrfs subvolume create /mnt/%s", sv)); err != nil {
					return err
				}
			}
		}
		Run("umount /mnt")

		// Mount
		if !IsMounted("/mnt") {
			if err := Run(fmt.Sprintf("mount -o subvol=@root,compress=zstd %s /mnt", nixosPart)); err != nil {
				return err
			}
		}
		for _, d := range []string{"home", "nix", "var/log", "boot/efi"} {
			os.MkdirAll(fmt.Sprintf("/mnt/%s", d), 0755)
		}

		mounts := []struct{ opts, mp string }{
			{fmt.Sprintf("-o subvol=@home,compress=zstd %s", nixosPart), "/mnt/home"},
			{fmt.Sprintf("-o subvol=@nix,compress=zstd,noatime %s", nixosPart), "/mnt/nix"},
			{fmt.Sprintf("-o subvol=@log,compress=zstd %s", nixosPart), "/mnt/var/log"},
			{efiPart, "/mnt/boot/efi"},
		}
		for _, m := range mounts {
			if !IsMounted(m.mp) {
				if err := Run(fmt.Sprintf("mount %s %s", m.opts, m.mp)); err != nil {
					return err
				}
			}
		}

		// Swapfile
		if swap != "0" && !PathExists("/mnt/swap/swapfile") {
			os.MkdirAll("/mnt/swap", 0755)
			if !IsMounted("/mnt/swap") {
				Run(fmt.Sprintf("mount -o subvol=@swap %s /mnt/swap", nixosPart))
			}
			RunSilent("chattr +C /mnt/swap")
			Run("truncate -s 0 /mnt/swap/swapfile")
			RunSilent("chattr +C /mnt/swap/swapfile")
			Run(fmt.Sprintf("fallocate -l %s /mnt/swap/swapfile", swap))
			Run("chmod 600 /mnt/swap/swapfile")
			Run("mkswap /mnt/swap/swapfile")
			Run("swapon /mnt/swap/swapfile")
		}

		// UUIDs + filesystems.nix
		nixosUUID, _ := RunCapture(fmt.Sprintf("blkid -s UUID -o value %s", nixosPart))
		efiUUID, _ := RunCapture(fmt.Sprintf("blkid -s UUID -o value %s", efiPart))

		swapConfig := ""
		if swap != "0" {
			swapConfig = fmt.Sprintf(`
  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];`, nixosUUID)
		}

		fsNix := fmt.Sprintf(`# Auto-generated filesystem configuration for %s
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/%s";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
%s
}
`, cfg.Hostname, nixosUUID, nixosUUID, nixosUUID, nixosUUID, efiUUID, swapConfig)
		os.WriteFile(filepath.Join(hostDir, "filesystems.nix"), []byte(fsNix), 0644)

		hw, err := RunCapture("nixos-generate-config --root /mnt --show-hardware-config")
		if err != nil {
			return err
		}
		os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hw+"\n"), 0644)
		RunSilent("git add .")
		return nil
	})
}

// ── NixOS Install ──────────────────────────────────────────────────

func doInstallNixOS(cfg InstallConfig) error {
	return Retry("nixos-install", 3, 10*time.Second, func() error {
		return Run(fmt.Sprintf(`nixos-install --flake ".#%s" --no-root-password`, cfg.Hostname))
	})
}

// ── Copy Flake ─────────────────────────────────────────────────────

func doCopyFlake(cfg InstallConfig, workDir string) error {
	return Retry("copy-flake", 3, 5*time.Second, func() error {
		dest := fmt.Sprintf("/mnt/home/%s/snowflake", cfg.Username)
		os.RemoveAll(dest)

		if err := Run(fmt.Sprintf("cp -a %s/. %s/", workDir, dest)); err != nil {
			return err
		}

		os.RemoveAll(filepath.Join(dest, ".git"))
		if err := Run(fmt.Sprintf(`cd %s && git init && git add . && git commit -m "Initial Snowflake configuration for %s"`, dest, cfg.Hostname)); err != nil {
			return err
		}

		// Fix ownership
		passwdData, err := os.ReadFile("/mnt/etc/passwd")
		if err == nil {
			for _, line := range strings.Split(string(passwdData), "\n") {
				fields := strings.Split(line, ":")
				if len(fields) > 3 && fields[0] == cfg.Username {
					uid, gid := fields[2], fields[3]
					Run(fmt.Sprintf("chown -R %s:%s %s", uid, gid, dest))
					return nil
				}
			}
		}
		return nil
	})
}
