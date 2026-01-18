# Deploying Snowflake

This repository contains a fully automated deployment strategy for NixOS using [Disko](https://github.com/nix-community/disko) and Flakes.

## Prerequisites
1. **NixOS Installer ISO**: Boot the target machine with a standard NixOS ISO (GNOME/Plasma edition recommended for ease of Wi-Fi setup, but minimal works too).
2. **Internet Connection**: Ensure the machine is online.

## Deployment Steps

### 1. Clone the Repository
Open a terminal in the live environment and clone this repository:
```bash
nix-shell -p git
git clone https://github.com/your-username/snowflake.git
cd snowflake
```
*Note: If you haven't pushed this branch yet, you might need to check out the specific branch.*
```bash
git checkout feature/deployment-strategy
```

### 2. Run the Installer
Execute the `install.sh` script. You typically need root privileges:
```bash
sudo ./install.sh
```

### 3. Follow the Prompts
The script will ask for:
- **Target Hostname**: The name for the new machine (e.g., `laptop-1`).
- **Target Disk**: The drive to wipe and install NixOS on (e.g., `nvme0n1`).

### What the script does:
1. Creates a new host directory `hosts/<hostname>`.
2. Generates `hardware-configuration.nix` specific to the machine.
3. Creates a `configuration.nix` with standard defaults and imports `disko` for partitioning.
4. Updates `flake.nix` (conceptually, by dynamic scanning) to include the new host.
5. Stages files to git (required for Flakes).
6. format and partitions the disk using **Disko**.
7. Installs NixOS.

### 4. Reboot
After installation completes, reboot into your new Snowflake system!

## Testing (Virtual Machine)
You can test the deployment safely using QEMU.

1.  **Download NixOS ISO**: Get the latest minimal or graphical ISO from [nixos.org](https://nixos.org/download.html).
2.  **Run the Test Script**:
    ```bash
    ./test-deployment.sh /path/to/nixos-plasma6-24.11.x86_64-linux.iso
    ```
3.  **Inside the VM**:
    The script prints instructions on start-up. In the VM terminal:
    ```bash
    mkdir -p /mnt/snowflake
    mount -t 9p -o trans=virtio,version=9p2000.L,msize=5120000 host0 /mnt/snowflake
    cd /mnt/snowflake
    sudo ./install.sh
    ```

