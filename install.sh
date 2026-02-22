#!/usr/bin/env bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ──────────────────────────────────────────────
# Helper: Copy flake to installed system
# ──────────────────────────────────────────────
copy_flake_to_target() {
    echo -e "\n${GREEN}Copying Snowflake flake to installed system...${NC}"
    local FLAKE_DEST="/mnt/home/$USERNAME/snowflake"
    mkdir -p "$FLAKE_DEST"
    cp -a "$WORK_DIR/." "$FLAKE_DEST/"

    # Remove old .git internals and initialize a fresh repo
    if [ -d "$FLAKE_DEST/.git" ]; then
        rm -rf "$FLAKE_DEST/.git"
    fi
    pushd "$FLAKE_DEST" > /dev/null
    git init
    git add .
    git commit -m "Initial Snowflake configuration for $HOSTNAME"
    popd > /dev/null

    # Fix ownership — look up UID/GID from the installed system's /etc/passwd
    local INSTALLED_UID INSTALLED_GID
    INSTALLED_UID=$(grep "^${USERNAME}:" /mnt/etc/passwd | cut -d: -f3)
    INSTALLED_GID=$(grep "^${USERNAME}:" /mnt/etc/passwd | cut -d: -f4)
    if [ -n "$INSTALLED_UID" ] && [ -n "$INSTALLED_GID" ]; then
        chown -R "$INSTALLED_UID:$INSTALLED_GID" "$FLAKE_DEST"
        echo -e "${GREEN}Flake saved to /home/$USERNAME/snowflake (owned by UID $INSTALLED_UID)${NC}"
    else
        echo -e "${YELLOW}Warning: Could not determine UID/GID for $USERNAME.${NC}"
        echo -e "${YELLOW}After first boot, run: sudo chown -R $USERNAME:$USERNAME ~/snowflake${NC}"
    fi
}

# Determine if running from remote (cloned to temp) or local
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR"

# If SNOWFLAKE_REMOTE is set, we're running from remote install
if [ -n "$SNOWFLAKE_REMOTE" ]; then
    WORK_DIR="$SNOWFLAKE_REMOTE"
fi

cd "$WORK_DIR"

echo -e "${CYAN}"
echo "  ❄️  Snowflake NixOS Installer  ❄️"
echo "  ================================="
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# ──────────────────────────────────────────────
# 1. Host Configuration
# ──────────────────────────────────────────────
echo -e "${GREEN}[1/8] Host Configuration${NC}"
read -p "Enter Target Hostname (e.g., my-laptop): " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Hostname cannot be empty${NC}"
    exit 1
fi

# ──────────────────────────────────────────────
# 2. User Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[2/8] User Configuration${NC}"
read -p "Enter Username: " USERNAME
if [ -z "$USERNAME" ]; then
    echo -e "${RED}Username cannot be empty${NC}"
    exit 1
fi

# 2b. Password
echo -e "\nEnter Password for user $USERNAME (will be hashed):"
read -s PASSWORD
echo -e "\nConfirm Password:"
read -s PASSWORD_CONFIRM

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Passwords do not match!${NC}"
    exit 1
fi

if [ -z "$PASSWORD" ]; then
    echo -e "${RED}Password cannot be empty${NC}"
    exit 1
fi

echo -e "${GREEN}Hashing password...${NC}"
if command -v mkpasswd &> /dev/null; then
  HASHED_PASSWORD=$(mkpasswd -m sha-512 "$PASSWORD")
elif command -v openssl &> /dev/null; then
  HASHED_PASSWORD=$(openssl passwd -6 "$PASSWORD")
elif command -v python3 &> /dev/null; then
  HASHED_PASSWORD=$(python3 -c "import crypt; print(crypt.crypt('$PASSWORD', crypt.mksalt(crypt.METHOD_SHA512)))")
else 
  echo -e "${RED}No tool found to hash password (mkpasswd, openssl, python3).${NC}"
  echo "Please install one of them."
  exit 1
fi

# ──────────────────────────────────────────────
# 3. Installation Mode
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[3/8] Installation Mode${NC}"
echo "Select installation mode:"
echo -e "  ${BOLD}1) Whole disk${NC} — fresh install, wipes entire disk (creates GPT + ESP + swap + root)"
echo -e "  ${BOLD}2) Partition only${NC} — dual-boot, installs to a specific partition (reuses existing ESP)"
read -p "Choice [1]: " INSTALL_MODE
INSTALL_MODE=${INSTALL_MODE:-1}

case "$INSTALL_MODE" in
    1) INSTALL_MODE="whole-disk" ;;
    2) INSTALL_MODE="partition-only" ;;
    *)
        echo -e "${RED}Invalid choice, defaulting to whole-disk${NC}"
        INSTALL_MODE="whole-disk"
        ;;
esac

# ──────────────────────────────────────────────
# 4. Disk / Partition Selection
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[4/8] Disk & Partition Selection${NC}"

if [ "$INSTALL_MODE" = "whole-disk" ]; then
    # ─── Whole Disk Mode (original behavior) ───
    echo -e "${YELLOW}Available Disks:${NC}"
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk || true
    echo ""
    read -p "Enter Target Disk Device (e.g., nvme0n1 or sda): " DISK_DEV

    if [ ! -b "/dev/$DISK_DEV" ]; then
        echo -e "${RED}Device /dev/$DISK_DEV does not exist${NC}"
        exit 1
    fi

    echo -e "${RED}WARNING: All data on /dev/$DISK_DEV will be DESTROYED!${NC}"
    read -p "Type 'yes' to confirm: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi

else
    # ─── Partition Only Mode (dual-boot) ───
    echo -e "${YELLOW}Available Disks:${NC}"
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk || true
    echo ""
    read -p "Enter the disk to show partitions for (e.g., nvme0n1 or sda): " DISK_DEV

    if [ ! -b "/dev/$DISK_DEV" ]; then
        echo -e "${RED}Device /dev/$DISK_DEV does not exist${NC}"
        exit 1
    fi

    echo -e "\n${YELLOW}Partitions on /dev/$DISK_DEV:${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "/dev/$DISK_DEV" 2>/dev/null || true
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"

    # Show free/unallocated space using parted
    echo -e "\n${YELLOW}Free/unallocated space on /dev/$DISK_DEV:${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    if command -v parted &> /dev/null; then
        parted -s "/dev/$DISK_DEV" unit GiB print free 2>/dev/null | grep -i "free space" || echo "  (no unallocated space found)"
    else
        echo -e "  ${YELLOW}(parted not found — cannot detect free space)${NC}"
    fi
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"

    echo ""
    echo "What would you like to do?"
    echo "  1) Use an existing partition"
    echo "  2) Create a new partition from unallocated space"
    read -p "Choice [1]: " PART_ACTION
    PART_ACTION=${PART_ACTION:-1}

    if [ "$PART_ACTION" = "2" ]; then
        # ─── Create new partition from free space ───
        if ! command -v parted &> /dev/null; then
            echo -e "${RED}parted is required to create partitions but is not installed.${NC}"
            exit 1
        fi

        echo -e "\n${YELLOW}Creating a new Linux partition on /dev/$DISK_DEV...${NC}"
        read -p "Enter start position (e.g., 100GiB): " PART_START
        read -p "Enter end position or size (e.g., 200GiB or 100%): " PART_END

        if [ -z "$PART_START" ] || [ -z "$PART_END" ]; then
            echo -e "${RED}Start and end positions are required${NC}"
            exit 1
        fi

        echo -e "${YELLOW}Creating partition from $PART_START to $PART_END on /dev/$DISK_DEV...${NC}"
        # Record partition count before creation
        PART_COUNT_BEFORE=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | wc -l)

        parted -s "/dev/$DISK_DEV" mkpart primary "$PART_START" "$PART_END"

        # Wait for the kernel to pick up the new partition
        sleep 2
        partprobe "/dev/$DISK_DEV" 2>/dev/null || true
        sleep 1

        # Detect the newly created partition
        PART_COUNT_AFTER=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | wc -l)
        if [ "$PART_COUNT_AFTER" -le "$PART_COUNT_BEFORE" ]; then
            echo -e "${RED}Failed to detect new partition. Check parted output above.${NC}"
            exit 1
        fi

        # The new partition is the last one listed
        NIXOS_PART_NAME=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | tail -1)
        NIXOS_PARTITION="/dev/$NIXOS_PART_NAME"
        echo -e "${GREEN}Created new partition: $NIXOS_PARTITION${NC}"
    else
        # ─── Use existing partition ───
        read -p "Enter the partition device for NixOS (e.g., nvme0n1p5 or sda3): " NIXOS_PART_NAME
        NIXOS_PARTITION="/dev/$NIXOS_PART_NAME"

        if [ ! -b "$NIXOS_PARTITION" ]; then
            echo -e "${RED}Partition $NIXOS_PARTITION does not exist${NC}"
            exit 1
        fi
    fi

    echo -e "${RED}WARNING: All data on $NIXOS_PARTITION will be DESTROYED!${NC}"
    read -p "Type 'yes' to confirm: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi

    # ─── Detect existing EFI System Partition ───
    echo -e "\n${YELLOW}Detecting EFI System Partition on /dev/$DISK_DEV...${NC}"
    # Find vfat partition with parttype GUID for EFI System Partition
    EFI_PARTITION=""
    while IFS= read -r line; do
        part_name=$(echo "$line" | awk '{print $1}')
        part_fstype=$(echo "$line" | awk '{print $2}')
        part_parttype=$(echo "$line" | awk '{print $3}')
        # EFI System Partition GUID: c12a7328-f81f-11d2-ba4b-00a0c93ec93b
        if [ "$part_fstype" = "vfat" ] && [ "$part_parttype" = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]; then
            EFI_PARTITION="/dev/$part_name"
            break
        fi
    done < <(lsblk -n -l -o NAME,FSTYPE,PARTTYPE "/dev/$DISK_DEV" 2>/dev/null)

    if [ -z "$EFI_PARTITION" ]; then
        echo -e "${YELLOW}Could not auto-detect ESP. Listing partitions:${NC}"
        lsblk -n -o NAME,SIZE,FSTYPE,LABEL "/dev/$DISK_DEV" 2>/dev/null || true
        read -p "Enter your EFI System Partition device (e.g., nvme0n1p1 or sda1): " EFI_PART_NAME
        EFI_PARTITION="/dev/$EFI_PART_NAME"

        if [ ! -b "$EFI_PARTITION" ]; then
            echo -e "${RED}EFI partition $EFI_PARTITION does not exist${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}Found ESP: $EFI_PARTITION${NC}"
    fi
fi

# ──────────────────────────────────────────────
# 5. Swap Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[5/8] Swap Configuration${NC}"
if [ "$INSTALL_MODE" = "partition-only" ]; then
    echo "Enter swap size (will be created as a swapfile inside btrfs)"
    echo "Examples: 8G, 16G, 0 to disable"
else
    echo "Enter swap partition size (examples: 8G, 16G, 0 to disable)"
fi
read -p "Swap size [8G]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-8G}

if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[GMgm]?$ ]] && [ "$SWAP_SIZE" != "0" ]; then
    echo -e "${RED}Invalid swap size format. Use format like 8G, 16G, or 0${NC}"
    exit 1
fi

# ──────────────────────────────────────────────
# 6. Filesystem Type
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[6/8] Filesystem Configuration${NC}"
if [ "$INSTALL_MODE" = "partition-only" ]; then
    echo -e "Filesystem type: ${BOLD}btrfs${NC} (required for partition-only dual-boot mode)"
    FS_TYPE="btrfs"
else
    echo "Select root filesystem type:"
    echo "  1) btrfs (recommended - supports snapshots, subvolumes)"
    echo "  2) ext4 (simple, traditional)"
    read -p "Choice [1]: " FS_CHOICE
    FS_CHOICE=${FS_CHOICE:-1}

    case "$FS_CHOICE" in
        1|btrfs) FS_TYPE="btrfs" ;;
        2|ext4) FS_TYPE="ext4" ;;
        *) 
            echo -e "${RED}Invalid choice, defaulting to btrfs${NC}"
            FS_TYPE="btrfs"
            ;;
    esac
fi

# ──────────────────────────────────────────────
# 7. GPU Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[7/8] GPU Configuration${NC}"
echo "Select your GPU type:"
echo "  1) None / Intel / AMD (no extra driver needed)"
echo "  2) NVIDIA (proprietary driver)"
echo "  3) NVIDIA + AMD/Intel hybrid (Prime)"
read -p "Choice [1]: " GPU_CHOICE
GPU_CHOICE=${GPU_CHOICE:-1}

NVIDIA_ENABLE="false"
NVIDIA_PRIME_ENABLE="false"
NVIDIA_BUS_ID=""
IGPU_BUS_ID=""
IGPU_TYPE=""

case "$GPU_CHOICE" in
    2)
        NVIDIA_ENABLE="true"
        ;;
    3)
        NVIDIA_ENABLE="true"
        NVIDIA_PRIME_ENABLE="true"
        echo ""
        echo -e "${YELLOW}To find PCI Bus IDs, run: lspci | grep -E 'VGA|3D'${NC}"
        if command -v lspci &> /dev/null; then
            echo -e "${CYAN}Detected GPUs:${NC}"
            lspci | grep -E 'VGA|3D' || true
        fi
        echo ""
        read -p "NVIDIA GPU Bus ID (e.g., PCI:1:0:0): " NVIDIA_BUS_ID
        echo "iGPU type:"
        echo "  1) Intel"
        echo "  2) AMD"
        read -p "Choice [1]: " IGPU_CHOICE
        IGPU_CHOICE=${IGPU_CHOICE:-1}
        read -p "iGPU Bus ID (e.g., PCI:0:2:0): " IGPU_BUS_ID
        case "$IGPU_CHOICE" in
            2) IGPU_TYPE="amd" ;;
            *) IGPU_TYPE="intel" ;;
        esac
        ;;
    *)
        # No extra GPU config
        ;;
esac

# ──────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────
echo -e "\n${CYAN}Configuration Summary:${NC}"
echo "  Hostname:     $HOSTNAME"
echo "  Username:     $USERNAME"
echo "  Mode:         $INSTALL_MODE"
if [ "$INSTALL_MODE" = "whole-disk" ]; then
    echo "  Disk:         /dev/$DISK_DEV"
else
    echo "  Disk:         /dev/$DISK_DEV"
    echo "  NixOS Part:   $NIXOS_PARTITION"
    echo "  EFI Part:     $EFI_PARTITION"
fi
echo "  Swap:         $SWAP_SIZE"
echo "  Filesystem:   $FS_TYPE"
if [ "$NVIDIA_ENABLE" = "true" ]; then
    echo "  GPU:          NVIDIA"
    if [ "$NVIDIA_PRIME_ENABLE" = "true" ]; then
        echo "  Prime:        Enabled ($NVIDIA_BUS_ID + $IGPU_TYPE:$IGPU_BUS_ID)"
    fi
else
    echo "  GPU:          Default (no NVIDIA)"
fi
echo ""
read -p "Proceed with installation? [Y/n]: " PROCEED
PROCEED=${PROCEED:-Y}
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# ──────────────────────────────────────────────
# [8/8] Generate Configuration & Install
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[8/8] Setting up configuration...${NC}"
HOST_DIR="$WORK_DIR/hosts/$HOSTNAME"
mkdir -p "$HOST_DIR"

# Generate Hardware Config
echo -e "Generating hardware configuration..."
nixos-generate-config --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"

# Build GPU configuration block
GPU_CONFIG=""
if [ "$NVIDIA_ENABLE" = "true" ]; then
    GPU_CONFIG="
  # NVIDIA GPU
  snowflake.nvidia.enable = true;"

    if [ "$NVIDIA_PRIME_ENABLE" = "true" ]; then
        GPU_CONFIG="$GPU_CONFIG
  snowflake.nvidia.prime = {
    enable = true;
    nvidiaBusId = \"$NVIDIA_BUS_ID\";"
        if [ "$IGPU_TYPE" = "intel" ]; then
            GPU_CONFIG="$GPU_CONFIG
    intelBusId = \"$IGPU_BUS_ID\";"
        else
            GPU_CONFIG="$GPU_CONFIG
    amdgpuBusId = \"$IGPU_BUS_ID\";"
        fi
        GPU_CONFIG="$GPU_CONFIG
  };"
    fi
fi

if [ "$INSTALL_MODE" = "whole-disk" ]; then
    # ═══════════════════════════════════════════════
    # WHOLE-DISK MODE — use disko (original behavior)
    # ═══════════════════════════════════════════════
    echo -e "Creating disko configuration..."
    cat > "$HOST_DIR/disko.nix" <<EOF
# Auto-generated disko configuration for $HOSTNAME
# Device: /dev/$DISK_DEV, Swap: $SWAP_SIZE, Filesystem: $FS_TYPE
{
  disko.devices.disk.main.device = "/dev/$DISK_DEV";
EOF

    if [ "$SWAP_SIZE" != "8G" ]; then
        if [ "$SWAP_SIZE" = "0" ]; then
            echo '  # Swap disabled' >> "$HOST_DIR/disko.nix"
            echo '  disko.devices.disk.main.content.partitions.swap.size = "0";' >> "$HOST_DIR/disko.nix"
        else
            echo "  disko.devices.disk.main.content.partitions.swap.size = \"$SWAP_SIZE\";" >> "$HOST_DIR/disko.nix"
        fi
    fi

    echo "}" >> "$HOST_DIR/disko.nix"

    # Create Host Configuration
    echo -e "Creating host configuration..."
    cat > "$HOST_DIR/configuration.nix" <<EOF
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./disko.nix
    ../common/base.nix
  ];

  home-manager.users.$USERNAME = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "$USERNAME";
    home.homeDirectory = lib.mkForce "/home/$USERNAME";
  };

  # User account
  users.users.$USERNAME = {
    isNormalUser = true;
    description = "$USERNAME";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$HASHED_PASSWORD";
  };
$GPU_CONFIG

  # Hostname
  networking.hostName = "$HOSTNAME";

  system.stateVersion = "26.05";
}
EOF

    # Handle filesystem type override
    if [ "$FS_TYPE" = "ext4" ]; then
        echo -e "Configuring ext4 filesystem..."
        cat > "$HOST_DIR/disko-fs.nix" <<EOF
{
  # Override to use ext4 instead of btrfs
  disko.devices.disk.main.content.partitions.root.content = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };
}
EOF
        sed -i '/imports = \[/a \    ./disko-fs.nix' "$HOST_DIR/configuration.nix"
    fi

    # Stage files
    echo -e "Staging files for flake (if git checkout)..."
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        git add .
    else
        echo -e "${YELLOW}Not in a git repository, skipping git add.${NC}"
    fi

    # Apply Partitioning with Disko
    echo -e "\n${GREEN}Partitioning /dev/$DISK_DEV with Disko...${NC}"
    nix run github:nix-community/disko -- --mode disko --flake ".#$HOSTNAME"

    # Install NixOS
    echo -e "\n${GREEN}Installing NixOS...${NC}"
    nixos-install --flake ".#$HOSTNAME" --no-root-password

    copy_flake_to_target

else
    # ═══════════════════════════════════════════════
    # PARTITION-ONLY MODE — manual btrfs + subvolumes
    # ═══════════════════════════════════════════════
    echo -e "\n${GREEN}Formatting $NIXOS_PARTITION as btrfs...${NC}"
    mkfs.btrfs -f "$NIXOS_PARTITION"

    # Mount and create subvolumes
    echo -e "${GREEN}Creating btrfs subvolumes...${NC}"
    mount "$NIXOS_PARTITION" /mnt

    btrfs subvolume create /mnt/@root
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@nix
    btrfs subvolume create /mnt/@log

    if [ "$SWAP_SIZE" != "0" ]; then
        btrfs subvolume create /mnt/@swap
    fi

    # Unmount and remount with subvolumes
    umount /mnt

    echo -e "${GREEN}Mounting subvolumes...${NC}"
    mount -o subvol=@root,compress=zstd "$NIXOS_PARTITION" /mnt

    mkdir -p /mnt/home
    mount -o subvol=@home,compress=zstd "$NIXOS_PARTITION" /mnt/home

    mkdir -p /mnt/nix
    mount -o subvol=@nix,compress=zstd,noatime "$NIXOS_PARTITION" /mnt/nix

    mkdir -p /mnt/var/log
    mount -o subvol=@log,compress=zstd "$NIXOS_PARTITION" /mnt/var/log

    # Mount existing EFI partition
    mkdir -p /mnt/boot/efi
    mount "$EFI_PARTITION" /mnt/boot/efi

    # Create swapfile if enabled
    if [ "$SWAP_SIZE" != "0" ]; then
        echo -e "${GREEN}Creating ${SWAP_SIZE} swapfile...${NC}"
        mkdir -p /mnt/swap
        mount -o subvol=@swap "$NIXOS_PARTITION" /mnt/swap

        # Disable CoW for swap subvolume
        chattr +C /mnt/swap

        # Parse swap size to bytes for truncate
        SWAP_BYTES="$SWAP_SIZE"
        truncate -s 0 /mnt/swap/swapfile
        chattr +C /mnt/swap/swapfile
        fallocate -l "$SWAP_SIZE" /mnt/swap/swapfile
        chmod 600 /mnt/swap/swapfile
        mkswap /mnt/swap/swapfile
        swapon /mnt/swap/swapfile
    fi

    # Get UUID of the NixOS partition for fstab
    NIXOS_UUID=$(blkid -s UUID -o value "$NIXOS_PARTITION")
    EFI_UUID=$(blkid -s UUID -o value "$EFI_PARTITION")

    echo -e "NixOS partition UUID: $NIXOS_UUID"
    echo -e "EFI partition UUID:   $EFI_UUID"

    # Generate NixOS configuration with fileSystems (no disko)
    echo -e "Creating filesystem configuration..."
    SWAP_CONFIG=""
    if [ "$SWAP_SIZE" != "0" ]; then
        SWAP_CONFIG='
  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/'"$NIXOS_UUID"'";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];'
    fi

    cat > "$HOST_DIR/filesystems.nix" <<EOF
# Auto-generated filesystem configuration for $HOSTNAME
# Partition-only (dual-boot) mode
# NixOS partition: $NIXOS_PARTITION (UUID: $NIXOS_UUID)
# EFI partition: $EFI_PARTITION (UUID: $EFI_UUID)
{
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/$NIXOS_UUID";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/$NIXOS_UUID";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/$NIXOS_UUID";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-uuid/$NIXOS_UUID";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" ];
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-uuid/$EFI_UUID";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
$SWAP_CONFIG
}
EOF

    # Create Host Configuration (no disko import)
    echo -e "Creating host configuration..."
    cat > "$HOST_DIR/configuration.nix" <<EOF
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ./filesystems.nix
    ../common/base.nix
  ];

  home-manager.users.$USERNAME = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "$USERNAME";
    home.homeDirectory = lib.mkForce "/home/$USERNAME";
  };

  # User account
  users.users.$USERNAME = {
    isNormalUser = true;
    description = "$USERNAME";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$HASHED_PASSWORD";
  };
$GPU_CONFIG

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
      useOSProber = true;  # Detect Windows and other OSes
    };
  };

  # Hostname
  networking.hostName = "$HOSTNAME";

  system.stateVersion = "26.05";
}
EOF

    # Stage files
    echo -e "Staging files for flake (if git checkout)..."
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        git add .
    else
        echo -e "${YELLOW}Not in a git repository, skipping git add.${NC}"
    fi

    # Generate hardware config to /mnt
    echo -e "Generating hardware configuration for mounted system..."
    nixos-generate-config --root /mnt --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"

    # Install NixOS
    echo -e "\n${GREEN}Installing NixOS to /mnt...${NC}"
    nixos-install --flake ".#$HOSTNAME" --no-root-password

    copy_flake_to_target
fi

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo -e "Your configuration has been saved to: ${CYAN}/home/$USERNAME/snowflake${NC}"
echo -e "You can now reboot into your new Snowflake system."
echo -e "After rebooting, run: ${CYAN}cd ~/snowflake && sudo nixos-rebuild switch --flake .#$HOSTNAME${NC}"
echo -e "Run: ${CYAN}reboot${NC}"
