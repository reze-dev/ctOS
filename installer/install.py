#!/usr/bin/env python3
"""
Cryonix NixOS Installer — idempotent, resumable, with retries.

State is saved to /tmp/cryonix-install-state.json after each step.
On re-run, the installer resumes from the last incomplete checkpoint.
"""

import json
import os
import shutil
import subprocess
import sys
import time
import getpass
import re
from pathlib import Path
from functools import wraps
from typing import Optional

# ── Constants ────────────────────────────────────────────────────
STATE_FILE = Path("/tmp/cryonix-install-state.json")
MAX_RETRIES = 3
RETRY_DELAY = 5  # seconds, doubles each attempt

STEPS = [
    "gather_host",
    "gather_user",
    "gather_mode",
    "gather_disk",
    "gather_swap_fs_gpu",
    "confirm",
    "generate_config",
    "partition",
    "install_nixos",
    "copy_flake",
    "done",
]

# ── Colors ───────────────────────────────────────────────────────
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
RED = "\033[0;31m"
CYAN = "\033[0;36m"
BOLD = "\033[1m"
NC = "\033[0m"


def msg(text: str) -> None:
    print(f"{GREEN}{text}{NC}")


def warn(text: str) -> None:
    print(f"{YELLOW}{text}{NC}")


def err(text: str) -> None:
    print(f"{RED}{text}{NC}")


def step(num: str, text: str) -> None:
    print(f"\n{GREEN}[{num}] {text}{NC}")


def die(text: str) -> None:
    err(text)
    sys.exit(1)


# ── State Management ─────────────────────────────────────────────
class State:
    """Persistent state with checkpoint-based resume."""

    def __init__(self) -> None:
        self.data: dict = {}
        self.load()

    def load(self) -> None:
        if STATE_FILE.exists():
            try:
                self.data = json.loads(STATE_FILE.read_text())
            except (json.JSONDecodeError, OSError):
                self.data = {}

    def save(self) -> None:
        STATE_FILE.write_text(json.dumps(self.data, indent=2))

    def get(self, key: str, default=None):
        return self.data.get(key, default)

    def set(self, key: str, value) -> None:
        self.data[key] = value
        self.save()

    def set_step(self, step_name: str) -> None:
        self.set("step", step_name)

    @property
    def current_step(self) -> str:
        return self.data.get("step", STEPS[0])

    def should_skip(self, step_name: str) -> bool:
        """Return True if this step was already completed."""
        current = self.current_step
        if current not in STEPS or step_name not in STEPS:
            return False
        return STEPS.index(step_name) < STEPS.index(current)

    def clear(self) -> None:
        self.data = {}
        if STATE_FILE.exists():
            STATE_FILE.unlink()


# ── Retry Decorator ──────────────────────────────────────────────
def retry(max_attempts: int = MAX_RETRIES, delay: int = RETRY_DELAY):
    """Retry decorator with exponential backoff and interactive fallback."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            last_err = None
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    last_err = e
                    if attempt < max_attempts:
                        wait = delay * (2 ** (attempt - 1))
                        warn(
                            f"  Attempt {attempt}/{max_attempts} failed: {e}\n"
                            f"  Retrying in {wait}s..."
                        )
                        time.sleep(wait)
                    else:
                        err(f"  All {max_attempts} attempts failed: {e}")

            # All retries exhausted — ask user
            while True:
                choice = input(
                    f"{YELLOW}[r]etry / [s]kip / [a]bort? {NC}"
                ).strip().lower()
                if choice == "r":
                    return wrapper(*args, **kwargs)
                elif choice == "s":
                    warn("  Skipped.")
                    return None
                elif choice == "a":
                    die("Aborted by user.")

        return wrapper

    return decorator


# ── Shell Helpers ────────────────────────────────────────────────
def run(
    cmd: str | list[str],
    check: bool = True,
    capture: bool = False,
    **kwargs,
) -> subprocess.CompletedProcess:
    """Run a shell command with logging."""
    if isinstance(cmd, str):
        kwargs.setdefault("shell", True)
    result = subprocess.run(
        cmd,
        capture_output=capture,
        text=True,
        **kwargs,
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip() if result.stderr else ""
        raise RuntimeError(
            f"Command failed (exit {result.returncode}): {cmd}\n{stderr}"
        )
    return result


def run_capture(cmd: str, check: bool = True) -> str:
    """Run a command and return stdout stripped."""
    r = run(cmd, check=check, capture=True)
    return r.stdout.strip()


def is_mounted(path: str) -> bool:
    """Check if a path is currently a mount point."""
    try:
        return run_capture(f"mountpoint -q {path} && echo yes || echo no") == "yes"
    except Exception:
        return False


def has_filesystem(device: str) -> bool:
    """Check if a device already has a filesystem."""
    try:
        result = run_capture(f"blkid -o value -s TYPE {device}", check=False)
        return bool(result)
    except Exception:
        return False


def subvolume_exists(mount: str, name: str) -> bool:
    """Check if a btrfs subvolume already exists."""
    try:
        out = run_capture(f"btrfs subvolume list {mount}", check=False)
        return name in out
    except Exception:
        return False


def confirm_input(prompt: str, err_msg: str = "Value cannot be empty") -> str:
    """Prompt for non-empty input."""
    value = input(prompt).strip()
    if not value:
        die(err_msg)
    return value


def confirm_yes(prompt: str) -> None:
    """Require user to type 'yes'."""
    ans = input(f"{prompt} ").strip()
    if ans != "yes":
        die("Aborted.")


# ── Password Hashing ────────────────────────────────────────────
def hash_password(password: str) -> str:
    """Hash password using best available tool."""
    for cmd_tpl in [
        "mkpasswd -m sha-512 '{pw}'",
        "openssl passwd -6 -stdin",
        "python3 -c \"import crypt; print(crypt.crypt('{pw}', crypt.mksalt(crypt.METHOD_SHA512)))\"",
    ]:
        tool = cmd_tpl.split()[0]
        if shutil.which(tool):
            if "stdin" in cmd_tpl:
                r = subprocess.run(
                    cmd_tpl.format(pw=password),
                    shell=True,
                    input=password,
                    capture_output=True,
                    text=True,
                )
            else:
                r = subprocess.run(
                    cmd_tpl.format(pw=password),
                    shell=True,
                    capture_output=True,
                    text=True,
                )
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip()
    die("No tool found to hash password (mkpasswd, openssl, python3).")
    return ""  # unreachable


# ── GPU Config Builder ───────────────────────────────────────────
def build_gpu_config(
    gpu_choice: str,
    nvidia_bus: str,
    igpu_type: str,
    igpu_bus: str,
) -> str:
    """Build the Nix GPU config block."""
    if gpu_choice == "1":
        return ""

    lines = ["\n  # NVIDIA GPU", "  cryonix.nvidia.enable = true;"]

    if gpu_choice == "3":
        lines.append("  cryonix.nvidia.prime = {")
        lines.append("    enable = true;")
        lines.append(f'    nvidiaBusId = "{nvidia_bus}";')
        bus_key = "amdgpuBusId" if igpu_type == "amd" else "intelBusId"
        lines.append(f'    {bus_key} = "{igpu_bus}";')
        lines.append("  };")

    return "\n".join(lines)


# ── Config Generation ────────────────────────────────────────────
def generate_host_config(
    host_dir: Path,
    user: str,
    hostname: str,
    hashed_pw: str,
    gpu_config: str,
    imports: str,
    boot_config: str,
) -> None:
    """Write the host default.nix."""
    content = f"""\
{{
  config,
  lib,
  pkgs,
  ...
}}:

{{
  imports = [
{imports}
  ];

  home-manager.users.{user} = {{
    imports = [ ../../home ];
    home.username = lib.mkForce "{user}";
    home.homeDirectory = lib.mkForce "/home/{user}";
  }};

  users.users.{user} = {{
    isNormalUser = true;
    description = "{user}";
    extraGroups = [ "networkmanager" "wheel" "libvirtd" "docker" ];
    shell = pkgs.zsh;
    hashedPassword = "{hashed_pw}";
  }};
{gpu_config}

  networking.hostName = "{hostname}";
{boot_config}  system.stateVersion = "26.05";
}}
"""
    (host_dir / "default.nix").write_text(content)


# ════════════════════════════════════════════════════════════════
#  Installer Steps
# ════════════════════════════════════════════════════════════════

def gather_host(state: State) -> None:
    step("1/8", "Host Configuration")
    hostname = confirm_input(
        "Enter Target Hostname (e.g., my-laptop): ", "Hostname cannot be empty"
    )
    state.set("hostname", hostname)
    state.set_step("gather_user")


def gather_user(state: State) -> None:
    step("2/8", "User Configuration")
    username = confirm_input("Enter Username: ", "Username cannot be empty")

    print("\nEnter Password (will be hashed):")
    password = getpass.getpass("  Password: ")
    password2 = getpass.getpass("  Confirm:  ")

    if password != password2:
        die("Passwords do not match!")
    if not password:
        die("Password cannot be empty")

    msg("Hashing password...")
    hashed = hash_password(password)
    state.set("username", username)
    state.set("hashed_password", hashed)
    state.set_step("gather_mode")


def gather_mode(state: State) -> None:
    step("3/8", "Installation Mode")
    print("Select installation mode:")
    print(f"  {BOLD}1) Whole disk{NC} — fresh install, wipes entire disk")
    print(f"  {BOLD}2) Partition only{NC} — dual-boot, installs to a specific partition")
    choice = input("Choice [1]: ").strip() or "1"
    mode = {"1": "whole-disk", "2": "partition-only"}.get(choice, "whole-disk")
    state.set("install_mode", mode)
    state.set_step("gather_disk")


def gather_disk(state: State) -> None:
    step("4/8", "Disk & Partition Selection")
    mode = state.get("install_mode")

    # Show disks
    warn("Available Disks:")
    run("lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep disk || true")
    print()

    disk_dev = confirm_input(
        "Enter Target Disk Device (e.g., nvme0n1 or sda): ",
        "Disk device cannot be empty",
    )
    if not Path(f"/dev/{disk_dev}").exists():
        die(f"Device /dev/{disk_dev} does not exist")
    state.set("disk_dev", disk_dev)

    if mode == "whole-disk":
        err(f"WARNING: All data on /dev/{disk_dev} will be DESTROYED!")
        confirm_yes("Type 'yes' to confirm:")
    else:
        # Show partitions
        print(f"\n{YELLOW}Partitions on /dev/{disk_dev}:{NC}")
        run(f"lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS /dev/{disk_dev}", check=False)

        # Show free space
        print(f"\n{YELLOW}Free/unallocated space:{NC}")
        if shutil.which("parted"):
            run(
                f'parted -s /dev/{disk_dev} unit GiB print free 2>/dev/null | grep -i "free space" || echo "  (none)"',
                check=False,
            )

        print("\nWhat would you like to do?")
        print("  1) Use an existing partition")
        print("  2) Create a new partition from unallocated space")
        action = input("Choice [1]: ").strip() or "1"

        if action == "2":
            if not shutil.which("parted"):
                die("parted is required but not installed.")
            start = input("Enter start position (e.g., 100GiB): ").strip()
            end = input("Enter end position (e.g., 200GiB or 100%): ").strip()
            if not start or not end:
                die("Start and end positions are required")

            warn(f"Creating partition from {start} to {end}...")
            before = run_capture(f"lsblk -n -l -o NAME /dev/{disk_dev} | wc -l")
            run(f'parted -s /dev/{disk_dev} mkpart primary "{start}" "{end}"')
            time.sleep(2)
            run(f"partprobe /dev/{disk_dev}", check=False)
            time.sleep(1)
            after = run_capture(f"lsblk -n -l -o NAME /dev/{disk_dev} | wc -l")
            if int(after) <= int(before):
                die("Failed to detect new partition.")
            part_name = run_capture(f"lsblk -n -l -o NAME /dev/{disk_dev} | tail -1")
            nixos_part = f"/dev/{part_name}"
            msg(f"Created: {nixos_part}")
        else:
            part_name = input("Enter NixOS partition device (e.g., nvme0n1p5): ").strip()
            nixos_part = f"/dev/{part_name}"
            if not Path(nixos_part).exists():
                die(f"Partition {nixos_part} does not exist")

        state.set("nixos_partition", nixos_part)
        err(f"WARNING: All data on {nixos_part} will be DESTROYED!")
        confirm_yes("Type 'yes' to confirm:")

        # Detect EFI
        warn("\nDetecting EFI System Partition...")
        efi_part = ""
        try:
            lines = run_capture(
                f"lsblk -n -l -o NAME,FSTYPE,PARTTYPE /dev/{disk_dev}"
            ).splitlines()
            for line in lines:
                parts = line.split()
                if len(parts) >= 3 and parts[1] == "vfat" and "c12a7328" in parts[2].lower():
                    efi_part = f"/dev/{parts[0]}"
                    break
        except Exception:
            pass

        if not efi_part:
            warn("Could not auto-detect ESP.")
            run(f"lsblk -n -o NAME,SIZE,FSTYPE,LABEL /dev/{disk_dev}", check=False)
            efi_name = input("Enter EFI partition device (e.g., nvme0n1p1): ").strip()
            efi_part = f"/dev/{efi_name}"
            if not Path(efi_part).exists():
                die(f"EFI partition {efi_part} does not exist")
        else:
            msg(f"Found ESP: {efi_part}")

        state.set("efi_partition", efi_part)

    state.set_step("gather_swap_fs_gpu")


def gather_swap_fs_gpu(state: State) -> None:
    mode = state.get("install_mode")

    # Swap
    step("5/8", "Swap Configuration")
    if mode == "partition-only":
        print("Enter swap size (btrfs swapfile). Examples: 8G, 16G, 0 to disable")
    else:
        print("Enter swap partition size. Examples: 8G, 16G, 0 to disable")
    swap = input("Swap size [8G]: ").strip() or "8G"
    if swap != "0" and not re.match(r"^\d+[GMgm]$", swap):
        die("Invalid swap size. Use format like 8G, 16G, or 0")
    state.set("swap_size", swap)

    # Filesystem
    step("6/8", "Filesystem Configuration")
    if mode == "partition-only":
        print(f"Filesystem: {BOLD}btrfs{NC} (required for dual-boot)")
        fs = "btrfs"
    else:
        print("Select root filesystem:")
        print("  1) btrfs (recommended)")
        print("  2) ext4")
        fc = input("Choice [1]: ").strip() or "1"
        fs = "ext4" if fc == "2" else "btrfs"
    state.set("fs_type", fs)

    # GPU
    step("7/8", "GPU Configuration")
    print("Select GPU type:")
    print("  1) None / Intel / AMD")
    print("  2) NVIDIA (proprietary)")
    print("  3) NVIDIA + AMD/Intel hybrid (Prime)")
    gpu = input("Choice [1]: ").strip() or "1"
    state.set("gpu_choice", gpu)

    nvidia_bus = igpu_bus = ""
    igpu_type = "intel"

    if gpu == "3":
        print()
        warn("To find PCI Bus IDs, run: lspci | grep -E 'VGA|3D'")
        if shutil.which("lspci"):
            print(f"{CYAN}Detected GPUs:{NC}")
            run("lspci | grep -E 'VGA|3D'", check=False)
        nvidia_bus = input("NVIDIA Bus ID (e.g., PCI:1:0:0): ").strip()
        print("iGPU type: 1) Intel  2) AMD")
        igpu_choice = input("Choice [1]: ").strip() or "1"
        igpu_bus = input("iGPU Bus ID (e.g., PCI:0:2:0): ").strip()
        if igpu_choice == "2":
            igpu_type = "amd"

    state.set("nvidia_bus_id", nvidia_bus)
    state.set("igpu_bus_id", igpu_bus)
    state.set("igpu_type", igpu_type)
    state.set_step("confirm")


def show_summary_and_confirm(state: State) -> None:
    mode = state.get("install_mode")
    gpu = state.get("gpu_choice")

    print(f"\n{CYAN}Configuration Summary:{NC}")
    print(f"  Hostname:     {state.get('hostname')}")
    print(f"  Username:     {state.get('username')}")
    print(f"  Mode:         {mode}")
    print(f"  Disk:         /dev/{state.get('disk_dev')}")
    if mode == "partition-only":
        print(f"  NixOS Part:   {state.get('nixos_partition')}")
        print(f"  EFI Part:     {state.get('efi_partition')}")
    print(f"  Swap:         {state.get('swap_size')}")
    print(f"  Filesystem:   {state.get('fs_type')}")
    if gpu != "1":
        g = "NVIDIA"
        if gpu == "3":
            g += f" Prime ({state.get('nvidia_bus_id')} + {state.get('igpu_type')}:{state.get('igpu_bus_id')})"
        print(f"  GPU:          {g}")
    else:
        print("  GPU:          Default (no NVIDIA)")

    print()
    ans = input("Proceed with installation? [Y/n]: ").strip() or "Y"
    if ans.lower() != "y":
        die("Aborted.")
    state.set_step("generate_config")


def generate_config(state: State, work_dir: Path) -> None:
    step("8/8", "Setting up configuration...")
    hostname = state.get("hostname")
    host_dir = work_dir / "hosts" / hostname
    host_dir.mkdir(parents=True, exist_ok=True)

    mode = state.get("install_mode")
    gpu_config = build_gpu_config(
        state.get("gpu_choice"),
        state.get("nvidia_bus_id"),
        state.get("igpu_type"),
        state.get("igpu_bus_id"),
    )

    if mode == "whole-disk":
        msg("Generating hardware configuration...")
        hw = run_capture("nixos-generate-config --show-hardware-config")
        (host_dir / "hardware.nix").write_text(hw + "\n")

        msg("Creating disko configuration...")
        disk_dev = state.get("disk_dev")
        swap = state.get("swap_size")
        disko = f'# Auto-generated disko config for {hostname}\n{{\n  disko.devices.disk.main.device = "/dev/{disk_dev}";\n'
        if swap == "0":
            disko += '  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = "0";\n'
        elif swap != "8G":
            disko += f'  disko.devices.disk.main.content.partitions.swap.size = "{swap}";\n'
        disko += "}\n"
        (host_dir / "disko.nix").write_text(disko)

        imports = "    ./disko.nix"
        boot_config = ""
        generate_host_config(
            host_dir, state.get("username"), hostname,
            state.get("hashed_password"), gpu_config, imports, boot_config,
        )

        # ext4 override
        if state.get("fs_type") == "ext4":
            msg("Configuring ext4 filesystem...")
            ext4_nix = """\
{
  disko.devices.disk.main.content.partitions.root.content = {
    type = "filesystem";
    format = "ext4";
    mountpoint = "/";
  };
}
"""
            (host_dir / "disko-fs.nix").write_text(ext4_nix)
            # Inject import
            default_nix = (host_dir / "default.nix").read_text()
            default_nix = default_nix.replace(
                "imports = [", "imports = [\n    ./disko-fs.nix", 1
            )
            (host_dir / "default.nix").write_text(default_nix)

    else:
        # Partition-only — config is generated, actual partitioning in next step
        imports = "    ./filesystems.nix"
        boot_config = """
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

"""
        generate_host_config(
            host_dir, state.get("username"), hostname,
            state.get("hashed_password"), gpu_config, imports, boot_config,
        )

    # Stage files
    msg("Staging files for flake...")
    try:
        run("git add .", check=False)
    except Exception:
        warn("Not in a git repo, skipping git add.")

    state.set_step("partition")


@retry(max_attempts=3, delay=5)
def do_partition(state: State, work_dir: Path) -> None:
    """Partition and format disks. Idempotent — checks state before acting."""
    mode = state.get("install_mode")
    hostname = state.get("hostname")
    host_dir = work_dir / "hosts" / hostname

    if mode == "whole-disk":
        msg("Partitioning with Disko...")
        run(f'nix run github:nix-community/disko -- --mode disko --flake ".#{hostname}"')

    else:
        nixos_part = state.get("nixos_partition")
        efi_part = state.get("efi_partition")
        swap = state.get("swap_size")

        # Format — idempotent: skip if already btrfs
        if has_filesystem(nixos_part):
            fs = run_capture(f"blkid -o value -s TYPE {nixos_part}", check=False)
            if fs == "btrfs":
                msg(f"{nixos_part} already formatted as btrfs, skipping format.")
            else:
                msg(f"Formatting {nixos_part} as btrfs...")
                run(f"mkfs.btrfs -f {nixos_part}")
        else:
            msg(f"Formatting {nixos_part} as btrfs...")
            run(f"mkfs.btrfs -f {nixos_part}")

        # Create subvolumes — idempotent
        if not is_mounted("/mnt"):
            run(f"mount {nixos_part} /mnt")

        subvols = ["@root", "@home", "@nix", "@log"]
        if swap != "0":
            subvols.append("@swap")

        for sv in subvols:
            if subvolume_exists("/mnt", sv):
                msg(f"  Subvolume {sv} already exists, skipping.")
            else:
                msg(f"  Creating subvolume {sv}...")
                run(f"btrfs subvolume create /mnt/{sv}")

        run("umount /mnt")

        # Mount subvolumes — idempotent
        if not is_mounted("/mnt"):
            run(f"mount -o subvol=@root,compress=zstd {nixos_part} /mnt")

        for d in ["home", "nix", "var/log", "boot/efi"]:
            os.makedirs(f"/mnt/{d}", exist_ok=True)

        mounts = [
            (f"-o subvol=@home,compress=zstd {nixos_part}", "/mnt/home"),
            (f"-o subvol=@nix,compress=zstd,noatime {nixos_part}", "/mnt/nix"),
            (f"-o subvol=@log,compress=zstd {nixos_part}", "/mnt/var/log"),
            (f"{efi_part}", "/mnt/boot/efi"),
        ]
        for opts, mp in mounts:
            if not is_mounted(mp):
                run(f"mount {opts} {mp}")
            else:
                msg(f"  {mp} already mounted, skipping.")

        # Swapfile — idempotent
        if swap != "0":
            swapfile = Path("/mnt/swap/swapfile")
            if swapfile.exists():
                msg("  Swapfile already exists, skipping.")
            else:
                msg(f"Creating {swap} swapfile...")
                os.makedirs("/mnt/swap", exist_ok=True)
                if not is_mounted("/mnt/swap"):
                    run(f"mount -o subvol=@swap {nixos_part} /mnt/swap")
                run("chattr +C /mnt/swap", check=False)
                run("truncate -s 0 /mnt/swap/swapfile")
                run("chattr +C /mnt/swap/swapfile", check=False)
                run(f"fallocate -l {swap} /mnt/swap/swapfile")
                run("chmod 600 /mnt/swap/swapfile")
                run("mkswap /mnt/swap/swapfile")
                run("swapon /mnt/swap/swapfile")

        # Get UUIDs and generate filesystems.nix
        nixos_uuid = run_capture(f"blkid -s UUID -o value {nixos_part}")
        efi_uuid = run_capture(f"blkid -s UUID -o value {efi_part}")
        msg(f"NixOS UUID: {nixos_uuid}")
        msg(f"EFI UUID:   {efi_uuid}")

        swap_config = ""
        if swap != "0":
            swap_config = f"""
  fileSystems."/swap" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@swap" ];
  }};

  swapDevices = [
    {{ device = "/swap/swapfile"; }}
  ];"""

        fs_nix = f"""\
# Auto-generated filesystem configuration for {hostname}
{{
  fileSystems."/" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@root" "compress=zstd" ];
  }};

  fileSystems."/home" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@home" "compress=zstd" ];
  }};

  fileSystems."/nix" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@nix" "compress=zstd" "noatime" ];
  }};

  fileSystems."/var/log" = {{
    device = "/dev/disk/by-uuid/{nixos_uuid}";
    fsType = "btrfs";
    options = [ "subvol=@log" "compress=zstd" ];
  }};

  fileSystems."/boot/efi" = {{
    device = "/dev/disk/by-uuid/{efi_uuid}";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  }};
{swap_config}
}}
"""
        (host_dir / "filesystems.nix").write_text(fs_nix)

        msg("Generating hardware configuration...")
        hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config")
        (host_dir / "hardware.nix").write_text(hw + "\n")

        # Re-stage
        try:
            run("git add .", check=False)
        except Exception:
            pass

    state.set_step("install_nixos")


@retry(max_attempts=3, delay=10)
def do_install_nixos(state: State) -> None:
    """Run nixos-install. Safe to re-run."""
    hostname = state.get("hostname")
    msg(f"\nInstalling NixOS (host: {hostname})...")
    run(f'nixos-install --flake ".#{hostname}" --no-root-password')
    state.set_step("copy_flake")


@retry(max_attempts=3, delay=5)
def do_copy_flake(state: State, work_dir: Path) -> None:
    """Copy flake to installed system. Idempotent — overwrites."""
    username = state.get("username")
    hostname = state.get("hostname")

    msg("\nCopying Cryonix flake to installed system...")
    dest = Path(f"/mnt/home/{username}/cryonix")
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(work_dir, dest, dirs_exist_ok=True)

    # Fresh git repo
    git_dir = dest / ".git"
    if git_dir.exists():
        shutil.rmtree(git_dir)
    run(f"cd {dest} && git init && git add . && git commit -m 'Initial Cryonix configuration for {hostname}'")

    # Fix ownership
    try:
        passwd = Path("/mnt/etc/passwd").read_text()
        for line in passwd.splitlines():
            fields = line.split(":")
            if fields[0] == username:
                uid, gid = fields[2], fields[3]
                run(f"chown -R {uid}:{gid} {dest}")
                msg(f"Flake saved to /home/{username}/cryonix (UID {uid})")
                break
        else:
            warn(f"Could not find UID for {username}. After boot, run:")
            warn(f"  sudo chown -R {username}:{username} ~/cryonix")
    except Exception:
        warn("Could not fix ownership. Fix after first boot.")

    state.set_step("done")


# ════════════════════════════════════════════════════════════════
#  Main
# ════════════════════════════════════════════════════════════════

def main() -> None:
    script_dir = Path(
        os.environ.get("CRYONIX_REMOTE", Path(__file__).resolve().parent.parent)
    )
    os.chdir(script_dir)

    print(f"{CYAN}")
    print("  ❄️  Cryonix NixOS Installer  ❄️")
    print("  =================================")
    print(f"{NC}")

    if os.geteuid() != 0:
        die("Please run as root")

    state = State()

    # Check for resume
    if state.current_step != STEPS[0]:
        warn(f"Resuming from checkpoint: {state.current_step}")
        ans = input("Continue from last checkpoint? [Y/n]: ").strip() or "Y"
        if ans.lower() != "y":
            state.clear()
            msg("Starting fresh.")

    # Run steps
    if not state.should_skip("gather_host"):
        gather_host(state)
    if not state.should_skip("gather_user"):
        gather_user(state)
    if not state.should_skip("gather_mode"):
        gather_mode(state)
    if not state.should_skip("gather_disk"):
        gather_disk(state)
    if not state.should_skip("gather_swap_fs_gpu"):
        gather_swap_fs_gpu(state)
    if not state.should_skip("confirm"):
        show_summary_and_confirm(state)
    if not state.should_skip("generate_config"):
        generate_config(state, script_dir)
    if not state.should_skip("partition"):
        do_partition(state, script_dir)
    if not state.should_skip("install_nixos"):
        do_install_nixos(state)
    if not state.should_skip("copy_flake"):
        do_copy_flake(state, script_dir)

    # Cleanup state
    state.clear()

    username = state.data.get("username", "user")
    hostname = state.data.get("hostname", "host")
    print(f"\n{GREEN}✅ Installation Complete!{NC}")
    print(f"Your configuration has been saved to: {CYAN}/home/{username}/cryonix{NC}")
    print(f"You can now reboot into your new Cryonix system.")
    print(f"After rebooting, run: {CYAN}cd ~/cryonix && sudo nixos-rebuild switch --flake .#{hostname}{NC}")
    print(f"Run: {CYAN}reboot{NC}")


if __name__ == "__main__":
    main()
