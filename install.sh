#!/usr/bin/env bash

set -e

# ── Colors & Helpers ─────────────────────────────────────────
GREEN='\033[0;32m' YELLOW='\033[1;33m' RED='\033[0;31m'
CYAN='\033[0;36m'  BOLD='\033[1m'      NC='\033[0m'

msg()  { echo -e "${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}$*${NC}"; }
err()  { echo -e "${RED}$*${NC}"; }
step() { echo -e "\n${GREEN}[$1] $2${NC}"; }

die() { err "$@"; exit 1; }

confirm() {
    local prompt="$1" var="$2"
    read -p "$prompt" "$var"
    [[ -z "${!var}" ]] && die "${3:-Value cannot be empty}"
}

confirm_yes() {
    local ans
    read -p "$1 " ans
    [[ "$ans" == "yes" ]] || { echo "Aborted."; exit 1; }
}

# ── Copy flake to installed system ───────────────────────────
copy_flake_to_target() {
    msg "\nCopying Snowflake flake to installed system..."
    local dest="/mnt/home/$USERNAME/snowflake"
    mkdir -p "$dest"
    cp -a "$WORK_DIR/." "$dest/"

    # Fresh git repo
    rm -rf "$dest/.git"
    pushd "$dest" > /dev/null
    git init && git add . && git commit -m "Initial Snowflake configuration for $HOSTNAME"
    popd > /dev/null

    # Fix ownership from installed system's /etc/passwd
    local uid gid
    uid=$(grep "^${USERNAME}:" /mnt/etc/passwd | cut -d: -f3)
    gid=$(grep "^${USERNAME}:" /mnt/etc/passwd | cut -d: -f4)
    if [[ -n "$uid" && -n "$gid" ]]; then
        chown -R "$uid:$gid" "$dest"
        msg "Flake saved to /home/$USERNAME/snowflake (owned by UID $uid)"
    else
        warn "Could not determine UID/GID for $USERNAME."
        warn "After first boot, run: sudo chown -R $USERNAME:$USERNAME ~/snowflake"
    fi
}

# ── Generate configuration.nix for a host ────────────────────
generate_host_config() {
    local dir="$1" user="$2" hostname="$3" hashed_pw="$4"
    local gpu_config="$5" imports="$6" boot_config="$7"

    cat > "$dir/default.nix" <<EOF
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
$imports
  ];

  home-manager.users.$user = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "$user";
    home.homeDirectory = lib.mkForce "/home/$user";
  };

  users.users.$user = {
    isNormalUser = true;
    description = "$user";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$hashed_pw";
  };
$gpu_config

  networking.hostName = "$hostname";
$boot_config
  system.stateVersion = "26.05";
}
EOF
}

# ── Hash password ────────────────────────────────────────────
hash_password() {
    local pw="$1"
    if command -v mkpasswd &> /dev/null; then
        mkpasswd -m sha-512 "$pw"
    elif command -v openssl &> /dev/null; then
        openssl passwd -6 "$pw"
    elif command -v python3 &> /dev/null; then
        python3 -c "import crypt; print(crypt.crypt('$pw', crypt.mksalt(crypt.METHOD_SHA512)))"
    else
        die "No tool found to hash password (mkpasswd, openssl, python3)."
    fi
}

# ── Build GPU config block ───────────────────────────────────
build_gpu_config() {
    local gpu_choice="$1" nvidia_bus="$2" igpu_type="$3" igpu_bus="$4"
    local cfg=""

    [[ "$gpu_choice" == "1" ]] && return

    cfg="\n  # NVIDIA GPU\n  snowflake.nvidia.enable = true;"

    if [[ "$gpu_choice" == "3" ]]; then
        cfg="$cfg\n  snowflake.nvidia.prime = {\n    enable = true;\n    nvidiaBusId = \"$nvidia_bus\";"
        if [[ "$igpu_type" == "amd" ]]; then
            cfg="$cfg\n    amdgpuBusId = \"$igpu_bus\";"
        else
            cfg="$cfg\n    intelBusId = \"$igpu_bus\";"
        fi
        cfg="$cfg\n  };"
    fi

    echo -e "$cfg"
}

# ── Stage files for flake ────────────────────────────────────
stage_files() {
    msg "Staging files for flake..."
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        git add .
    else
        warn "Not in a git repository, skipping git add."
    fi
}

# ═════════════════════════════════════════════════════════════
# Main
# ═════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SNOWFLAKE_REMOTE:-$SCRIPT_DIR}"
cd "$WORK_DIR"

echo -e "${CYAN}"
echo "  ❄️  Snowflake NixOS Installer  ❄️"
echo "  ================================="
echo -e "${NC}"

[[ "$EUID" -ne 0 ]] && die "Please run as root"

# ── [1/8] Host ───────────────────────────────────────────────
step "1/8" "Host Configuration"
confirm "Enter Target Hostname (e.g., my-laptop): " HOSTNAME "Hostname cannot be empty"

# ── [2/8] User ───────────────────────────────────────────────
step "2/8" "User Configuration"
confirm "Enter Username: " USERNAME "Username cannot be empty"

echo -e "\nEnter Password for user $USERNAME (will be hashed):"
read -s PASSWORD
echo -e "\nConfirm Password:"
read -s PASSWORD_CONFIRM

[[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]] && die "Passwords do not match!"
[[ -z "$PASSWORD" ]] && die "Password cannot be empty"

msg "Hashing password..."
HASHED_PASSWORD=$(hash_password "$PASSWORD")

# ── [3/8] Installation Mode ─────────────────────────────────
step "3/8" "Installation Mode"
echo "Select installation mode:"
echo -e "  ${BOLD}1) Whole disk${NC} — fresh install, wipes entire disk"
echo -e "  ${BOLD}2) Partition only${NC} — dual-boot, installs to a specific partition"
read -p "Choice [1]: " INSTALL_MODE
INSTALL_MODE=${INSTALL_MODE:-1}

case "$INSTALL_MODE" in
    1) INSTALL_MODE="whole-disk" ;;
    2) INSTALL_MODE="partition-only" ;;
    *) warn "Invalid choice, defaulting to whole-disk"; INSTALL_MODE="whole-disk" ;;
esac

# ── [4/8] Disk / Partition Selection ─────────────────────────
step "4/8" "Disk & Partition Selection"

show_disks() { lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk || true; }

if [[ "$INSTALL_MODE" == "whole-disk" ]]; then
    warn "Available Disks:"
    show_disks
    echo ""
    confirm "Enter Target Disk Device (e.g., nvme0n1 or sda): " DISK_DEV "Disk device cannot be empty"
    [[ ! -b "/dev/$DISK_DEV" ]] && die "Device /dev/$DISK_DEV does not exist"
    err "WARNING: All data on /dev/$DISK_DEV will be DESTROYED!"
    confirm_yes "Type 'yes' to confirm:"
else
    warn "Available Disks:"
    show_disks
    echo ""
    confirm "Enter the disk to show partitions for (e.g., nvme0n1 or sda): " DISK_DEV "Disk device cannot be empty"
    [[ ! -b "/dev/$DISK_DEV" ]] && die "Device /dev/$DISK_DEV does not exist"

    echo -e "\n${YELLOW}Partitions on /dev/$DISK_DEV:${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "/dev/$DISK_DEV" 2>/dev/null || true
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"

    echo -e "\n${YELLOW}Free/unallocated space on /dev/$DISK_DEV:${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"
    if command -v parted &> /dev/null; then
        parted -s "/dev/$DISK_DEV" unit GiB print free 2>/dev/null | grep -i "free space" || echo "  (no unallocated space found)"
    else
        warn "  (parted not found — cannot detect free space)"
    fi
    echo -e "${CYAN}──────────────────────────────────────────────${NC}"

    echo ""
    echo "What would you like to do?"
    echo "  1) Use an existing partition"
    echo "  2) Create a new partition from unallocated space"
    read -p "Choice [1]: " PART_ACTION
    PART_ACTION=${PART_ACTION:-1}

    if [[ "$PART_ACTION" == "2" ]]; then
        command -v parted &> /dev/null || die "parted is required to create partitions but is not installed."

        warn "\nCreating a new Linux partition on /dev/$DISK_DEV..."
        read -p "Enter start position (e.g., 100GiB): " PART_START
        read -p "Enter end position or size (e.g., 200GiB or 100%): " PART_END
        [[ -z "$PART_START" || -z "$PART_END" ]] && die "Start and end positions are required"

        warn "Creating partition from $PART_START to $PART_END on /dev/$DISK_DEV..."
        PART_COUNT_BEFORE=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | wc -l)
        parted -s "/dev/$DISK_DEV" mkpart primary "$PART_START" "$PART_END"
        sleep 2; partprobe "/dev/$DISK_DEV" 2>/dev/null || true; sleep 1

        PART_COUNT_AFTER=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | wc -l)
        [[ "$PART_COUNT_AFTER" -le "$PART_COUNT_BEFORE" ]] && die "Failed to detect new partition."

        NIXOS_PART_NAME=$(lsblk -n -l -o NAME "/dev/$DISK_DEV" | tail -1)
        NIXOS_PARTITION="/dev/$NIXOS_PART_NAME"
        msg "Created new partition: $NIXOS_PARTITION"
    else
        read -p "Enter the partition device for NixOS (e.g., nvme0n1p5 or sda3): " NIXOS_PART_NAME
        NIXOS_PARTITION="/dev/$NIXOS_PART_NAME"
        [[ ! -b "$NIXOS_PARTITION" ]] && die "Partition $NIXOS_PARTITION does not exist"
    fi

    err "WARNING: All data on $NIXOS_PARTITION will be DESTROYED!"
    confirm_yes "Type 'yes' to confirm:"

    # Detect existing EFI System Partition
    warn "\nDetecting EFI System Partition on /dev/$DISK_DEV..."
    EFI_PARTITION=""
    while IFS= read -r line; do
        part_name=$(echo "$line" | awk '{print $1}')
        part_fstype=$(echo "$line" | awk '{print $2}')
        part_parttype=$(echo "$line" | awk '{print $3}')
        if [[ "$part_fstype" == "vfat" && "$part_parttype" == "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" ]]; then
            EFI_PARTITION="/dev/$part_name"
            break
        fi
    done < <(lsblk -n -l -o NAME,FSTYPE,PARTTYPE "/dev/$DISK_DEV" 2>/dev/null)

    if [[ -z "$EFI_PARTITION" ]]; then
        warn "Could not auto-detect ESP. Listing partitions:"
        lsblk -n -o NAME,SIZE,FSTYPE,LABEL "/dev/$DISK_DEV" 2>/dev/null || true
        read -p "Enter your EFI System Partition device (e.g., nvme0n1p1 or sda1): " EFI_PART_NAME
        EFI_PARTITION="/dev/$EFI_PART_NAME"
        [[ ! -b "$EFI_PARTITION" ]] && die "EFI partition $EFI_PARTITION does not exist"
    else
        msg "Found ESP: $EFI_PARTITION"
    fi
fi

# ── [5/8] Swap ───────────────────────────────────────────────
step "5/8" "Swap Configuration"
if [[ "$INSTALL_MODE" == "partition-only" ]]; then
    echo "Enter swap size (will be created as a swapfile inside btrfs)"
    echo "Examples: 8G, 16G, 0 to disable"
else
    echo "Enter swap partition size (examples: 8G, 16G, 0 to disable)"
fi
read -p "Swap size [8G]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-8G}
[[ ! "$SWAP_SIZE" =~ ^[0-9]+[GMgm]?$ && "$SWAP_SIZE" != "0" ]] && die "Invalid swap size format. Use format like 8G, 16G, or 0"

# ── [6/8] Filesystem ─────────────────────────────────────────
step "6/8" "Filesystem Configuration"
if [[ "$INSTALL_MODE" == "partition-only" ]]; then
    echo -e "Filesystem type: ${BOLD}btrfs${NC} (required for partition-only dual-boot mode)"
    FS_TYPE="btrfs"
else
    echo "Select root filesystem type:"
    echo "  1) btrfs (recommended - supports snapshots, subvolumes)"
    echo "  2) ext4 (simple, traditional)"
    read -p "Choice [1]: " FS_CHOICE
    case "${FS_CHOICE:-1}" in
        1|btrfs) FS_TYPE="btrfs" ;;
        2|ext4)  FS_TYPE="ext4" ;;
        *)       warn "Invalid choice, defaulting to btrfs"; FS_TYPE="btrfs" ;;
    esac
fi

# ── [7/8] GPU ────────────────────────────────────────────────
step "7/8" "GPU Configuration"
echo "Select your GPU type:"
echo "  1) None / Intel / AMD (no extra driver needed)"
echo "  2) NVIDIA (proprietary driver)"
echo "  3) NVIDIA + AMD/Intel hybrid (Prime)"
read -p "Choice [1]: " GPU_CHOICE
GPU_CHOICE=${GPU_CHOICE:-1}

NVIDIA_BUS_ID="" IGPU_BUS_ID="" IGPU_TYPE="intel"

if [[ "$GPU_CHOICE" == "3" ]]; then
    echo ""
    warn "To find PCI Bus IDs, run: lspci | grep -E 'VGA|3D'"
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
    read -p "iGPU Bus ID (e.g., PCI:0:2:0): " IGPU_BUS_ID
    [[ "${IGPU_CHOICE:-1}" == "2" ]] && IGPU_TYPE="amd"
fi

GPU_CONFIG=$(build_gpu_config "$GPU_CHOICE" "$NVIDIA_BUS_ID" "$IGPU_TYPE" "$IGPU_BUS_ID")

# ── Summary ──────────────────────────────────────────────────
echo -e "\n${CYAN}Configuration Summary:${NC}"
echo "  Hostname:     $HOSTNAME"
echo "  Username:     $USERNAME"
echo "  Mode:         $INSTALL_MODE"
echo "  Disk:         /dev/$DISK_DEV"
[[ "$INSTALL_MODE" == "partition-only" ]] && echo "  NixOS Part:   $NIXOS_PARTITION" && echo "  EFI Part:     $EFI_PARTITION"
echo "  Swap:         $SWAP_SIZE"
echo "  Filesystem:   $FS_TYPE"
if [[ "$GPU_CHOICE" != "1" ]]; then
    echo "  GPU:          NVIDIA"
    [[ "$GPU_CHOICE" == "3" ]] && echo "  Prime:        Enabled ($NVIDIA_BUS_ID + $IGPU_TYPE:$IGPU_BUS_ID)"
else
    echo "  GPU:          Default (no NVIDIA)"
fi

echo ""
read -p "Proceed with installation? [Y/n]: " PROCEED
[[ ! "${PROCEED:-Y}" =~ ^[Yy]$ ]] && { echo "Aborted."; exit 1; }

# ── [8/8] Generate Configuration & Install ───────────────────
step "8/8" "Setting up configuration..."
HOST_DIR="$WORK_DIR/hosts/$HOSTNAME"
mkdir -p "$HOST_DIR"

msg "Generating hardware configuration..."

if [[ "$INSTALL_MODE" == "whole-disk" ]]; then
    # ═══════════════════════════════════════════════
    # WHOLE-DISK MODE — disko
    # ═══════════════════════════════════════════════
    nixos-generate-config --show-hardware-config > "$HOST_DIR/hardware.nix"

    msg "Creating disko configuration..."
    {
        echo "# Auto-generated disko configuration for $HOSTNAME"
        echo "# Device: /dev/$DISK_DEV, Swap: $SWAP_SIZE, Filesystem: $FS_TYPE"
        echo "{"
        echo "  disko.devices.disk.main.device = \"/dev/$DISK_DEV\";"
        if [[ "$SWAP_SIZE" == "0" ]]; then
            echo '  # Swap disabled'
            echo '  disko.devices.disk.main.content.partitions.swap.size = "0";'
        elif [[ "$SWAP_SIZE" != "8G" ]]; then
            echo "  disko.devices.disk.main.content.partitions.swap.size = \"$SWAP_SIZE\";"
        fi
        echo "}"
    } > "$HOST_DIR/disko.nix"

    IMPORTS="    ./disko.nix"
    BOOT_CONFIG=""

    generate_host_config "$HOST_DIR" "$USERNAME" "$HOSTNAME" "$HASHED_PASSWORD" "$GPU_CONFIG" "$IMPORTS" "$BOOT_CONFIG"

    # Handle ext4 override
    if [[ "$FS_TYPE" == "ext4" ]]; then
        msg "Configuring ext4 filesystem..."
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
        sed -i '/imports = \[/a \    ./disko-fs.nix' "$HOST_DIR/default.nix"
    fi

    stage_files

    msg "\nPartitioning /dev/$DISK_DEV with Disko..."
    nix run github:nix-community/disko -- --mode disko --flake ".#$HOSTNAME"

    msg "\nInstalling NixOS..."
    nixos-install --flake ".#$HOSTNAME" --no-root-password
    copy_flake_to_target

else
    # ═══════════════════════════════════════════════
    # PARTITION-ONLY MODE — manual btrfs + subvolumes
    # ═══════════════════════════════════════════════
    msg "\nFormatting $NIXOS_PARTITION as btrfs..."
    mkfs.btrfs -f "$NIXOS_PARTITION"

    msg "Creating btrfs subvolumes..."
    mount "$NIXOS_PARTITION" /mnt

    for sv in @root @home @nix @log; do
        btrfs subvolume create "/mnt/$sv"
    done
    [[ "$SWAP_SIZE" != "0" ]] && btrfs subvolume create /mnt/@swap

    umount /mnt

    msg "Mounting subvolumes..."
    mount -o subvol=@root,compress=zstd "$NIXOS_PARTITION" /mnt
    mkdir -p /mnt/{home,nix,var/log,boot/efi}
    mount -o subvol=@home,compress=zstd "$NIXOS_PARTITION" /mnt/home
    mount -o subvol=@nix,compress=zstd,noatime "$NIXOS_PARTITION" /mnt/nix
    mount -o subvol=@log,compress=zstd "$NIXOS_PARTITION" /mnt/var/log
    mount "$EFI_PARTITION" /mnt/boot/efi

    # Swapfile
    if [[ "$SWAP_SIZE" != "0" ]]; then
        msg "Creating ${SWAP_SIZE} swapfile..."
        mkdir -p /mnt/swap
        mount -o subvol=@swap "$NIXOS_PARTITION" /mnt/swap
        chattr +C /mnt/swap
        truncate -s 0 /mnt/swap/swapfile
        chattr +C /mnt/swap/swapfile
        fallocate -l "$SWAP_SIZE" /mnt/swap/swapfile
        chmod 600 /mnt/swap/swapfile
        mkswap /mnt/swap/swapfile
        swapon /mnt/swap/swapfile
    fi

    NIXOS_UUID=$(blkid -s UUID -o value "$NIXOS_PARTITION")
    EFI_UUID=$(blkid -s UUID -o value "$EFI_PARTITION")
    msg "NixOS partition UUID: $NIXOS_UUID"
    msg "EFI partition UUID:   $EFI_UUID"

    # Generate filesystems.nix
    msg "Creating filesystem configuration..."
    SWAP_CONFIG=""
    if [[ "$SWAP_SIZE" != "0" ]]; then
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

    IMPORTS="    ./filesystems.nix"
    BOOT_CONFIG="
  # Boot — use existing EFI bootloader (dual-boot safe)
  boot.loader = {
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = \"/boot/efi\";
    };
    grub = {
      enable = true;
      device = \"nodev\";
      efiSupport = true;
      useOSProber = true;  # Detect Windows and other OSes
    };
  };
"

    generate_host_config "$HOST_DIR" "$USERNAME" "$HOSTNAME" "$HASHED_PASSWORD" "$GPU_CONFIG" "$IMPORTS" "$BOOT_CONFIG"

    stage_files

    msg "Generating hardware configuration for mounted system..."
    nixos-generate-config --root /mnt --show-hardware-config > "$HOST_DIR/hardware.nix"

    msg "\nInstalling NixOS to /mnt..."
    nixos-install --flake ".#$HOSTNAME" --no-root-password
    copy_flake_to_target
fi

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo -e "Your configuration has been saved to: ${CYAN}/home/$USERNAME/snowflake${NC}"
echo -e "You can now reboot into your new Snowflake system."
echo -e "After rebooting, run: ${CYAN}cd ~/snowflake && sudo nixos-rebuild switch --flake .#$HOSTNAME${NC}"
echo -e "Run: ${CYAN}reboot${NC}"
