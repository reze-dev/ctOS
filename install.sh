#!/usr/bin/env bash

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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
echo -e "${GREEN}[1/7] Host Configuration${NC}"
read -p "Enter Target Hostname (e.g., my-laptop): " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Hostname cannot be empty${NC}"
    exit 1
fi

# ──────────────────────────────────────────────
# 2. User Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[2/7] User Configuration${NC}"
read -p "Enter Username: " USERNAME
if [ -z "$USERNAME" ]; then
    echo -e "${RED}Username cannot be empty${NC}"
    exit 1
fi

# 3. Password
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
# 4. Disk Selection
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[3/7] Disk Selection${NC}"
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

# ──────────────────────────────────────────────
# 5. Swap Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[4/7] Swap Configuration${NC}"
echo "Enter swap partition size (examples: 8G, 16G, 0 to disable)"
read -p "Swap size [8G]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-8G}

if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[GMgm]?$ ]] && [ "$SWAP_SIZE" != "0" ]; then
    echo -e "${RED}Invalid swap size format. Use format like 8G, 16G, or 0${NC}"
    exit 1
fi

# ──────────────────────────────────────────────
# 6. Filesystem Type
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[5/7] Filesystem Configuration${NC}"
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

# ──────────────────────────────────────────────
# 7. GPU Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[6/7] GPU Configuration${NC}"
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
echo "  Hostname:   $HOSTNAME"
echo "  Username:   $USERNAME"
echo "  Disk:       /dev/$DISK_DEV"
echo "  Swap:       $SWAP_SIZE"
echo "  Filesystem: $FS_TYPE"
if [ "$NVIDIA_ENABLE" = "true" ]; then
    echo "  GPU:        NVIDIA"
    if [ "$NVIDIA_PRIME_ENABLE" = "true" ]; then
        echo "  Prime:      Enabled ($NVIDIA_BUS_ID + $IGPU_TYPE:$IGPU_BUS_ID)"
    fi
else
    echo "  GPU:        Default (no NVIDIA)"
fi
echo ""
read -p "Proceed with installation? [Y/n]: " PROCEED
PROCEED=${PROCEED:-Y}
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# ──────────────────────────────────────────────
# [7/7] Generate Configuration
# ──────────────────────────────────────────────
echo -e "\n${GREEN}[7/7] Setting up configuration...${NC}"
HOST_DIR="$WORK_DIR/hosts/$HOSTNAME"
mkdir -p "$HOST_DIR"

# Generate Hardware Config
echo -e "Generating hardware configuration..."
nixos-generate-config --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"

# Generate host-specific disko configuration
echo -e "Creating disk configuration..."
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

# Handle filesystem type
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

# Stage files when running from a git checkout
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

echo -e "\n${GREEN}✅ Installation Complete!${NC}"
echo -e "You can now reboot into your new Snowflake system."
echo -e "Run: ${CYAN}reboot${NC}"
