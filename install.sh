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

# 1. Ask for Target Hostname
echo -e "${GREEN}[1/6] Host Configuration${NC}"
read -p "Enter Target Hostname (e.g., my-laptop): " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Hostname cannot be empty${NC}"
    exit 1
fi

# 2. Ask for Username
echo -e "\n${GREEN}[2/6] User Configuration${NC}"
read -p "Enter Username (default: loid): " USERNAME
USERNAME=${USERNAME:-loid}

# 3. Ask for Password
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
# Try mkpasswd (from whois/mkpasswd), then openssl, then python
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

# 4. Disk Selection  
echo -e "\n${GREEN}[3/6] Disk Selection${NC}"
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

# 5. Swap Size Configuration
echo -e "\n${GREEN}[4/6] Swap Configuration${NC}"
echo "Enter swap partition size (examples: 8G, 16G, 0 to disable)"
read -p "Swap size [8G]: " SWAP_SIZE
SWAP_SIZE=${SWAP_SIZE:-8G}

# Validate swap size format
if [[ ! "$SWAP_SIZE" =~ ^[0-9]+[GMgm]?$ ]] && [ "$SWAP_SIZE" != "0" ]; then
    echo -e "${RED}Invalid swap size format. Use format like 8G, 16G, or 0${NC}"
    exit 1
fi

# 6. Filesystem Type
echo -e "\n${GREEN}[5/6] Filesystem Configuration${NC}"
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

echo -e "\n${CYAN}Configuration Summary:${NC}"
echo "  Hostname:   $HOSTNAME"
echo "  Username:   $USERNAME"
echo "  Disk:       /dev/$DISK_DEV"
echo "  Swap:       $SWAP_SIZE"
echo "  Filesystem: $FS_TYPE"
echo ""
read -p "Proceed with installation? [Y/n]: " PROCEED
PROCEED=${PROCEED:-Y}
if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

# Create host directory
echo -e "\n${GREEN}[6/6] Setting up configuration...${NC}"
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

# Add swap size override if not default
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

  # Define the user account
  users.users.$USERNAME = {
    isNormalUser = true;
    description = "$USERNAME";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "$HASHED_PASSWORD";
  };

  # Hostname
  networking.hostName = "$HOSTNAME";

  system.stateVersion = "26.05";
}
EOF

# Handle filesystem type - for ext4, we need a different disko config
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
    # Add import to configuration.nix
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
