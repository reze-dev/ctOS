#!/usr/bin/env python3
"""
Northstar NixOS Installer — idempotent, resumable, with retries.

Provides full feature parity with Northstar Rust installer (installer-rs):
- Profiles (Base, Desktop, Workstation)
- 10 toggleable feature options and delta overrides
- Selectable bootloaders (GRUB with DedSec theme, Limine)
- Automated hardware detection (lspci GPU detection, lsblk -J disks, ESP scanning)
- Dual-boot detection and chainloader config generation
- Disko whole-disk and partition-only layout generation
- Host default.nix generation targeting NixOS 26.11
- Checkpoint-based state resume (/tmp/northstar-install-state.json)
"""

from __future__ import annotations

import getpass
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from enum import Enum
from functools import wraps
from pathlib import Path
from typing import Any, Callable, Optional


# ── Constants ────────────────────────────────────────────────────
STATE_FILE = Path("/tmp/northstar-install-state.json")
MAX_RETRIES = 3
RETRY_DELAY = 5  # seconds, doubles each attempt
NIX_CONFIG_FEATURES = "experimental-features = nix-command flakes pipe-operators"

STEP_ORDER = [
    "generate_config",
    "partition",
    "install_nixos",
    "copy_flake",
    "done",
]

# ── Colors & Formatting ──────────────────────────────────────────
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


def ensure_nix_config() -> None:
    """Export flake feature flags for every Nix command run by this session."""
    current = os.environ.get("NIX_CONFIG", "").strip()
    if NIX_CONFIG_FEATURES in current:
        return
    os.environ["NIX_CONFIG"] = (
        f"{current}\n{NIX_CONFIG_FEATURES}" if current else NIX_CONFIG_FEATURES
    )


# ── Data Models & Enums ──────────────────────────────────────────

class InstallMode(str, Enum):
    WHOLE_DISK = "whole-disk"
    PARTITION_ONLY = "partition-only"

    def __str__(self) -> str:
        return self.value


class ProfileChoice(str, Enum):
    BASE = "Base"
    DESKTOP = "Desktop"
    WORKSTATION = "Workstation"

    def __str__(self) -> str:
        if self == ProfileChoice.BASE:
            return "Base (Minimal CLI Server)"
        elif self == ProfileChoice.DESKTOP:
            return "Desktop (GUI + Compositors + Browsers)"
        elif self == ProfileChoice.WORKSTATION:
            return "Workstation (Desktop + Devtools + Virt)"
        return self.value


class BootloaderChoice(str, Enum):
    GRUB = "grub"
    LIMINE = "limine"

    def __str__(self) -> str:
        if self == BootloaderChoice.GRUB:
            return "GRUB (Cyberpunk DedSec Theme)"
        elif self == BootloaderChoice.LIMINE:
            return "Limine (Modern Ultra-Fast UEFI)"
        return self.value


class GpuChoice(str, Enum):
    NONE = "none"
    NVIDIA = "nvidia"
    NVIDIA_PRIME = "nvidia-prime"

    def __str__(self) -> str:
        if self == GpuChoice.NONE:
            return "Default (no NVIDIA)"
        elif self == GpuChoice.NVIDIA:
            return "NVIDIA Discrete"
        elif self == GpuChoice.NVIDIA_PRIME:
            return "NVIDIA Prime (Hybrid GPU)"
        return self.value


class IgpuType(str, Enum):
    INTEL = "intel"
    AMD = "amd"

    def __str__(self) -> str:
        return self.value

    @property
    def bus_id_key(self) -> str:
        return "intelBusId" if self == IgpuType.INTEL else "amdgpuBusId"


@dataclass
class FeatureOption:
    id: str
    label: str
    category: str
    enabled: bool


@dataclass
class DualBootEntry:
    name: str
    efi_path: str
    disk_uuid: str
    enabled: bool = True


@dataclass
class PartitionInfo:
    name: str
    size: str = "?"
    fs_type: str = ""
    mountpoint: Optional[str] = None
    label: Optional[str] = None
    uuid: Optional[str] = None


@dataclass
class DiskInfo:
    name: str
    size: str
    model: str
    drive_type: str
    partitions: list[PartitionInfo] = field(default_factory=list)


def default_features(profile: ProfileChoice | str) -> list[FeatureOption]:
    """Return default features list for given profile preset."""
    if isinstance(profile, str):
        for p in ProfileChoice:
            if p.value.lower() == profile.lower() or p.name.lower() == profile.lower():
                profile = p
                break
        else:
            profile = ProfileChoice.DESKTOP

    is_desktop = profile in (ProfileChoice.DESKTOP, ProfileChoice.WORKSTATION)
    is_workstation = profile == ProfileChoice.WORKSTATION

    return [
        # Desktop / Compositor
        FeatureOption(
            id="hyprland",
            label="Hyprland (Dynamic Wayland Tiling WM)",
            category="Desktop / Compositor",
            enabled=is_desktop,
        ),
        FeatureOption(
            id="niri",
            label="Niri (Scrollable-tiling Wayland WM)",
            category="Desktop / Compositor",
            enabled=False,
        ),
        FeatureOption(
            id="noctalia",
            label="Noctalia (Custom Desktop Environment)",
            category="Desktop / Compositor",
            enabled=is_desktop,
        ),
        # Shell & Terminal
        FeatureOption(
            id="zsh",
            label="Zsh + Starship / OMP Shell",
            category="Shell & Terminal",
            enabled=True,
        ),
        FeatureOption(
            id="fish",
            label="Fish Friendly Interactive Shell",
            category="Shell & Terminal",
            enabled=False,
        ),
        FeatureOption(
            id="ghostty",
            label="Ghostty Modern Terminal",
            category="Shell & Terminal",
            enabled=is_desktop,
        ),
        FeatureOption(
            id="kitty",
            label="Kitty GPU-accelerated Terminal",
            category="Shell & Terminal",
            enabled=is_desktop,
        ),
        # Development & Virt
        FeatureOption(
            id="devtools",
            label="Developer Workspace (LSPs, Compilers, Tools)",
            category="Development & Virt",
            enabled=is_workstation,
        ),
        FeatureOption(
            id="virtualization",
            label="Docker & Libvirt Virtualization",
            category="Development & Virt",
            enabled=is_workstation,
        ),
        FeatureOption(
            id="emacs",
            label="Emacs with Doom/Custom Config",
            category="Development & Virt",
            enabled=False,
        ),
    ]


@dataclass
class InstallConfig:
    hostname: str = ""
    username: str = ""
    hashed_pw: str = ""
    profile: ProfileChoice = ProfileChoice.DESKTOP
    shell: str = "zsh"
    bootloader: BootloaderChoice = BootloaderChoice.GRUB
    features: list[FeatureOption] = field(default_factory=lambda: default_features(ProfileChoice.DESKTOP))
    dual_boot_entries: list[DualBootEntry] = field(default_factory=list)
    mode: InstallMode = InstallMode.WHOLE_DISK
    disk_dev: str = ""
    nixos_part: str = ""
    efi_part: str = ""
    swap_size: str = "8G"
    swap_partition: str = ""
    fs_type: str = "btrfs"
    root_size: str = "100%"
    gpu_choice: GpuChoice = GpuChoice.NONE
    nvidia_bus_id: str = ""
    igpu_bus_id: str = ""
    igpu_type: IgpuType = IgpuType.INTEL


# ── State Management ─────────────────────────────────────────────
class State:
    """Persistent state with checkpoint-based resume."""

    def __init__(self, state_file: Optional[Path] = None) -> None:
        self.state_file = Path(state_file) if state_file else STATE_FILE
        self.data: dict[str, str] = {}
        self.load()

    def load(self) -> None:
        if self.state_file.exists():
            try:
                parsed = json.loads(self.state_file.read_text(encoding="utf-8", errors="replace"))
                self.data = parsed if isinstance(parsed, dict) else {}
            except (ValueError, UnicodeDecodeError, OSError, json.JSONDecodeError):
                self.data = {}
        else:
            self.data = {}

    def save(self) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        try:
            self.state_file.write_text(json.dumps(self.data, indent=2), encoding="utf-8")
        except OSError:
            pass

    def get(self, key: str, default: Any = None) -> Any:
        if not isinstance(self.data, dict):
            self.data = {}
        return self.data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data[key] = str(value)
        self.save()

    def set_step(self, step_name: str) -> None:
        self.set("step", step_name)

    def current_step(self) -> str:
        if not isinstance(self.data, dict):
            self.data = {}
        step = self.data.get("step")
        if isinstance(step, str) and step in STEP_ORDER:
            return step
        return STEP_ORDER[0]

    def is_completed(self, step_name: Optional[str] = None) -> bool:
        """Return True if installation is completed (or if a specific step was completed)."""
        if not isinstance(self.data, dict):
            self.data = {}
        if step_name is None:
            return self.current_step() == "done"
        return self.should_skip(step_name)

    def should_skip(self, step_name: str) -> bool:
        """Return True if this step was already completed in the checkpoint order."""
        current = self.current_step()
        if current not in STEP_ORDER or step_name not in STEP_ORDER:
            return False
        return STEP_ORDER.index(step_name) < STEP_ORDER.index(current)

    def clear(self) -> None:
        if isinstance(self.data, dict):
            self.data.clear()
        else:
            self.data = {}
        if self.state_file.exists():
            try:
                self.state_file.unlink()
            except OSError:
                pass


# ── App Wizard / Interactive State Model ────────────────────────
class Page(str, Enum):
    WELCOME = "Welcome"
    HOSTNAME = "Hostname"
    USERNAME = "Username"
    PASSWORD = "Password"
    PASSWORD_CONFIRM = "PasswordConfirm"
    PROFILE = "Profile"
    PROFILE_CUSTOMIZE = "ProfileCustomize"
    BOOTLOADER = "Bootloader"
    MODE = "Mode"
    DISK = "Disk"
    DISK_CONFIRM = "DiskConfirm"
    PART_SELECT = "PartSelect"
    PART_NEW_START = "PartNewStart"
    PART_NEW_END = "PartNewEnd"
    PART_EXIST = "PartExist"
    PART_CONFIRM = "PartConfirm"
    EFI = "Efi"
    FS = "Fs"
    ROOT_SIZE = "RootSize"
    SWAP = "Swap"
    SWAP_PARTITION = "SwapPartition"
    GPU = "Gpu"
    GPU_NV_BUS = "GpuNvBus"
    GPU_IGPU_TYPE = "GpuIgpuType"
    GPU_IGPU_BUS = "GpuIgpuBus"
    DUAL_BOOT = "DualBoot"
    SUMMARY = "Summary"
    INSTALLING = "Installing"
    DONE = "Done"


class App:
    """State and UI interaction controller for Northstar installer."""

    def __init__(self, work_dir: str = "/tmp/test-northstar-workdir") -> None:
        self.work_dir = work_dir
        self.page = Page.WELCOME
        self.should_quit = False
        self.input = ""
        self.cursor_pos = 0
        self.err = ""
        self.choices: list[str] = []
        self.cursor = 0
        self.detected_disks: list[DiskInfo] = []
        self.detected_efis: list[tuple[str, str, str]] = []
        self.config = InstallConfig()
        self.plain_pw = ""
        self.part_new_start = ""

    def apply_profile(self, profile: ProfileChoice | str) -> None:
        if isinstance(profile, str):
            for p in ProfileChoice:
                if p.value.lower() == profile.lower() or p.name.lower() == profile.lower():
                    profile = p
                    break
            else:
                profile = ProfileChoice.DESKTOP
        self.config.profile = profile
        self.config.features = default_features(profile)

    def toggle_current_feature(self) -> None:
        if self.cursor < len(self.config.features):
            self.config.features[self.cursor].enabled = not self.config.features[self.cursor].enabled

    def toggle_current_dual_boot(self) -> None:
        if self.cursor < len(self.config.dual_boot_entries):
            self.config.dual_boot_entries[self.cursor].enabled = not self.config.dual_boot_entries[self.cursor].enabled

    def go_to_page(self, next_page: Page) -> None:
        self.page = next_page
        self.err = ""
        self.cursor = 0

    def type_char(self, c: str) -> None:
        self.input = self.input[:self.cursor_pos] + c + self.input[self.cursor_pos:]
        self.cursor_pos += len(c)
        self.err = ""

    def delete_char(self) -> None:
        if self.cursor_pos > 0:
            self.input = self.input[:self.cursor_pos - 1] + self.input[self.cursor_pos:]
            self.cursor_pos -= 1
            self.err = ""

    def input_value(self) -> str:
        return self.input.strip()


# ── Retry Decorator ──────────────────────────────────────────────
def retry(max_attempts: int = MAX_RETRIES, delay: int = RETRY_DELAY) -> Callable:
    """Retry decorator with exponential backoff and interactive fallback."""

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
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
    **kwargs: Any,
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
    """Hash password securely using mkpasswd or openssl."""
    if shutil.which("mkpasswd"):
        r = subprocess.run(
            ["mkpasswd", "-m", "sha-512", "--stdin"],
            input=password,
            capture_output=True,
            text=True,
        )
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()

    if shutil.which("openssl"):
        r = subprocess.run(
            ["openssl", "passwd", "-6", "-stdin"],
            input=password,
            capture_output=True,
            text=True,
        )
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()

    try:
        import crypt
        return crypt.crypt(password, crypt.mksalt(crypt.METHOD_SHA512))
    except Exception:
        pass

    die("No tool found to hash password (mkpasswd, openssl).")
    return ""


# ── Hardware Detection Logic ────────────────────────────────────

def format_pci_bus_id(raw: str) -> Optional[str]:
    """Parse PCI slot string (e.g. '01:00.0' or '0000:01:00.0') into Nix format 'PCI:1:0:0'."""
    clean = raw.strip()
    if not clean:
        return None

    # Strip domain if present (e.g. "0000:01:00.0" -> "01:00.0")
    if clean.count(":") >= 2:
        parts = clean.split(":", 1)
        after_domain = parts[1]
    else:
        after_domain = clean

    colon_parts = after_domain.split(":")
    if len(colon_parts) != 2:
        return None

    bus_str = colon_parts[0]
    dev_fn_parts = colon_parts[1].split(".")
    if len(dev_fn_parts) != 2:
        return None

    dev_str = dev_fn_parts[0]
    fn_str = dev_fn_parts[1]

    try:
        bus = int(bus_str, 16)
        dev = int(dev_str, 16)
        func = int(fn_str, 16)
        return f"PCI:{bus}:{dev}:{func}"
    except ValueError:
        return None


def parse_lspci_output(
    output: str,
) -> tuple[GpuChoice, Optional[str], Optional[str], IgpuType]:
    """Parse lspci lines and extract GPU bus IDs and vendors."""
    nvidia_bus = None
    intel_bus = None
    amd_bus = None

    for line in output.splitlines():
        line_lower = line.lower()
        if (
            "vga compatible controller" in line_lower
            or "3d controller" in line_lower
            or "display controller" in line_lower
        ):
            tokens = line.split()
            slot = tokens[0] if tokens else ""
            formatted = format_pci_bus_id(slot)

            if "nvidia" in line_lower:
                nvidia_bus = formatted
            elif "intel" in line_lower:
                intel_bus = formatted
            elif (
                "amd" in line_lower
                or "advanced micro devices" in line_lower
                or "radeon" in line_lower
            ):
                amd_bus = formatted

    if nvidia_bus:
        if amd_bus:
            return (GpuChoice.NVIDIA_PRIME, nvidia_bus, amd_bus, IgpuType.AMD)
        elif intel_bus:
            return (GpuChoice.NVIDIA_PRIME, nvidia_bus, intel_bus, IgpuType.INTEL)
        else:
            return (GpuChoice.NVIDIA, nvidia_bus, None, IgpuType.INTEL)
    else:
        return (GpuChoice.NONE, None, None, IgpuType.INTEL)


def parse_lsblk_json(json_str: str) -> list[DiskInfo]:
    """Parse lsblk JSON string into structured DiskInfo objects."""
    if not json_str or not isinstance(json_str, str):
        return []

    try:
        data = json.loads(json_str)
    except (json.JSONDecodeError, TypeError, ValueError):
        return []

    if not isinstance(data, dict):
        return []

    disks = []
    for dev in data.get("blockdevices") or []:
        if not isinstance(dev, dict):
            continue
        dev_type = dev.get("type") or ""
        name = dev.get("name", "")
        if not isinstance(name, str):
            name = str(name) if name is not None else ""
        if dev_type != "disk" and not name.startswith("nvme") and not name.startswith("sd"):
            continue
        if name.startswith("loop") or name.startswith("zram"):
            continue

        model = (dev.get("model") or "Unknown Disk")
        model = model.strip() if isinstance(model, str) else "Unknown Disk"

        tran = dev.get("tran") or ""
        tran = tran.upper() if isinstance(tran, str) else ""

        if name.startswith("nvme"):
            drive_type = "NVMe"
        elif tran:
            drive_type = tran
        else:
            drive_type = "Disk"

        partitions = []
        for child in dev.get("children") or []:
            if not isinstance(child, dict):
                continue
            partitions.append(
                PartitionInfo(
                    name=child.get("name", "") or "",
                    size=child.get("size") or "?",
                    fs_type=child.get("fstype") or "",
                    mountpoint=child.get("mountpoint"),
                    label=child.get("label"),
                    uuid=child.get("uuid"),
                )
            )

        disks.append(
            DiskInfo(
                name=name,
                size=dev.get("size") or "?",
                model=model,
                drive_type=drive_type,
                partitions=partitions,
            )
        )

    return disks


def scan_esp_for_os(esp_mount_path: Path, esp_uuid: str) -> list[DualBootEntry]:
    """Detect dual-boot OS EFI files in mounted ESP directory."""
    entries = []
    candidates = [
        ("EFI/Microsoft/Boot/bootmgfw.efi", "Windows Boot Manager"),
        ("EFI/fedora/shimx64.efi", "Fedora Linux"),
        ("EFI/ubuntu/shimx64.efi", "Ubuntu"),
        ("EFI/arch/grubx64.efi", "Arch Linux"),
        ("EFI/debian/shimx64.efi", "Debian"),
        ("EFI/opensuse/shim.efi", "openSUSE"),
    ]

    for rel_path, name in candidates:
        full_path = esp_mount_path / rel_path
        if full_path.exists():
            entries.append(
                DualBootEntry(
                    name=name,
                    efi_path=f"/{rel_path}",
                    disk_uuid=esp_uuid,
                    enabled=True,
                )
            )

    return entries


def detect_all() -> dict[str, Any]:
    """Run full automatic hardware detection."""
    detected: dict[str, Any] = {
        "disks": [],
        "recommended_disk": None,
        "efi_partitions": [],
        "detected_os": [],
        "gpu_choice": GpuChoice.NONE,
        "nvidia_bus_id": None,
        "igpu_bus_id": None,
        "igpu_type": IgpuType.INTEL,
    }

    # 1. Detect GPUs
    try:
        lspci_out = run_capture("lspci -D 2>/dev/null || lspci 2>/dev/null")
        choice, nv_bus, igpu_bus, igpu_type = parse_lspci_output(lspci_out)
        detected["gpu_choice"] = choice
        detected["nvidia_bus_id"] = nv_bus
        detected["igpu_bus_id"] = igpu_bus
        detected["igpu_type"] = igpu_type
    except Exception:
        pass

    # 2. Detect Disks
    try:
        lsblk_out = run_capture(
            "lsblk -J -o NAME,SIZE,TYPE,MODEL,TRAN,MOUNTPOINT,FSTYPE,LABEL,UUID 2>/dev/null"
        )
        disks = parse_lsblk_json(lsblk_out)
        detected["disks"] = disks
        if disks:
            detected["recommended_disk"] = disks[0].name

        for disk in disks:
            for part in disk.partitions:
                if part.fs_type.lower() == "vfat" or "efi" in part.name.lower():
                    dev_path = f"/dev/{part.name}"
                    uuid = part.uuid or ""
                    detected["efi_partitions"].append((dev_path, part.size, uuid))
    except Exception:
        pass

    # 3. Detect Dual-Boot OSes
    temp_esp = Path("/tmp/northstar-esp-scan")
    temp_esp.mkdir(parents=True, exist_ok=True)
    for dev, _, uuid in detected["efi_partitions"]:
        try:
            if run(f"mount -o ro {dev} /tmp/northstar-esp-scan", check=False).returncode == 0:
                entries = scan_esp_for_os(temp_esp, uuid)
                detected["detected_os"].extend(entries)
                run("umount /tmp/northstar-esp-scan", check=False)
        except Exception:
            pass

    try:
        shutil.rmtree(temp_esp)
    except Exception:
        pass

    return detected


# ── Extra Entries Formatters ────────────────────────────────────

def format_grub_extra_entries(entries: list[DualBootEntry]) -> str:
    """Format GRUB extraEntries configuration."""
    enabled = [e for e in entries if e.enabled]
    if not enabled:
        return ""
    lines = ["  boot.loader.grub.extraEntries = ''"]
    for entry in enabled:
        lines.append(f'    menuentry "{entry.name}" {{')
        lines.append(f"      search --fs-uuid --set=root {entry.disk_uuid}")
        lines.append(f"      chainloader {entry.efi_path}")
        lines.append("    }")
    lines.append("  '';")
    return "\n".join(lines)


def format_limine_extra_entries(entries: list[DualBootEntry]) -> str:
    """Format Limine extraEntries configuration."""
    enabled = [e for e in entries if e.enabled]
    if not enabled:
        return ""
    lines = ["  boot.loader.limine.extraEntries = ''"]
    for entry in enabled:
        lines.append(f"    /{entry.name}")
        lines.append("    protocol: efi")
        lines.append(f"    path: boot():{entry.efi_path}")
        lines.append("")
    lines.append("  '';")
    return "\n".join(lines)


# ── Configuration Builders ──────────────────────────────────────

def build_gpu_config(cfg: InstallConfig) -> str:
    """Build the Nix GPU config block."""
    if cfg.gpu_choice == GpuChoice.NONE:
        return ""
    elif cfg.gpu_choice == GpuChoice.NVIDIA:
        return "  # NVIDIA GPU\n  northstar.nvidia.enable = true;"
    elif cfg.gpu_choice == GpuChoice.NVIDIA_PRIME:
        key = cfg.igpu_type.bus_id_key
        return (
            "  # NVIDIA GPU\n"
            "  northstar.nvidia.enable = true;\n"
            "  northstar.nvidia.prime = {\n"
            "    enable = true;\n"
            f'    nvidiaBusId = "{cfg.nvidia_bus_id}";\n'
            f'    {key} = "{cfg.igpu_bus_id}";\n'
            "  };"
        )
    return ""


def build_bootloader_config(cfg: InstallConfig) -> str:
    """Build the bootloader configuration block with dual boot entries."""
    if cfg.bootloader == BootloaderChoice.GRUB:
        s = '  # Bootloader\n  northstar.features.boot.loader = "grub";\n'
        extra = format_grub_extra_entries(cfg.dual_boot_entries)
        if extra:
            s += f"{extra}\n"
        return s
    elif cfg.bootloader == BootloaderChoice.LIMINE:
        s = '  # Bootloader\n  northstar.features.boot.loader = "limine";\n'
        extra = format_limine_extra_entries(cfg.dual_boot_entries)
        if extra:
            s += f"{extra}\n"
        return s
    return ""


def build_profile_config(cfg: InstallConfig) -> str:
    """Build the northstar.profiles configuration block."""
    lines = ["  # Northstar profiles", "  northstar.profiles = {"]
    if cfg.profile == ProfileChoice.BASE:
        lines.append("    base.enable = true;")
    elif cfg.profile == ProfileChoice.DESKTOP:
        lines.append("    desktop.enable = true;")
    elif cfg.profile == ProfileChoice.WORKSTATION:
        lines.append("    desktop.enable = true;")
        lines.append("    workstation.enable = true;")
    lines.append("  };")
    return "\n".join(lines)


def build_features_override(cfg: InstallConfig) -> str:
    """Build delta feature overrides for customized features."""
    defaults = default_features(cfg.profile)
    default_map = {f.id: f.enabled for f in defaults}
    overrides = []

    for f in cfg.features:
        if f.id in default_map and f.enabled != default_map[f.id]:
            val_str = "true" if f.enabled else "false"
            overrides.append(f"    {f.id}.enable = {val_str};")

    if not overrides:
        return ""

    return "  # Custom feature overrides\n  northstar.features = {\n" + "\n".join(overrides) + "\n  };"


def strip_filesystems_from_hardware(hw_text: str) -> str:
    """Strip fileSystems.* and swapDevices entries from hardware.nix output."""
    cleaned_lines = []
    in_fs_block = False
    fs_depth = 0
    in_swap_devices = False

    for line in hw_text.splitlines():
        stripped = line.strip()

        if in_swap_devices:
            if ";" in stripped:
                in_swap_devices = False
            continue

        if stripped.startswith("swapDevices"):
            if ";" not in stripped:
                in_swap_devices = True
            continue

        if (
            stripped.startswith("fileSystems.")
            or stripped.startswith("fileSystems =")
            or stripped.startswith("fileSystems ")
        ):
            in_fs_block = True
            fs_depth += stripped.count("{") - stripped.count("}")
            if ";" in stripped or (fs_depth <= 0 and "}" in stripped):
                in_fs_block = False
                fs_depth = 0
            continue

        if in_fs_block:
            fs_depth += stripped.count("{") - stripped.count("}")
            if fs_depth <= 0 and ("}" in stripped or ";" in stripped):
                in_fs_block = False
                fs_depth = 0
            continue

        cleaned_lines.append(line)

    result = "\n".join(cleaned_lines)
    while "\n\n\n" in result:
        result = result.replace("\n\n\n", "\n\n")
    return result.strip()


def generate_disko_whole_disk(cfg: InstallConfig) -> str:
    """Generate disko.nix content for whole-disk mode."""
    template = "ext4" if cfg.fs_type == "ext4" else "btrfs"
    disko = (
        f"# Auto-generated disko config for {cfg.hostname}\n"
        "{\n"
        "  lib,\n"
        "  ...\n"
        "}:\n\n"
        "{\n"
        f"  imports = [ ../../lib/disko/{template}.nix ];\n\n"
        f'  disko.devices.disk.main.device = "/dev/{cfg.disk_dev}";\n'
    )

    if cfg.swap_size == "0":
        disko += '  # Swap disabled\n  disko.devices.disk.main.content.partitions.swap.size = lib.mkForce "0";\n'
    elif cfg.swap_size != "8G":
        disko += f'  disko.devices.disk.main.content.partitions.swap.size = lib.mkForce "{cfg.swap_size}";\n'

    if cfg.root_size != "100%":
        disko += f'  disko.devices.disk.main.content.partitions.root.size = lib.mkForce "{cfg.root_size}";\n'

    disko += "}\n"
    return disko


def generate_disko_partition_only(
    cfg: InstallConfig,
    efi_uuid: str = "",
) -> str:
    """Generate disko.nix content for partition-only mode."""
    if not efi_uuid and cfg.efi_part:
        try:
            efi_uuid = run_capture(f"blkid -s UUID -o value {cfg.efi_part}")
        except Exception:
            efi_uuid = ""

    lines = [
        f"# Auto-generated disko config for {cfg.hostname} (partition-only)",
        "{",
        "  disko.devices.disk.nixos = {",
        '    type = "disk";',
        f'    device = "{cfg.nixos_part}";',
        "    content = {",
    ]

    if cfg.fs_type == "btrfs":
        lines += [
            '      type = "btrfs";',
            '      extraArgs = [ "-f" ];',
            "      subvolumes = {",
            '        "/root" = {',
            '          mountpoint = "/";',
            '          mountOptions = [ "compress=zstd" ];',
            "        };",
            '        "/home" = {',
            '          mountpoint = "/home";',
            '          mountOptions = [ "compress=zstd" ];',
            "        };",
            '        "/nix" = {',
            '          mountpoint = "/nix";',
            '          mountOptions = [ "compress=zstd" "noatime" ];',
            "        };",
            '        "/log" = {',
            '          mountpoint = "/var/log";',
            '          mountOptions = [ "compress=zstd" ];',
            "        };",
        ]
        if cfg.swap_size != "0":
            lines += [
                '        "/swap" = {',
                '          mountpoint = "/swap";',
                "        };",
            ]
        lines += ["      };"]
    else:
        lines += [
            '      type = "filesystem";',
            '      format = "ext4";',
            '      mountpoint = "/";',
        ]

    lines += [
        "    };",
        "  };",
    ]

    if cfg.swap_size != "0" and cfg.fs_type == "ext4" and cfg.swap_partition:
        lines += [
            "",
            "  disko.devices.disk.swap = {",
            '    type = "disk";',
            f'    device = "{cfg.swap_partition}";',
            "    content = {",
            '      type = "swap";',
            '      discardPolicy = "both";',
            "      resumeDevice = true;",
            "    };",
            "  };",
        ]

    lines += [
        "",
        "  # Existing EFI partition — not managed by disko",
    ]

    if efi_uuid:
        lines += [
            '  fileSystems."/boot/efi" = {',
            f'    device = "/dev/disk/by-uuid/{efi_uuid}";',
            '    fsType = "vfat";',
            '    options = [ "fmask=0022" "dmask=0022" ];',
            "  };",
        ]
    else:
        lines += [
            '  fileSystems."/boot/efi" = {',
            f'    device = "{cfg.efi_part}";',
            '    fsType = "vfat";',
            '    options = [ "fmask=0022" "dmask=0022" ];',
            "  };",
        ]

    if cfg.swap_size != "0" and cfg.fs_type == "btrfs":
        lines += [
            "",
            "  swapDevices = [",
            '    { device = "/swap/swapfile"; }',
            "  ];",
        ]

    lines += ["}", ""]
    return "\n".join(lines)


def generate_host_default_nix(cfg: InstallConfig) -> str:
    """Generate complete host default.nix configuration."""
    bootloader_config = build_bootloader_config(cfg)
    profile_config = build_profile_config(cfg)
    features_config = build_features_override(cfg)
    gpu_config = build_gpu_config(cfg)

    blocks = []
    if bootloader_config:
        blocks.append(bootloader_config.rstrip())

    user_block = f"""  users.users.{cfg.username} = {{
    isNormalUser = true;
    description = "{cfg.username}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.{cfg.shell};
    hashedPassword = "{cfg.hashed_pw}";
  }};"""
    blocks.append(user_block)
    blocks.append(profile_config)

    if features_config:
        blocks.append(features_config)

    if gpu_config:
        blocks.append(gpu_config)

    body = "\n\n".join(blocks)

    return f"""{{
  config,
  lib,
  pkgs,
  ...
}}:

{{
  imports = [
    ./disko.nix
  ];

  home-manager.users.{cfg.username} = {{
    imports = [ ../../home ];
    home.username = lib.mkForce "{cfg.username}";
    home.homeDirectory = lib.mkForce "/home/{cfg.username}";
  }};

{body}

  networking.hostName = "{cfg.hostname}";
  system.stateVersion = "26.11";
}}
"""


# ════════════════════════════════════════════════════════════════
#  Execution Steps
# ════════════════════════════════════════════════════════════════

def do_generate_config(cfg: InstallConfig, work_dir: Path) -> None:
    """Write disko.nix and default.nix to host directory and stage in git."""
    host_dir = work_dir / "hosts" / cfg.hostname
    host_dir.mkdir(parents=True, exist_ok=True)

    if cfg.mode == InstallMode.WHOLE_DISK:
        disko_content = generate_disko_whole_disk(cfg)
    else:
        disko_content = generate_disko_partition_only(cfg)
    (host_dir / "disko.nix").write_text(disko_content)

    default_content = generate_host_default_nix(cfg)
    (host_dir / "default.nix").write_text(default_content)

    msg("Staging files for flake...")
    try:
        run("git add .", check=False)
    except Exception:
        warn("Not in a git repo, skipping git add.")


@retry(max_attempts=3, delay=5)
def do_partition(cfg: InstallConfig, work_dir: Path) -> None:
    """Partition and format disks using disko."""
    host_dir = work_dir / "hosts" / cfg.hostname

    msg("Partitioning with Disko...")
    run(f'nix run github:nix-community/disko -- --mode disko --flake ".#{cfg.hostname}"')

    if cfg.mode == InstallMode.PARTITION_ONLY:
        # Mount EFI partition (not managed by disko)
        os.makedirs("/mnt/boot/efi", exist_ok=True)
        if not is_mounted("/mnt/boot/efi"):
            msg(f"Mounting EFI partition {cfg.efi_part}...")
            run(f"mount {cfg.efi_part} /mnt/boot/efi")

        # Create swapfile for btrfs
        if cfg.swap_size != "0" and cfg.fs_type == "btrfs":
            swapfile = Path("/mnt/swap/swapfile")
            if swapfile.exists():
                msg("  Swapfile already exists, skipping.")
            else:
                msg(f"Creating {cfg.swap_size} btrfs swapfile...")
                run("chattr +C /mnt/swap", check=False)
                run("truncate -s 0 /mnt/swap/swapfile")
                run("chattr +C /mnt/swap/swapfile", check=False)
                run(f"fallocate -l {cfg.swap_size} /mnt/swap/swapfile")
                run("chmod 600 /mnt/swap/swapfile")
                run("mkswap /mnt/swap/swapfile")
                run("swapon /mnt/swap/swapfile")

        # Generate hardware.nix from the mounted system
        msg("Generating hardware configuration...")
        hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config")
        hw = strip_filesystems_from_hardware(hw)
        (host_dir / "hardware.nix").write_text(hw + "\n")

        try:
            run("git add .", check=False)
        except Exception:
            pass


@retry(max_attempts=3, delay=10)
def do_install_nixos(cfg: InstallConfig) -> None:
    """Run nixos-install."""
    msg(f"\nInstalling NixOS (host: {cfg.hostname})...")
    run(f'nixos-install --flake ".#{cfg.hostname}" --no-root-password')


@retry(max_attempts=3, delay=5)
def do_copy_flake(cfg: InstallConfig, work_dir: Path) -> None:
    """Copy flake to installed system. Idempotent — overwrites."""
    msg("\nCopying Northstar flake to installed system...")
    dest = Path(f"/mnt/home/{cfg.username}/northstar")
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(work_dir, dest, dirs_exist_ok=True)

    # Fresh git repo
    git_dir = dest / ".git"
    if git_dir.exists():
        shutil.rmtree(git_dir)
    run(
        f'cd {dest} && git init && git config user.name "Northstar Installer" '
        f'&& git config user.email "installer@northstar.local" && git add . '
        f'&& git commit -m "Initial Northstar configuration for {cfg.hostname}"'
    )

    # Fix ownership
    try:
        passwd = Path("/mnt/etc/passwd").read_text()
        for line in passwd.splitlines():
            fields = line.split(":")
            if fields[0] == cfg.username:
                uid, gid = fields[2], fields[3]
                run(f"chown -R {uid}:{gid} {dest}")
                msg(f"Flake saved to /home/{cfg.username}/northstar (UID {uid})")
                break
        else:
            warn(f"Could not find UID for {cfg.username}. After boot, run:")
            warn(f"  sudo chown -R {cfg.username}:{cfg.username} ~/northstar")
    except Exception:
        warn("Could not fix ownership. Fix after first boot.")


# ════════════════════════════════════════════════════════════════
#  Interactive Wizard CLI
# ════════════════════════════════════════════════════════════════

def interactive_wizard(script_dir: Path) -> None:
    ensure_nix_config()

    print(f"{CYAN}")
    print("  ❄️  Northstar NixOS Installer  ❄️")
    print("  =================================")
    print(f"{NC}")

    if os.geteuid() != 0:
        die("Please run as root")

    state = State()

    # Check for resume
    if state.current_step() != STEP_ORDER[0] and state.current_step() in STEP_ORDER:
        warn(f"Resuming from checkpoint: {state.current_step()}")
        ans = input("Continue from last checkpoint? [Y/n]: ").strip() or "Y"
        if ans.lower() != "y":
            state.clear()
            msg("Starting fresh.")

    cfg = InstallConfig()

    # 1. Hostname
    step("1/11", "Host Configuration")
    cfg.hostname = confirm_input(
        "Enter Target Hostname (e.g., Makima): ", "Hostname cannot be empty"
    )

    # 2. User & Password
    step("2/11", "User Configuration")
    cfg.username = confirm_input("Enter Username: ", "Username cannot be empty")
    print("\nEnter Password (will be hashed):")
    password = getpass.getpass("  Password: ")
    password2 = getpass.getpass("  Confirm:  ")
    if password != password2:
        die("Passwords do not match!")
    if not password:
        die("Password cannot be empty")
    msg("Hashing password...")
    cfg.hashed_pw = hash_password(password)

    # 3. Profile Selection
    step("3/11", "Profile Selection")
    print("Select base system profile bundle:")
    print("  1) Base        — Minimal CLI Server")
    print("  2) Desktop     — GUI + Compositors + Browsers (Default)")
    print("  3) Workstation — Desktop + Devtools + Virtualization")
    p_choice = input("Choice [2]: ").strip() or "2"
    if p_choice == "1":
        cfg.profile = ProfileChoice.BASE
    elif p_choice == "3":
        cfg.profile = ProfileChoice.WORKSTATION
    else:
        cfg.profile = ProfileChoice.DESKTOP
    cfg.features = default_features(cfg.profile)
    msg(f"Selected Profile: {cfg.profile}")

    # 4. Feature Customization
    step("4/11", "Feature Customization")
    print(f"Current features for profile {cfg.profile.value}:")
    for idx, f in enumerate(cfg.features, 1):
        status = f"{GREEN}[✓]{NC}" if f.enabled else f"{RED}[ ]{NC}"
        print(f"  {idx:2d}) {status} {f.label} ({f.category})")

    cust = input("\nCustomize individual features? [y/N]: ").strip().lower()
    if cust == "y":
        while True:
            t_str = input("Enter feature number to toggle (or Enter to finish): ").strip()
            if not t_str:
                break
            try:
                t_idx = int(t_str) - 1
                if 0 <= t_idx < len(cfg.features):
                    cfg.features[t_idx].enabled = not cfg.features[t_idx].enabled
                    f = cfg.features[t_idx]
                    status = f"{GREEN}enabled{NC}" if f.enabled else f"{RED}disabled{NC}"
                    print(f"  -> {f.label} is now {status}")
                else:
                    warn("Invalid feature index.")
            except ValueError:
                warn("Please enter a valid number.")

    # Determine default user shell
    fish_feat = next((f for f in cfg.features if f.id == "fish"), None)
    zsh_feat = next((f for f in cfg.features if f.id == "zsh"), None)
    if fish_feat and fish_feat.enabled and (not zsh_feat or not zsh_feat.enabled):
        cfg.shell = "fish"
    else:
        cfg.shell = "zsh"

    # 5. Bootloader Selection
    step("5/11", "Bootloader Selection")
    print("Select bootloader:")
    print("  1) GRUB   — Cyberpunk DedSec Theme (Default)")
    print("  2) Limine — Modern Ultra-Fast UEFI Bootloader")
    bl_choice = input("Choice [1]: ").strip() or "1"
    cfg.bootloader = BootloaderChoice.LIMINE if bl_choice == "2" else BootloaderChoice.GRUB
    msg(f"Selected Bootloader: {cfg.bootloader}")

    # Auto-detect hardware
    msg("\nScanning system hardware (disks, GPUs, ESPs)...")
    hw_info = detect_all()

    # 6. Installation Mode
    step("6/11", "Installation Mode")
    print("Select installation mode:")
    print(f"  {BOLD}1) Whole disk{NC} — fresh install, wipes entire disk")
    print(f"  {BOLD}2) Partition only{NC} — dual-boot, installs to a specific partition")
    m_choice = input("Choice [1]: ").strip() or "1"
    cfg.mode = InstallMode.PARTITION_ONLY if m_choice == "2" else InstallMode.WHOLE_DISK

    # 7. Disk & Partition Selection
    step("7/11", "Disk Selection")
    disks: list[DiskInfo] = hw_info["disks"]
    if disks:
        print("Detected Disks:")
        for idx, d in enumerate(disks, 1):
            print(f"  {idx}) /dev/{d.name} — {d.size} ({d.drive_type}, {d.model})")
        d_input = input("Select disk number or enter device name: ").strip()
        try:
            d_idx = int(d_input) - 1
            if 0 <= d_idx < len(disks):
                cfg.disk_dev = disks[d_idx].name
            else:
                cfg.disk_dev = d_input.replace("/dev/", "")
        except ValueError:
            cfg.disk_dev = d_input.replace("/dev/", "")
    else:
        cfg.disk_dev = confirm_input("Enter Target Disk Device (e.g. nvme0n1 or sda): ")

    if cfg.mode == InstallMode.WHOLE_DISK:
        err(f"WARNING: All data on /dev/{cfg.disk_dev} will be DESTROYED!")
        confirm_yes("Type 'yes' to confirm:")
    else:
        print(f"\n{YELLOW}Partitions on /dev/{cfg.disk_dev}:{NC}")
        run(f"lsblk -n -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS /dev/{cfg.disk_dev}", check=False)

        print("\nPartition action:")
        print("  1) Use an existing partition")
        print("  2) Create a new partition from unallocated space (parted)")
        p_act = input("Choice [1]: ").strip() or "1"
        if p_act == "2":
            if not shutil.which("parted"):
                die("parted is required but not installed.")
            start = input("Enter start position (e.g., 100GiB): ").strip()
            end = input("Enter end position (e.g., 200GiB or 100%): ").strip()
            if not start or not end:
                die("Start and end positions are required")
            warn(f"Creating partition from {start} to {end}...")
            run(f'parted -s /dev/{cfg.disk_dev} mkpart primary "{start}" "{end}"')
            time.sleep(2)
            run(f"partprobe /dev/{cfg.disk_dev}", check=False)
            time.sleep(1)
            part_name = run_capture(f"lsblk -n -l -o NAME /dev/{cfg.disk_dev} | tail -1")
            cfg.nixos_part = f"/dev/{part_name}"
            msg(f"Created: {cfg.nixos_part}")
        else:
            part_name = input("Enter NixOS partition device (e.g. nvme0n1p5): ").strip().replace("/dev/", "")
            cfg.nixos_part = f"/dev/{part_name}"

        err(f"WARNING: All data on {cfg.nixos_part} will be DESTROYED!")
        confirm_yes("Type 'yes' to confirm:")

        # EFI selection
        efi_parts = hw_info["efi_partitions"]
        if efi_parts:
            print("\nDetected EFI System Partitions:")
            for idx, (dev, size, uuid) in enumerate(efi_parts, 1):
                print(f"  {idx}) {dev} ({size}) [UUID: {uuid}]")
            efi_in = input("Select EFI partition [1]: ").strip() or "1"
            try:
                e_idx = int(efi_in) - 1
                if 0 <= e_idx < len(efi_parts):
                    cfg.efi_part = efi_parts[e_idx][0]
                else:
                    cfg.efi_part = efi_in
            except ValueError:
                cfg.efi_part = efi_in
        else:
            cfg.efi_part = confirm_input("Enter EFI partition device (e.g., /dev/nvme0n1p1): ")

    # 8. Filesystem, Swap, Root Size
    step("8/11", "Filesystem & Swap")
    print("Select root filesystem:")
    print("  1) btrfs (recommended — subvolumes for root, home, nix, log & swapfile)")
    print("  2) ext4  (standard filesystem)")
    fs_choice = input("Choice [1]: ").strip() or "1"
    cfg.fs_type = "ext4" if fs_choice == "2" else "btrfs"

    if cfg.mode == InstallMode.WHOLE_DISK:
        r_size = input("Root partition size [100%]: ").strip() or "100%"
        if r_size != "100%" and not re.match(r"^\d+[GMgm%]$", r_size):
            die("Invalid root size format. Use 200G, 50%, or 100%")
        cfg.root_size = r_size

    swap = input("Swap size [8G] (or 0 to disable): ").strip() or "8G"
    if swap != "0" and not re.match(r"^\d+[GMgm]$", swap):
        die("Invalid swap size format. Use 8G, 16G, or 0")
    cfg.swap_size = swap

    if cfg.mode == InstallMode.PARTITION_ONLY and cfg.fs_type == "ext4" and cfg.swap_size != "0":
        swap_part = input("Enter dedicated swap partition device (e.g. /dev/nvme0n1p6): ").strip()
        cfg.swap_partition = swap_part

    # 9. GPU Configuration
    step("9/11", "GPU Configuration")
    detected_gpu: GpuChoice = hw_info["gpu_choice"]
    print(f"Auto-detected GPU: {detected_gpu}")
    if detected_gpu == GpuChoice.NVIDIA_PRIME:
        print(f"  NVIDIA Bus ID: {hw_info['nvidia_bus_id']}")
        print(f"  iGPU ({hw_info['igpu_type']}) Bus ID: {hw_info['igpu_bus_id']}")
    elif detected_gpu == GpuChoice.NVIDIA:
        print(f"  NVIDIA Bus ID: {hw_info['nvidia_bus_id']}")

    print("\nSelect GPU setup:")
    print("  1) Auto-detected / None")
    print("  2) NVIDIA Discrete")
    print("  3) NVIDIA + Intel/AMD Hybrid (Prime)")
    g_choice = input("Choice [1]: ").strip() or "1"

    if g_choice == "1":
        cfg.gpu_choice = detected_gpu
        cfg.nvidia_bus_id = hw_info["nvidia_bus_id"] or ""
        cfg.igpu_bus_id = hw_info["igpu_bus_id"] or ""
        cfg.igpu_type = hw_info["igpu_type"]
    elif g_choice == "2":
        cfg.gpu_choice = GpuChoice.NVIDIA
        cfg.nvidia_bus_id = input(f"NVIDIA Bus ID [{hw_info['nvidia_bus_id'] or 'PCI:1:0:0'}]: ").strip() or (hw_info["nvidia_bus_id"] or "PCI:1:0:0")
    elif g_choice == "3":
        cfg.gpu_choice = GpuChoice.NVIDIA_PRIME
        cfg.nvidia_bus_id = input(f"NVIDIA Bus ID [{hw_info['nvidia_bus_id'] or 'PCI:1:0:0'}]: ").strip() or (hw_info["nvidia_bus_id"] or "PCI:1:0:0")
        ig_type_str = input("iGPU type: 1) Intel  2) AMD [1]: ").strip() or "1"
        cfg.igpu_type = IgpuType.AMD if ig_type_str == "2" else IgpuType.INTEL
        cfg.igpu_bus_id = input(f"iGPU Bus ID [{hw_info['igpu_bus_id'] or 'PCI:0:2:0'}]: ").strip() or (hw_info["igpu_bus_id"] or "PCI:0:2:0")

    # 10. Dual-Boot OSes
    step("10/11", "Dual-Boot OS Detection")
    detected_oses: list[DualBootEntry] = hw_info["detected_os"]
    if detected_oses:
        print("Detected other OSes on ESP:")
        for idx, os_entry in enumerate(detected_oses, 1):
            status = f"{GREEN}[✓]{NC}" if os_entry.enabled else f"{RED}[ ]{NC}"
            print(f"  {idx}) {status} {os_entry.name} ({os_entry.efi_path})")
        cfg.dual_boot_entries = detected_oses
    else:
        print("No other OS installations found on scanned ESPs.")

    # 11. Summary & Confirmation
    step("11/11", "Configuration Summary")
    print(f"  Hostname:     {cfg.hostname}")
    print(f"  Username:     {cfg.username}")
    print(f"  Profile:      {cfg.profile.value}")
    print(f"  Bootloader:   {cfg.bootloader.value}")
    print(f"  Mode:         {cfg.mode.value}")
    print(f"  Disk:         /dev/{cfg.disk_dev}")
    if cfg.mode == InstallMode.PARTITION_ONLY:
        print(f"  NixOS Part:   {cfg.nixos_part}")
        print(f"  EFI Part:     {cfg.efi_part}")
    print(f"  Filesystem:   {cfg.fs_type}")
    print(f"  Swap:         {cfg.swap_size}")
    print(f"  GPU:          {cfg.gpu_choice.value}")

    print()
    ans = input("Proceed with installation? [Y/n]: ").strip() or "Y"
    if ans.lower() != "y":
        die("Aborted.")

    # Execute Steps
    if not state.should_skip("generate_config"):
        do_generate_config(cfg, script_dir)
        state.set_step("partition")

    if not state.should_skip("partition"):
        do_partition(cfg, script_dir)
        state.set_step("install_nixos")

    if not state.should_skip("install_nixos"):
        do_install_nixos(cfg)
        state.set_step("copy_flake")

    if not state.should_skip("copy_flake"):
        do_copy_flake(cfg, script_dir)
        state.set_step("done")

    state.clear()

    print(f"\n{GREEN}✅ Installation Complete!{NC}")
    print(f"Your configuration has been saved to: {CYAN}/home/{cfg.username}/northstar{NC}")
    print("You can now reboot into your new Northstar system.")
    print(f"After rebooting, run: {CYAN}cd ~/northstar && sudo nixos-rebuild switch --flake .#{cfg.hostname}{NC}")
    print(f"Run: {CYAN}reboot{NC}")


def main() -> None:
    script_dir = Path(
        os.environ.get("NORTHSTAR_REMOTE", Path(__file__).resolve().parent.parent)
    )
    os.chdir(script_dir)
    interactive_wizard(script_dir)


if __name__ == "__main__":
    main()
