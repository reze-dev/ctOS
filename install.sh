#!/usr/bin/env bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Snowflake Installer${NC}"

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root${NC}"
  exit 1
fi

# 1. Ask for Target Hostname
read -p "Enter Target Hostname (e.g., connected-to-monitor): " HOSTNAME
if [ -z "$HOSTNAME" ]; then
    echo -e "${RED}Hostname cannot be empty${NC}"
    exit 1
fi

# 1.5 Ask for Username
read -p "Enter Username (default: loid): " USERNAME
USERNAME=${USERNAME:-loid}

# 1.6 Ask for Password
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

HOST_DIR="./hosts/$HOSTNAME"
mkdir -p "$HOST_DIR"

# 2. Disk Selection
echo -e "\n${GREEN}Available Disks:${NC}"
lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk
echo ""
read -p "Enter Target Disk Device (e.g., nvme0n1 or sda): " DISK_DEV

if [ ! -b "/dev/$DISK_DEV" ]; then
    echo -e "${RED}Device /dev/$DISK_DEV does not exist${NC}"
    exit 1
fi

# 3. Generate Hardware Config
echo -e "\n${GREEN}Generating Hardware Config...${NC}"
nixos-generate-config --show-hardware-config > "$HOST_DIR/hardware-configuration.nix"

# 4. Create Host Configuration
echo -e "\n${GREEN}Creating Host Configuration...${NC}"
if [ ! -f "$HOST_DIR/configuration.nix" ]; then
    cat > "$HOST_DIR/configuration.nix" <<EOF
{
  config,
  lib,
  pkgs,
  inputs,
  importers,
  ...
}:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.nix-index-database.nixosModules.nix-index
  ] ++ (importers.scanPaths ../../nixos); # Reuse existing modules

  home-manager.extraSpecialArgs = { inherit inputs importers; };
  home-manager.users.${USERNAME} = {
    imports = [ ../../home.nix ];
    home.username = lib.mkForce "${USERNAME}";
    home.homeDirectory = lib.mkForce "/home/${USERNAME}";
  };

  # Define the user account
  users.users.${USERNAME} = {
    isNormalUser = true;
    description = "${USERNAME}";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    initialHashedPassword = "${HASHED_PASSWORD}";
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Hostname
  networking.hostName = "$HOSTNAME";

  system.stateVersion = "24.11"; 
}
EOF
fi

# 5. Git Tracking (Required for Flakes)
echo -e "\n${GREEN}Staging files for Flake...${NC}"
git add .

# 6. Apply Partitioning with Disko
echo -e "\n${GREEN}Partitioning /dev/$DISK_DEV with Disko...${NC}"
# We pass the device as an argument to the disko configuration via --arg, 
# BUT disko via nix run usually wants a flake attribute.
# Since we modified flake.nix to include disko config in the host,
# we can use disko-install or just nixos-install if partitions are mounted.

# However, to run disko *before* install to formatting:
# We can use the standalone disko tool from the flake input.

# We need to construct a disko payload or override the device.
# The common/disko-config.nix has `main` device. 
# We need to set `device = "/dev/$DISK_DEV"`.

# The easiest way is to modify the disko-config.nix OR pass it as a special arg?
# Disko supports enforcing the device path. 
# Let's generate a host-specific disko override.

cat > "$HOST_DIR/disko.nix" <<EOF
{
  disko.devices.disk.main.device = "/dev/$DISK_DEV";
}
EOF

# Add it to configuration.nix imports if not present
if ! grep -q "disko.nix" "$HOST_DIR/configuration.nix"; then
    sed -i '/imports = \[/a \    ./disko.nix' "$HOST_DIR/configuration.nix"
fi

git add "$HOST_DIR/disko.nix"

echo -e "\n${GREEN}Running Disko Partitioning...${NC}"
# Use nix run to execute disko against the new host configuration
nix run github:nix-community/disko -- --mode disko --flake ".#$HOSTNAME"

# 7. Install NixOS
echo -e "\n${GREEN}Installing NixOS...${NC}"
nixos-install --flake ".#$HOSTNAME"

echo -e "\n${GREEN}Installation Complete! Rebooting in 5 seconds...${NC}"
sleep 5
# reboot
