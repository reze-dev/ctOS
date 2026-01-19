# ❄️ Snowflake NixOS

A fully automated, distributable NixOS deployment using [Disko](https://github.com/nix-community/disko) and Flakes.

## Quick Install

### Option 1: Remote Install (Recommended)

Boot a NixOS ISO and run:

```bash
# Using curl
sudo bash <(curl -sL https://raw.githubusercontent.com/atomiksan/snowflake/main/remote-install.sh)

# Or using nix run
sudo nix run github:atomiksan/snowflake#install --extra-experimental-features "nix-command flakes"
```

### Option 2: Manual Clone

```bash
# Get git in the live environment
nix-shell -p git

# Clone and run
git clone https://github.com/YOUR-USERNAME/snowflake.git
cd snowflake
sudo ./install.sh
```

## What the Installer Does

The installer will prompt for:

| Prompt | Description |
|--------|-------------|
| **Hostname** | System name (e.g., `my-laptop`) |
| **Username** | Primary user account |
| **Password** | User password (hashed securely) |
| **Target Disk** | Disk to install on (e.g., `nvme0n1`) |
| **Swap Size** | Swap partition size (e.g., `8G`, `16G`, or `0` to disable) |
| **Filesystem** | Root filesystem type (`btrfs` or `ext4`) |

Then it:
1. Creates a new host configuration in `hosts/<hostname>/`
2. Generates `hardware-configuration.nix` for the machine
3. Partitions and formats the disk using Disko
4. Installs NixOS with your flake configuration

## Testing in a VM

Safely test the deployment using QEMU:

```bash
# Download a NixOS ISO first, then:
./test-deployment.sh /path/to/nixos.iso
```

Inside the VM:
```bash
mkdir -p /mnt/snowflake
mount -t 9p -o trans=virtio,version=9p2000.L,msize=5120000 host0 /mnt/snowflake
cd /mnt/snowflake
sudo ./install.sh
```

## Configuration

### Adding a New Host Manually

1. Create `hosts/<hostname>/configuration.nix`
2. Add `hardware-configuration.nix` 
3. The flake auto-discovers hosts in the `hosts/` directory

### Customizing Disk Layout

Edit `hosts/common/disko-config.nix` for the base layout, or override per-host in `hosts/<hostname>/disko.nix`.

## Repository Structure

```
snowflake/
├── flake.nix             # Flake definition with auto-discovery
├── install.sh            # Local installer script
├── remote-install.sh     # Remote curl-based installer
├── hosts/
│   ├── common/
│   │   └── disko-config.nix   # Base disk configuration
│   └── <hostname>/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       └── disko.nix     # Host-specific disk overrides
├── nixos/                # System-wide NixOS modules
├── home/                 # Home Manager configurations  
└── home.nix              # Base home configuration
```

## Environment Variables

For remote install customization:

| Variable | Description | Default |
|----------|-------------|---------|
| `SNOWFLAKE_REPO` | Git repository URL | `https://github.com/YOUR-USERNAME/snowflake.git` |
| `SNOWFLAKE_BRANCH` | Branch to clone | `main` |

Example:
```bash
SNOWFLAKE_REPO="https://github.com/myuser/snowflake.git" \
SNOWFLAKE_BRANCH="feature/testing" \
sudo bash <(curl -sL .../remote-install.sh)
```
