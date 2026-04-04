package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ── Gathering Steps ─────────────────────────────────────────────

func GatherHost(state *State) {
	Step("1/8", "Host Configuration")
	hostname := PromptRequired("Enter Target Hostname (e.g., my-laptop): ", "Hostname cannot be empty")
	state.Set("hostname", hostname)
	state.SetStep("gather_user")
}

func GatherUser(state *State) {
	Step("2/8", "User Configuration")
	username := PromptRequired("Enter Username: ", "Username cannot be empty")

	fmt.Println("\nEnter Password (will be hashed):")
	pw := PromptPassword("  Password: ")
	pw2 := PromptPassword("  Confirm:  ")
	if pw != pw2 {
		Die("Passwords do not match!")
	}
	if pw == "" {
		Die("Password cannot be empty")
	}

	Msg("Hashing password...")
	hashed, err := HashPassword(pw)
	if err != nil {
		Die(fmt.Sprintf("Failed to hash password: %v", err))
	}
	state.Set("username", username)
	state.Set("hashed_password", hashed)
	state.SetStep("gather_mode")
}

func GatherMode(state *State) {
	Step("3/8", "Installation Mode")
	fmt.Println("Select installation mode:")
	fmt.Printf("  %s1) Whole disk%s — fresh install, wipes entire disk\n", Bold, Reset)
	fmt.Printf("  %s2) Partition only%s — dual-boot, installs to a specific partition\n", Bold, Reset)
	choice := PromptDefault("Choice [1]: ", "1")
	mode := "whole-disk"
	if choice == "2" {
		mode = "partition-only"
	}
	state.Set("install_mode", mode)
	state.SetStep("gather_disk")
}

func GatherDisk(state *State) {
	Step("4/8", "Disk & Partition Selection")
	mode := state.Get("install_mode")

	Warn("Available Disks:")
	RunSilent("lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk")
	fmt.Println()

	diskDev := PromptRequired("Enter Target Disk Device (e.g., nvme0n1 or sda): ", "Disk device cannot be empty")
	if !PathExists(fmt.Sprintf("/dev/%s", diskDev)) {
		Die(fmt.Sprintf("Device /dev/%s does not exist", diskDev))
	}
	state.Set("disk_dev", diskDev)

	if mode == "whole-disk" {
		Err(fmt.Sprintf("WARNING: All data on /dev/%s will be DESTROYED!", diskDev))
		ConfirmYes("Type 'yes' to confirm:")
	} else {
		// Show partitions
		fmt.Printf("\n%sPartitions on /dev/%s:%s\n", Yellow, diskDev, Reset)
		RunSilent(fmt.Sprintf("lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS /dev/%s", diskDev))

		// Free space
		fmt.Printf("\n%sFree/unallocated space:%s\n", Yellow, Reset)
		RunSilent(fmt.Sprintf(`parted -s /dev/%s unit GiB print free 2>/dev/null | grep -i "free space" || echo "  (none)"`, diskDev))

		fmt.Println("\nWhat would you like to do?")
		fmt.Println("  1) Use an existing partition")
		fmt.Println("  2) Create a new partition from unallocated space")
		action := PromptDefault("Choice [1]: ", "1")

		var nixosPart string
		if action == "2" {
			start := Prompt("Enter start position (e.g., 100GiB): ")
			end := Prompt("Enter end position (e.g., 200GiB or 100%): ")
			if start == "" || end == "" {
				Die("Start and end positions are required")
			}
			Warn(fmt.Sprintf("Creating partition from %s to %s...", start, end))
			before, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | wc -l", diskDev))
			if err := Run(fmt.Sprintf(`parted -s /dev/%s mkpart primary "%s" "%s"`, diskDev, start, end)); err != nil {
				Die(fmt.Sprintf("Failed to create partition: %v", err))
			}
			time.Sleep(2 * time.Second)
			RunSilent(fmt.Sprintf("partprobe /dev/%s", diskDev))
			time.Sleep(1 * time.Second)
			after, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | wc -l", diskDev))
			if after <= before {
				Die("Failed to detect new partition.")
			}
			partName, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME /dev/%s | tail -1", diskDev))
			nixosPart = fmt.Sprintf("/dev/%s", partName)
			Msg(fmt.Sprintf("Created: %s", nixosPart))
		} else {
			partName := Prompt("Enter NixOS partition device (e.g., nvme0n1p5): ")
			nixosPart = fmt.Sprintf("/dev/%s", partName)
			if !PathExists(nixosPart) {
				Die(fmt.Sprintf("Partition %s does not exist", nixosPart))
			}
		}
		state.Set("nixos_partition", nixosPart)
		Err(fmt.Sprintf("WARNING: All data on %s will be DESTROYED!", nixosPart))
		ConfirmYes("Type 'yes' to confirm:")

		// Detect EFI
		Warn("\nDetecting EFI System Partition...")
		efiPart := ""
		out, _ := RunCapture(fmt.Sprintf("lsblk -n -l -o NAME,FSTYPE,PARTTYPE /dev/%s", diskDev))
		for _, line := range strings.Split(out, "\n") {
			fields := strings.Fields(line)
			if len(fields) >= 3 && fields[1] == "vfat" && strings.Contains(strings.ToLower(fields[2]), "c12a7328") {
				efiPart = fmt.Sprintf("/dev/%s", fields[0])
				break
			}
		}
		if efiPart == "" {
			Warn("Could not auto-detect ESP.")
			RunSilent(fmt.Sprintf("lsblk -n -o NAME,SIZE,FSTYPE,LABEL /dev/%s", diskDev))
			efiName := Prompt("Enter EFI partition device (e.g., nvme0n1p1): ")
			efiPart = fmt.Sprintf("/dev/%s", efiName)
			if !PathExists(efiPart) {
				Die(fmt.Sprintf("EFI partition %s does not exist", efiPart))
			}
		} else {
			Msg(fmt.Sprintf("Found ESP: %s", efiPart))
		}
		state.Set("efi_partition", efiPart)
	}
	state.SetStep("gather_swap_fs_gpu")
}

func GatherSwapFsGpu(state *State) {
	mode := state.Get("install_mode")

	// Swap
	Step("5/8", "Swap Configuration")
	if mode == "partition-only" {
		fmt.Println("Enter swap size (btrfs swapfile). Examples: 8G, 16G, 0 to disable")
	} else {
		fmt.Println("Enter swap partition size. Examples: 8G, 16G, 0 to disable")
	}
	swap := PromptDefault("Swap size [8G]: ", "8G")
	state.Set("swap_size", swap)

	// Filesystem
	Step("6/8", "Filesystem Configuration")
	fs := "btrfs"
	if mode == "partition-only" {
		fmt.Printf("Filesystem: %sbtrfs%s (required for dual-boot)\n", Bold, Reset)
	} else {
		fmt.Println("Select root filesystem:")
		fmt.Println("  1) btrfs (recommended)")
		fmt.Println("  2) ext4")
		fc := PromptDefault("Choice [1]: ", "1")
		if fc == "2" {
			fs = "ext4"
		}
	}
	state.Set("fs_type", fs)

	// GPU
	Step("7/8", "GPU Configuration")
	fmt.Println("Select GPU type:")
	fmt.Println("  1) None / Intel / AMD")
	fmt.Println("  2) NVIDIA (proprietary)")
	fmt.Println("  3) NVIDIA + AMD/Intel hybrid (Prime)")
	gpu := PromptDefault("Choice [1]: ", "1")
	state.Set("gpu_choice", gpu)

	if gpu == "3" {
		fmt.Println()
		Warn("To find PCI Bus IDs, run: lspci | grep -E 'VGA|3D'")
		RunSilent("lspci | grep -E 'VGA|3D'")
		nvBus := Prompt("NVIDIA Bus ID (e.g., PCI:1:0:0): ")
		fmt.Println("iGPU type: 1) Intel  2) AMD")
		igpuChoice := PromptDefault("Choice [1]: ", "1")
		igpuBus := Prompt("iGPU Bus ID (e.g., PCI:0:2:0): ")
		igpuType := "intel"
		if igpuChoice == "2" {
			igpuType = "amd"
		}
		state.Set("nvidia_bus_id", nvBus)
		state.Set("igpu_bus_id", igpuBus)
		state.Set("igpu_type", igpuType)
	}
	state.SetStep("confirm")
}

func ShowSummaryAndConfirm(state *State) {
	mode := state.Get("install_mode")
	gpu := state.Get("gpu_choice")

	fmt.Printf("\n%sConfiguration Summary:%s\n", Cyan, Reset)
	fmt.Printf("  Hostname:     %s\n", state.Get("hostname"))
	fmt.Printf("  Username:     %s\n", state.Get("username"))
	fmt.Printf("  Mode:         %s\n", mode)
	fmt.Printf("  Disk:         /dev/%s\n", state.Get("disk_dev"))
	if mode == "partition-only" {
		fmt.Printf("  NixOS Part:   %s\n", state.Get("nixos_partition"))
		fmt.Printf("  EFI Part:     %s\n", state.Get("efi_partition"))
	}
	fmt.Printf("  Swap:         %s\n", state.Get("swap_size"))
	fmt.Printf("  Filesystem:   %s\n", state.Get("fs_type"))
	if gpu != "1" {
		g := "NVIDIA"
		if gpu == "3" {
			g += fmt.Sprintf(" Prime (%s + %s:%s)", state.Get("nvidia_bus_id"), state.Get("igpu_type"), state.Get("igpu_bus_id"))
		}
		fmt.Printf("  GPU:          %s\n", g)
	} else {
		fmt.Println("  GPU:          Default (no NVIDIA)")
	}

	fmt.Println()
	ans := PromptDefault("Proceed with installation? [Y/n]: ", "Y")
	if strings.ToLower(ans) != "y" {
		Die("Aborted.")
	}
	state.SetStep("generate_config")
}

// ── Config Generation ───────────────────────────────────────────

func HashPassword(pw string) (string, error) {
	// Try mkpasswd first, then openssl
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

func GenerateConfig(state *State, workDir string) {
	Step("8/8", "Setting up configuration...")
	hostname := state.Get("hostname")
	hostDir := filepath.Join(workDir, "hosts", hostname)
	os.MkdirAll(hostDir, 0755)

	mode := state.Get("install_mode")
	gpuConfig := BuildGpuConfig(state.Get("gpu_choice"), state.Get("nvidia_bus_id"), state.Get("igpu_type"), state.Get("igpu_bus_id"))

	if mode == "whole-disk" {
		Msg("Generating hardware configuration...")
		hw, err := RunCapture("nixos-generate-config --show-hardware-config")
		if err != nil {
			Die(fmt.Sprintf("Failed to generate hardware config: %v", err))
		}
		os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hw+"\n"), 0644)

		Msg("Creating disko configuration...")
		diskDev := state.Get("disk_dev")
		swap := state.Get("swap_size")
		disko := fmt.Sprintf("# Auto-generated disko config for %s\n{\n  disko.devices.disk.main.device = \"/dev/%s\";\n", hostname, diskDev)
		if swap == "0" {
			disko += "  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = \"0\";\n"
		} else if swap != "8G" {
			disko += fmt.Sprintf("  disko.devices.disk.main.content.partitions.swap.size = \"%s\";\n", swap)
		}
		disko += "}\n"
		os.WriteFile(filepath.Join(hostDir, "disko.nix"), []byte(disko), 0644)

		writeHostConfig(hostDir, state.Get("username"), hostname, state.Get("hashed_password"), gpuConfig, "    ./disko.nix", "")

		if state.Get("fs_type") == "ext4" {
			Msg("Configuring ext4 override...")
			ext4 := `{
  disko.devices.disk.main.content.partitions.root.content = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };
}
`
			os.WriteFile(filepath.Join(hostDir, "disko-fs.nix"), []byte(ext4), 0644)
			cfg, _ := os.ReadFile(filepath.Join(hostDir, "default.nix"))
			patched := strings.Replace(string(cfg), "imports = [", "imports = [\n    ./disko-fs.nix", 1)
			os.WriteFile(filepath.Join(hostDir, "default.nix"), []byte(patched), 0644)
		}
	} else {
		bootConfig := `
  # Boot — use existing EFI bootloader (dual-boot safe)
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
    };
  };

`
		writeHostConfig(hostDir, state.Get("username"), hostname, state.Get("hashed_password"), gpuConfig, "    ./filesystems.nix", bootConfig)
	}

	Msg("Staging files...")
	RunSilent("git add .")
	state.SetStep("partition")
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

// ── Partition ───────────────────────────────────────────────────

func DoPartition(state *State, workDir string) {
	Retry("partition", 3, 5*time.Second, func() error {
		mode := state.Get("install_mode")
		hostname := state.Get("hostname")
		hostDir := filepath.Join(workDir, "hosts", hostname)

		if mode == "whole-disk" {
			Msg("Partitioning with Disko...")
			return Run(fmt.Sprintf(`nix run github:nix-community/disko -- --mode disko --flake ".#%s"`, hostname))
		}

		// Partition-only mode
		nixosPart := state.Get("nixos_partition")
		efiPart := state.Get("efi_partition")
		swap := state.Get("swap_size")

		// Format — idempotent
		if HasFilesystem(nixosPart) && GetFilesystem(nixosPart) == "btrfs" {
			Msg(fmt.Sprintf("%s already btrfs, skipping format.", nixosPart))
		} else {
			Msg(fmt.Sprintf("Formatting %s as btrfs...", nixosPart))
			if err := Run(fmt.Sprintf("mkfs.btrfs -f %s", nixosPart)); err != nil {
				return err
			}
		}

		// Subvolumes — idempotent
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
			if SubvolumeExists("/mnt", sv) {
				Msg(fmt.Sprintf("  Subvolume %s exists, skipping.", sv))
			} else {
				Msg(fmt.Sprintf("  Creating %s...", sv))
				if err := Run(fmt.Sprintf("btrfs subvolume create /mnt/%s", sv)); err != nil {
					return err
				}
			}
		}
		Run("umount /mnt")

		// Mount — idempotent
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
			} else {
				Msg(fmt.Sprintf("  %s already mounted.", m.mp))
			}
		}

		// Swapfile — idempotent
		if swap != "0" {
			if PathExists("/mnt/swap/swapfile") {
				Msg("  Swapfile exists, skipping.")
			} else {
				Msg(fmt.Sprintf("Creating %s swapfile...", swap))
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
		}

		// UUIDs + filesystems.nix
		nixosUUID, _ := RunCapture(fmt.Sprintf("blkid -s UUID -o value %s", nixosPart))
		efiUUID, _ := RunCapture(fmt.Sprintf("blkid -s UUID -o value %s", efiPart))
		Msg(fmt.Sprintf("NixOS UUID: %s", nixosUUID))
		Msg(fmt.Sprintf("EFI UUID:   %s", efiUUID))

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
`, hostname, nixosUUID, nixosUUID, nixosUUID, nixosUUID, efiUUID, swapConfig)
		os.WriteFile(filepath.Join(hostDir, "filesystems.nix"), []byte(fsNix), 0644)

		Msg("Generating hardware configuration...")
		hw, err := RunCapture("nixos-generate-config --root /mnt --show-hardware-config")
		if err != nil {
			return err
		}
		os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hw+"\n"), 0644)
		RunSilent("git add .")
		return nil
	})
	state.SetStep("install_nixos")
}

// ── NixOS Install ───────────────────────────────────────────────

func DoInstallNixOS(state *State) {
	hostname := state.Get("hostname")
	Retry("nixos-install", 3, 10*time.Second, func() error {
		Msg(fmt.Sprintf("\nInstalling NixOS (host: %s)...", hostname))
		return Run(fmt.Sprintf(`nixos-install --flake ".#%s" --no-root-password`, hostname))
	})
	state.SetStep("copy_flake")
}

// ── Copy Flake ──────────────────────────────────────────────────

func DoCopyFlake(state *State, workDir string) {
	username := state.Get("username")
	hostname := state.Get("hostname")

	Retry("copy-flake", 3, 5*time.Second, func() error {
		Msg("\nCopying Snowflake flake to installed system...")
		dest := fmt.Sprintf("/mnt/home/%s/snowflake", username)
		os.RemoveAll(dest)

		if err := Run(fmt.Sprintf("cp -a %s/. %s/", workDir, dest)); err != nil {
			return err
		}

		os.RemoveAll(filepath.Join(dest, ".git"))
		if err := Run(fmt.Sprintf(`cd %s && git init && git add . && git commit -m "Initial Snowflake configuration for %s"`, dest, hostname)); err != nil {
			return err
		}

		// Fix ownership
		passwdData, err := os.ReadFile("/mnt/etc/passwd")
		if err == nil {
			for _, line := range strings.Split(string(passwdData), "\n") {
				fields := strings.Split(line, ":")
				if len(fields) > 3 && fields[0] == username {
					uid, gid := fields[2], fields[3]
					Run(fmt.Sprintf("chown -R %s:%s %s", uid, gid, dest))
					Msg(fmt.Sprintf("Flake saved to /home/%s/snowflake (UID %s)", username, uid))
					return nil
				}
			}
		}
		Warn(fmt.Sprintf("Could not fix ownership. After boot, run:\n  sudo chown -R %s:%s ~/snowflake", username, username))
		return nil
	})
	state.SetStep("done")
}
