#!/usr/bin/env bash

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Usage: $0 <path-to-nixos.iso>${NC}"
    echo "Please provide the path to a NixOS ISO image."
    exit 1
fi

ISO_PATH="$1"

if [ ! -f "$ISO_PATH" ]; then
    echo -e "${RED}Error: ISO file not found at $ISO_PATH${NC}"
    exit 1
fi

DISK_IMG="test-disk.qcow2"

# Create disk image if it doesn't exist
if [ ! -f "$DISK_IMG" ]; then
    echo -e "${GREEN}Creating 20GB disk image ($DISK_IMG)...${NC}"
    qemu-img create -f qcow2 "$DISK_IMG" 20G
else
    echo -e "${GREEN}Using existing disk image ($DISK_IMG)...${NC}"
fi

echo -e "${GREEN}Launching QEMU VM...${NC}"
echo "inside the VM, run:"
echo "  mkdir -p /mnt/snowflake"
echo "  mount -t 9p -o trans=virtio,version=9p2000.L,msize=5120000 host0 /mnt/snowflake"
echo "  cd /mnt/snowflake"
echo "  sudo ./install.sh"
echo ""

qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -drive file="$DISK_IMG",format=qcow2 \
    -cdrom "$ISO_PATH" \
    -fsdev local,security_model=passthrough,id=fsdev0,path="$(pwd)" \
    -device virtio-9p-pci,id=fs0,fsdev=fsdev0,mount_tag=host0 \
    -net nic,model=virtio \
    -net user \
    -vga virtio \
    -display gtk
