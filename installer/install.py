#!/usr/bin/env python3
"""
Northstar NixOS Installer — idempotent, resumable, with retries.

Provides full feature parity with Northstar Rust installer (installer-rs):
- Profiles (Base, Desktop, Workstation)
- 10 toggleable feature options and delta overrides
- Limine bootloader with display resolution detection
- Automated hardware detection (lspci GPU detection, lsblk -J disks, ESP scanning)
- Dual-boot detection and chainloader config generation
- Disko whole-disk and partition-only layout generation
- Host default.nix generation targeting NixOS 26.11
- Checkpoint-based state resume (/tmp/northstar-install-state.json)
"""

from __future__ import annotations

import argparse
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

STANDARD_RESOLUTIONS = [
    "3840x2160",
    "2560x1440",
    "1920x1080",
    "1680x1050",
    "1600x900",
    "1440x900",
    "1366x768",
    "1280x1024",
    "1280x800",
    "1280x720",
    "1024x768",
    "800x600",
    "640x480",
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
    LIMINE = "limine"

    def __str__(self) -> str:
        return "Limine (Modern Ultra-Fast UEFI)"


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
        FeatureOption(
            id="aiml",
            label="AI/ML Development Suite (PyTorch, Ollama, CUDA/ROCm)",
            category="Development & Virt",
            enabled=False,
        ),
    ]


@dataclass
class InstallConfig:
    hostname: str = ""
    username: str = ""
    user_fullname: str = ""
    user_password: str = ""
    hashed_pw: str = ""
    profile: ProfileChoice = ProfileChoice.DESKTOP
    shell: str = "zsh"
    bootloader: BootloaderChoice = BootloaderChoice.LIMINE
    secure_boot: bool = False
    resolution: str = "1920x1080"
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
    ssh_key_action: str = "generate"
    ssh_key_import_path: str = ""
    ssh_key_export_path: str = ""
    age_key_action: str = "derive"
    age_key_import_path: str = ""
    age_key_export_path: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Serialize InstallConfig to a plain JSON-compatible dictionary."""
        return {
            "hostname": self.hostname,
            "username": self.username,
            "user_fullname": self.user_fullname,
            "user_password": self.user_password,
            "hashed_pw": self.hashed_pw,
            "profile": self.profile.value if isinstance(self.profile, ProfileChoice) else str(self.profile),
            "shell": self.shell,
            "bootloader": self.bootloader.value if isinstance(self.bootloader, BootloaderChoice) else str(self.bootloader),
            "secure_boot": self.secure_boot,
            "resolution": self.resolution,
            "features": [
                {
                    "id": f.id,
                    "label": f.label,
                    "category": f.category,
                    "enabled": f.enabled,
                }
                for f in self.features
            ],
            "dual_boot_entries": [
                {
                    "name": e.name,
                    "efi_path": e.efi_path,
                    "disk_uuid": e.disk_uuid,
                    "enabled": e.enabled,
                }
                for e in self.dual_boot_entries
            ],
            "mode": self.mode.value if isinstance(self.mode, InstallMode) else str(self.mode),
            "disk_dev": self.disk_dev,
            "nixos_part": self.nixos_part,
            "efi_part": self.efi_part,
            "swap_size": self.swap_size,
            "swap_partition": self.swap_partition,
            "fs_type": self.fs_type,
            "root_size": self.root_size,
            "gpu_choice": self.gpu_choice.value if isinstance(self.gpu_choice, GpuChoice) else str(self.gpu_choice),
            "nvidia_bus_id": self.nvidia_bus_id,
            "igpu_bus_id": self.igpu_bus_id,
            "igpu_type": self.igpu_type.value if isinstance(self.igpu_type, IgpuType) else str(self.igpu_type),
            "ssh_key_action": self.ssh_key_action,
            "ssh_key_import_path": self.ssh_key_import_path,
            "ssh_key_export_path": self.ssh_key_export_path,
            "age_key_action": self.age_key_action,
            "age_key_import_path": self.age_key_import_path,
            "age_key_export_path": self.age_key_export_path,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> InstallConfig:
        """Losslessly reconstruct an InstallConfig from dictionary representation."""
        cfg = cls()
        if not isinstance(data, dict):
            return cfg

        cfg.hostname = str(data.get("hostname", cfg.hostname) or "")
        cfg.username = str(data.get("username", cfg.username) or "")
        cfg.user_fullname = str(data.get("user_fullname", cfg.user_fullname) or "")
        cfg.user_password = str(data.get("user_password", cfg.user_password) or "")
        cfg.hashed_pw = str(data.get("hashed_pw", cfg.hashed_pw) or "")

        p_val = data.get("profile", "Desktop")
        for p in ProfileChoice:
            if p.value.lower() == str(p_val).lower() or p.name.lower() == str(p_val).lower():
                cfg.profile = p
                break

        cfg.shell = str(data.get("shell", cfg.shell) or "zsh")

        bl_val = data.get("bootloader", "limine")
        cfg.bootloader = BootloaderChoice.LIMINE
        cfg.secure_boot = bool(data.get("secure_boot", False))
        cfg.resolution = str(data.get("resolution", "1920x1080") or "1920x1080")

        raw_feats = data.get("features")
        if isinstance(raw_feats, list) and raw_feats:
            feats = []
            for f in raw_feats:
                if isinstance(f, dict) and "id" in f:
                    feats.append(
                        FeatureOption(
                            id=str(f.get("id", "")),
                            label=str(f.get("label", "")),
                            category=str(f.get("category", "")),
                            enabled=bool(f.get("enabled", False)),
                        )
                    )
            if feats:
                cfg.features = feats

        raw_dbe = data.get("dual_boot_entries")
        if isinstance(raw_dbe, list):
            dbe = []
            for e in raw_dbe:
                if isinstance(e, dict) and "name" in e:
                    dbe.append(
                        DualBootEntry(
                            name=str(e.get("name", "")),
                            efi_path=str(e.get("efi_path", "")),
                            disk_uuid=str(e.get("disk_uuid", "")),
                            enabled=bool(e.get("enabled", True)),
                        )
                    )
            cfg.dual_boot_entries = dbe

        m_val = data.get("mode", "whole-disk")
        cfg.mode = InstallMode.PARTITION_ONLY if str(m_val).lower() == "partition-only" else InstallMode.WHOLE_DISK
        cfg.disk_dev = str(data.get("disk_dev", cfg.disk_dev) or "")
        cfg.nixos_part = str(data.get("nixos_part", cfg.nixos_part) or "")
        cfg.efi_part = str(data.get("efi_part", cfg.efi_part) or "")
        cfg.swap_size = str(data.get("swap_size", cfg.swap_size) or "8G")
        cfg.swap_partition = str(data.get("swap_partition", cfg.swap_partition) or "")
        cfg.fs_type = str(data.get("fs_type", cfg.fs_type) or "btrfs")
        cfg.root_size = str(data.get("root_size", cfg.root_size) or "100%")

        g_val = data.get("gpu_choice", "none")
        for g in GpuChoice:
            if g.value.lower() == str(g_val).lower() or g.name.lower() == str(g_val).lower():
                cfg.gpu_choice = g
                break
        cfg.nvidia_bus_id = str(data.get("nvidia_bus_id", cfg.nvidia_bus_id) or "")
        cfg.igpu_bus_id = str(data.get("igpu_bus_id", cfg.igpu_bus_id) or "")
        ig_val = data.get("igpu_type", "intel")
        cfg.igpu_type = IgpuType.AMD if str(ig_val).lower() == "amd" else IgpuType.INTEL

        cfg.ssh_key_action = str(data.get("ssh_key_action", cfg.ssh_key_action) or "generate")
        cfg.ssh_key_import_path = str(data.get("ssh_key_import_path", cfg.ssh_key_import_path) or "")
        cfg.ssh_key_export_path = str(data.get("ssh_key_export_path", cfg.ssh_key_export_path) or "")
        cfg.age_key_action = str(data.get("age_key_action", cfg.age_key_action) or "derive")
        cfg.age_key_import_path = str(data.get("age_key_import_path", cfg.age_key_import_path) or "")
        cfg.age_key_export_path = str(data.get("age_key_export_path", cfg.age_key_export_path) or "")

        return cfg


# ── State Management ─────────────────────────────────────────────
class State:
    """Persistent state with full InstallConfig checkpointing and resume."""

    def __init__(self, state_file: Optional[Path] = None) -> None:
        self.state_file = Path(state_file) if state_file else STATE_FILE
        self.data: dict[str, Any] = {}
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

    def save(self, config: Optional[InstallConfig] = None) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        if config is not None:
            self.data["config"] = config.to_dict()
        try:
            temp_file = self.state_file.with_suffix(".tmp")
            temp_file.write_text(json.dumps(self.data, indent=2), encoding="utf-8")
            try:
                os.chmod(temp_file, 0o600)
            except OSError:
                pass
            os.replace(temp_file, self.state_file)
            try:
                os.chmod(self.state_file, 0o600)
            except OSError:
                pass
        except OSError:
            pass

    def get(self, key: str, default: Any = None) -> Any:
        if not isinstance(self.data, dict):
            self.data = {}
        return self.data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data[key] = value
        self.save()

    def set_config(self, cfg: InstallConfig) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data["config"] = cfg.to_dict()
        self.save()

    def get_config(self) -> Optional[InstallConfig]:
        if not isinstance(self.data, dict):
            self.data = {}
        cfg_data = self.data.get("config")
        if isinstance(cfg_data, dict) and cfg_data:
            return InstallConfig.from_dict(cfg_data)
        return None

    def load_config(self) -> Optional[InstallConfig]:
        return self.get_config()

    def set_step(self, step_name: str) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data["step"] = step_name
        completed = self.data.get("completed_steps")
        if not isinstance(completed, list):
            completed = []
        if step_name in STEP_ORDER:
            idx = STEP_ORDER.index(step_name)
            for s in STEP_ORDER[:idx]:
                if s not in completed:
                    completed.append(s)
        self.data["completed_steps"] = completed
        self.save()

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


def parse_resolution_string(s: str) -> Optional[tuple[int, int]]:
    """Parse a resolution string like '1920x1080', '1920,1080', or 'U:1920x1080p-0'."""
    s = s.strip()
    if not s:
        return None
    m = re.search(r"(\d{3,5})[xX,\s]+(\d{3,5})", s)
    if m:
        try:
            w, h = int(m.group(1)), int(m.group(2))
            if 640 <= w <= 16384 and 480 <= h <= 16384:
                return (w, h)
        except ValueError:
            pass
    return None


def detect_display_resolutions(
    drm_path: Path = Path("/sys/class/drm"),
    fb_path: Path = Path("/sys/class/graphics"),
) -> list[str]:
    """
    Auto-detect available display resolutions from Linux DRM sysfs and framebuffer devices.
    Deduplicates, sorts descending by pixel count (and dimensions), and falls back to STANDARD_RESOLUTIONS.
    """
    found_pairs: set[tuple[int, int]] = set()

    # 1. Probe /sys/class/drm/*/modes
    if drm_path.exists():
        try:
            for connector_dir in drm_path.iterdir():
                if not connector_dir.is_dir():
                    continue
                status_file = connector_dir / "status"
                if status_file.exists():
                    try:
                        status = status_file.read_text(encoding="utf-8", errors="replace").strip()
                        if status != "connected":
                            continue
                    except (OSError, UnicodeDecodeError):
                        pass
                modes_file = connector_dir / "modes"
                if modes_file.exists() and modes_file.is_file():
                    try:
                        content = modes_file.read_text(encoding="utf-8", errors="replace")
                        for line in content.splitlines():
                            res = parse_resolution_string(line)
                            if res:
                                found_pairs.add(res)
                    except (OSError, UnicodeDecodeError):
                        pass
        except (OSError, PermissionError):
            pass

    # 2. Probe /sys/class/graphics/fb*/virtual_size or modes
    if fb_path.exists():
        try:
            for fb_dir in fb_path.iterdir():
                if not fb_dir.is_dir() or not fb_dir.name.startswith("fb"):
                    continue
                for fname in ["virtual_size", "mode", "modes"]:
                    fpath = fb_dir / fname
                    if fpath.exists() and fpath.is_file():
                        try:
                            content = fpath.read_text(encoding="utf-8", errors="replace")
                            for line in content.splitlines():
                                res = parse_resolution_string(line)
                                if res:
                                    found_pairs.add(res)
                        except (OSError, UnicodeDecodeError):
                            pass
        except (OSError, PermissionError):
            pass

    if found_pairs:
        sorted_pairs = sorted(found_pairs, key=lambda p: (p[0] * p[1], p[0], p[1]), reverse=True)
        return [f"{w}x{h}" for w, h in sorted_pairs]

    return list(STANDARD_RESOLUTIONS)


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
        "resolutions": [],
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

    # 4. Detect Display Resolutions
    try:
        detected["resolutions"] = detect_display_resolutions()
    except Exception:
        detected["resolutions"] = list(STANDARD_RESOLUTIONS)

    return detected


# ── Extra Entries Formatters ────────────────────────────────────




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
    """Build the bootloader configuration block with dual boot, resolution and secure boot."""
    lines: list[str] = ["  # Bootloader (Limine)"]
    res = getattr(cfg, "resolution", "") or "1920x1080"
    lines.append(f'  boot.loader.limine.resolution = "{res}";')
    if getattr(cfg, "secure_boot", False):
        lines.append("  northstar.features.boot.secureBoot.enable = true;")
    extra = format_limine_extra_entries(cfg.dual_boot_entries)
    if extra:
        lines.append(extra)
    return "\n".join(lines) + "\n"


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
            feat_key = "development.aiml" if f.id in ("aiml", "development.aiml") else f.id
            overrides.append(f"    {feat_key}.enable = {val_str};")

    if not overrides:
        return ""

    return "  # Custom feature overrides\n  northstar.features = {\n" + "\n".join(overrides) + "\n  };"


def strip_filesystems_from_hardware(hw_text: str) -> str:
    """Strip fileSystems.*, swapDevices entries, and autogenerated '#' comments from hardware.nix output,
    ensuring hardware.graphics and firmware settings are present."""
    if not hw_text.strip():
        return ""

    cleaned_lines = []
    in_fs_block = False
    fs_depth = 0
    in_swap_devices = False

    for line in hw_text.splitlines():
        stripped = line.strip()

        # Strip autogenerated comment lines
        if stripped.startswith("#"):
            continue

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

    # Ensure hardware graphics and firmware settings exist if not already present
    if "hardware.graphics" not in result and "graphics.enable" not in result:
        hw_block = "  hardware = {\n    graphics.enable = lib.mkDefault true;\n    firmware = [ pkgs.linux-firmware ];\n  };\n"
        if result.rstrip().endswith("}"):
            idx = result.rfind("}")
            result = result[:idx] + hw_block + result[idx:]
        else:
            result += "\n" + hw_block

    while "\n\n\n" in result:
        result = result.replace("\n\n\n", "\n\n")
    return result.strip()


def escape_nix_string(s: str) -> str:
    """Escape a string for safe embedding in a Nix double-quoted string literal.

    Only escapes characters that are actually special in Nix string literals:
    - backslash (\\) — escape character
    - double-quote (") — string delimiter
    - dollar-brace (${) — interpolation trigger
    Bare $ (e.g. in SHA-512 hashes like $6$salt$hash) is NOT special and must NOT be escaped.
    """
    if not isinstance(s, str):
        return str(s)
    return s.replace('\\', '\\\\').replace('"', '\\"').replace('${', '\\${')

def generate_disko_whole_disk(cfg: InstallConfig) -> str:
    """Generate disko.nix content for whole-disk mode."""
    lines = [
        f"# Auto-generated disko config for {cfg.hostname}",
        "{ lib, ... }:",
        "",
        "let",
        "  northstar = import ../../lib/core.nix { inherit lib; };",
        "in",
        "northstar.mkDisko {",
        '  mode = "whole-disk";',
        f'  device = "/dev/{cfg.disk_dev}";',
        f'  fsType = "{cfg.fs_type}";',
        '  efiSize = "4G";',
    ]
    if getattr(cfg, "extra_disko_config", ""):
        lines.append(f"  extraConfig = {cfg.extra_disko_config};")

    lines.append(f'  swapSize = "{cfg.swap_size}";')

    if cfg.root_size != "100%":
        lines.append(f'  rootSize = "{cfg.root_size}";')

    lines.extend([
        "}",
        "",
    ])
    return "\n".join(lines)


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

    u = escape_nix_string(cfg.username)
    user_block = f"""  users.users.{u} = {{
    isNormalUser = true;
    description = "{u}";
    extraGroups = [
      "networkmanager"
      "wheel"
      "libvirtd"
      "docker"
    ];
    shell = pkgs.{cfg.shell};
    hashedPassword = "{escape_nix_string(cfg.hashed_pw)}";
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
    ./hardware.nix
    ./disko.nix
  ];

  home-manager.users.{u} = {{
    imports = [ ../../home/home.nix ];
    home.username = lib.mkForce "{u}";
    home.homeDirectory = lib.mkForce "/home/{u}";
  }};

{body}

  networking.hostName = "{escape_nix_string(cfg.hostname)}";
  system.stateVersion = "26.11";
}}
"""


# ════════════════════════════════════════════════════════════════
#  Execution Steps & Lifecycle Helpers
# ════════════════════════════════════════════════════════════════

def ensure_mounted(cfg: InstallConfig) -> None:
    """
    Verify and ensure that target filesystems are properly mounted at /mnt
    before performing nixos-install or post-install steps on resume.
    """
    msg("Checking target mount status (/mnt)...")
    if is_mounted("/mnt"):
        msg("  /mnt is already mounted.")
        if cfg.efi_part and not is_mounted("/mnt/boot/efi") and not is_mounted("/mnt/boot"):
            os.makedirs("/mnt/boot/efi", exist_ok=True)
            try:
                run(f"mount {cfg.efi_part} /mnt/boot/efi", check=False)
            except Exception:
                pass
        return

    warn("  /mnt is not mounted. Mounting target filesystems...")

    # Try Disko mount mode first if whole-disk
    if cfg.mode == InstallMode.WHOLE_DISK:
        try:
            res = run(
                f'nix run github:nix-community/disko -- --mode mount --flake ".#{cfg.hostname}"',
                check=False,
            )
            if res.returncode == 0 and is_mounted("/mnt"):
                msg("  Successfully mounted target with Disko.")
                return
        except Exception:
            pass

    # Fallback manual mounting
    target_part = cfg.nixos_part if cfg.mode == InstallMode.PARTITION_ONLY else f"/dev/{cfg.disk_dev}2"
    if not os.path.exists(target_part) and cfg.disk_dev:
        p_prefix = "p" if "nvme" in cfg.disk_dev or "mmcblk" in cfg.disk_dev else ""
        candidate = f"/dev/{cfg.disk_dev}{p_prefix}2"
        if os.path.exists(candidate):
            target_part = candidate

    os.makedirs("/mnt", exist_ok=True)
    if cfg.fs_type == "btrfs":
        run(f"mount -o compress=zstd,subvol=/root {target_part} /mnt", check=False)
        if not is_mounted("/mnt"):
            run(f"mount -o compress=zstd,subvol=root {target_part} /mnt", check=False)

        for subvol, mountp in [
            ("home", "/mnt/home"),
            ("nix", "/mnt/nix"),
            ("log", "/mnt/var/log"),
            ("swap", "/mnt/swap"),
        ]:
            os.makedirs(mountp, exist_ok=True)
            if not is_mounted(mountp):
                run(f"mount -o compress=zstd,subvol=/{subvol} {target_part} {mountp}", check=False)
                if not is_mounted(mountp):
                    run(f"mount -o compress=zstd,subvol={subvol} {target_part} {mountp}", check=False)

        if Path("/mnt/swap/swapfile").exists():
            run("swapon /mnt/swap/swapfile", check=False)
    else:
        run(f"mount {target_part} /mnt", check=False)
        if cfg.swap_partition and os.path.exists(cfg.swap_partition):
            run(f"swapon {cfg.swap_partition}", check=False)

    # Mount EFI partition
    efi_dev = cfg.efi_part
    if not efi_dev and cfg.disk_dev:
        p_prefix = "p" if "nvme" in cfg.disk_dev or "mmcblk" in cfg.disk_dev else ""
        candidate_efi = f"/dev/{cfg.disk_dev}{p_prefix}1"
        if os.path.exists(candidate_efi):
            efi_dev = candidate_efi

    if efi_dev and os.path.exists(efi_dev):
        os.makedirs("/mnt/boot/efi", exist_ok=True)
        if not is_mounted("/mnt/boot/efi"):
            run(f"mount {efi_dev} /mnt/boot/efi", check=False)

    if not is_mounted("/mnt"):
        warn("Could not automatically remount /mnt. nixos-install may fail if mounts are missing.")
    else:
        msg("  Target mounts established.")


class MemoryProtector:
    """
    Context manager that dynamically provisions temporary compressed ZRAM swap
    (or fallback swapfile) before memory-intensive stages (nixos-install) to prevent
    Linux OOM-killer terminations, and guarantees cleanup on exit.
    """

    def __init__(self, target_size: str = "4G") -> None:
        self.target_size = target_size
        self.zram_dev: Optional[str] = None
        self.swapfile_path: Optional[Path] = None
        self.enabled = False

    @staticmethod
    def get_system_memory_mb() -> tuple[int, int]:
        """Return (mem_total_mb, swap_total_mb) from /proc/meminfo."""
        mem_total_kb = 0
        swap_total_kb = 0
        try:
            meminfo = Path("/proc/meminfo").read_text(encoding="utf-8")
            for line in meminfo.splitlines():
                if line.startswith("MemTotal:"):
                    mem_total_kb = int(line.split()[1])
                elif line.startswith("SwapTotal:"):
                    swap_total_kb = int(line.split()[1])
        except Exception:
            pass
        return (mem_total_kb // 1024, swap_total_kb // 1024)

    def start(self) -> bool:
        """Attempt to provision temporary ZRAM or swapfile."""
        if self.enabled:
            return True

        mem_mb, swap_mb = self.get_system_memory_mb()
        msg(f"Memory check: {mem_mb} MB RAM, {swap_mb} MB active swap.")

        # 1. Try ZRAM via zramctl
        try:
            run("modprobe zram", check=False)
            if shutil.which("zramctl"):
                res = run(
                    f"zramctl --find --size {self.target_size} --algorithm zstd",
                    capture=True,
                    check=False,
                )
                dev = res.stdout.strip() if res.returncode == 0 else ""
                if dev and dev.startswith("/dev/zram"):
                    run(f"mkswap {dev}", check=True)
                    run(f"swapon -p 32767 {dev}", check=True)
                    self.zram_dev = dev
                    self.enabled = True
                    msg(f"  Dynamic ZRAM memory protection active: {self.target_size} on {dev} (zstd).")
                    return True
        except Exception as e:
            warn(f"  ZRAM provisioning via zramctl failed: {e}")

        # 2. Try direct /dev/zram0 fallback
        try:
            zram0 = Path("/sys/block/zram0")
            if zram0.exists():
                run("echo 1 > /sys/block/zram0/reset", check=False)
                run("echo zstd > /sys/block/zram0/comp_algorithm", check=False)
                run(f"echo {self.target_size} > /sys/block/zram0/disksize", check=True)
                run("mkswap /dev/zram0", check=True)
                run("swapon -p 32767 /dev/zram0", check=True)
                self.zram_dev = "/dev/zram0"
                self.enabled = True
                msg(f"  Dynamic ZRAM memory protection active: {self.target_size} on /dev/zram0.")
                return True
        except Exception as e:
            warn(f"  Direct /dev/zram0 configuration failed: {e}")

        # 3. Fallback: Temporary swapfile in /tmp
        try:
            swap_path = Path(f"/tmp/northstar-temp-swap-{os.getpid()}.swap")
            msg(f"  Creating temporary fallback swapfile at {swap_path}...")
            alloc_res = run(f"fallocate -l 2G {swap_path}", check=False)
            if alloc_res.returncode != 0:
                run(f"dd if=/dev/zero of={swap_path} bs=1M count=2048", check=True)
            run(f"chmod 600 {swap_path}", check=True)
            run(f"mkswap {swap_path}", check=True)
            run(f"swapon -p 100 {swap_path}", check=True)
            self.swapfile_path = swap_path
            self.enabled = True
            msg("  Temporary fallback swapfile active (2G).")
            return True
        except Exception as e:
            warn(f"  Temporary swapfile creation failed: {e}. Continuing without extra swap.")
            return False

    def stop(self) -> None:
        """Tear down and clean up any provisioned swap/ZRAM."""
        if not self.enabled:
            return

        msg("Cleaning up temporary memory protection...")
        if self.zram_dev:
            try:
                run(f"swapoff {self.zram_dev}", check=False)
                if shutil.which("zramctl"):
                    run(f"zramctl --reset {self.zram_dev}", check=False)
                else:
                    dev_name = Path(self.zram_dev).name
                    run(f"echo 1 > /sys/block/{dev_name}/reset", check=False)
                msg(f"  ZRAM device {self.zram_dev} released.")
            except Exception as e:
                warn(f"  Failed to reset ZRAM device {self.zram_dev}: {e}")
            self.zram_dev = None

        if self.swapfile_path:
            try:
                run(f"swapoff {self.swapfile_path}", check=False)
                if self.swapfile_path.exists():
                    self.swapfile_path.unlink()
                msg("  Temporary swapfile removed.")
            except Exception as e:
                warn(f"  Failed to clean up temporary swapfile {self.swapfile_path}: {e}")
            self.swapfile_path = None

        self.enabled = False

    def __enter__(self) -> MemoryProtector:
        self.start()
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.stop()


def detect_keys(target_root: Path = Path("/mnt")) -> dict[str, Any]:
    """Detect existing SSH host/user keys and Age secret keys on target system."""
    detected: dict[str, list[str]] = {
        "ssh_host_keys": [],
        "ssh_user_keys": [],
        "age_keys": [],
    }
    # Check /mnt/etc/ssh
    ssh_dir = target_root / "etc" / "ssh"
    if ssh_dir.exists():
        for key in ssh_dir.glob("ssh_host_*_key"):
            if not key.name.endswith(".pub"):
                detected["ssh_host_keys"].append(str(key))
    # Check /mnt/home/*/.ssh
    home_dir = target_root / "home"
    if home_dir.exists():
        for user_ssh in home_dir.glob("*/.ssh"):
            for key in user_ssh.glob("id_*"):
                if not key.name.endswith(".pub"):
                    detected["ssh_user_keys"].append(str(key))
    # Check /mnt/var/lib/sops-nix/key.txt
    age_key = target_root / "var" / "lib" / "sops-nix" / "key.txt"
    if age_key.exists():
        detected["age_keys"].append(str(age_key))

    return detected


def setup_ssh_keys(cfg: InstallConfig, target_root: Path = Path("/mnt")) -> None:
    """Setup, generate, or import SSH host and user keys."""
    if cfg.ssh_key_action == "none":
        return

    ssh_dir = target_root / "etc" / "ssh"
    ssh_dir.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(ssh_dir, 0o755)
    except OSError:
        pass

    host_priv = ssh_dir / "ssh_host_ed25519_key"
    host_pub = ssh_dir / "ssh_host_ed25519_key.pub"

    if cfg.ssh_key_action == "generate":
        msg("Generating Ed25519 SSH host key...")
        if host_priv.exists():
            try:
                host_priv.unlink()
            except OSError:
                pass
        if host_pub.exists():
            try:
                host_pub.unlink()
            except OSError:
                pass
        run(f'ssh-keygen -t ed25519 -N "" -f {host_priv} -C "root@{cfg.hostname}"')
        try:
            os.chmod(host_priv, 0o600)
            if host_pub.exists():
                os.chmod(host_pub, 0o644)
        except OSError:
            pass

        # User key
        if cfg.username:
            user_ssh = target_root / "home" / cfg.username / ".ssh"
            user_ssh.mkdir(parents=True, exist_ok=True)
            try:
                os.chmod(user_ssh, 0o700)
            except OSError:
                pass
            user_priv = user_ssh / "id_ed25519"
            user_pub = user_ssh / "id_ed25519.pub"
            if not user_priv.exists():
                msg(f"Generating Ed25519 SSH user key for {cfg.username}...")
                run(f'ssh-keygen -t ed25519 -N "" -f {user_priv} -C "{cfg.username}@{cfg.hostname}"')
                try:
                    os.chmod(user_priv, 0o600)
                    if user_pub.exists():
                        os.chmod(user_pub, 0o644)
                except OSError:
                    pass

    elif cfg.ssh_key_action == "import" and cfg.ssh_key_import_path:
        src = Path(cfg.ssh_key_import_path)
        if src.is_dir():
            msg(f"Importing SSH keys from directory {src}...")
            for f in src.glob("*"):
                shutil.copy2(f, ssh_dir / f.name)
            if host_priv.exists():
                try:
                    os.chmod(host_priv, 0o600)
                except OSError:
                    pass
        elif src.is_file():
            msg(f"Importing SSH host key from {src}...")
            shutil.copy2(src, host_priv)
            try:
                os.chmod(host_priv, 0o600)
            except OSError:
                pass
            src_pub = Path(str(src) + ".pub")
            if src_pub.exists():
                shutil.copy2(src_pub, host_pub)
                try:
                    os.chmod(host_pub, 0o644)
                except OSError:
                    pass
        else:
            warn(f"Specified SSH key import path {src} does not exist, skipping.")


def setup_age_keys(cfg: InstallConfig, target_root: Path = Path("/mnt")) -> None:
    """Generate, derive, or import Age secret key for sops-nix."""
    if cfg.age_key_action == "none":
        return

    sops_dir = target_root / "var" / "lib" / "sops-nix"
    sops_dir.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(sops_dir, 0o700)
    except OSError:
        pass

    age_key_file = sops_dir / "key.txt"
    host_priv = target_root / "etc" / "ssh" / "ssh_host_ed25519_key"

    if age_key_file.exists() and age_key_file.stat().st_size > 0:
        msg(f"Age key already exists at {age_key_file}, reusing existing key.")
        try:
            os.chmod(age_key_file, 0o600)
        except OSError:
            pass
        return

    if cfg.age_key_action == "derive":
        if host_priv.exists() and shutil.which("ssh-to-age"):
            msg("Deriving Age key from SSH host key (ssh-to-age)...")
            derived = run_capture(f"ssh-to-age -private-key -i {host_priv}")
            age_key_file.write_text(derived.strip() + "\n")
            try:
                os.chmod(age_key_file, 0o600)
            except OSError:
                pass
        elif shutil.which("age-keygen"):
            msg("Generating Age key via age-keygen (ssh-to-age unavailable)...")
            if age_key_file.exists():
                try:
                    age_key_file.unlink()
                except OSError:
                    pass
            run(f"age-keygen -o {age_key_file}")
            try:
                os.chmod(age_key_file, 0o600)
            except OSError:
                pass
    elif cfg.age_key_action == "generate":
        if shutil.which("age-keygen"):
            msg("Generating fresh Age key via age-keygen...")
            if age_key_file.exists():
                try:
                    age_key_file.unlink()
                except OSError:
                    pass
            run(f"age-keygen -o {age_key_file}")
            try:
                os.chmod(age_key_file, 0o600)
            except OSError:
                pass
    elif cfg.age_key_action == "import" and cfg.age_key_import_path:
        src = Path(cfg.age_key_import_path)
        if src.exists() and src.is_file():
            msg(f"Importing Age key from {src}...")
            shutil.copy2(src, age_key_file)
            try:
                os.chmod(age_key_file, 0o600)
            except OSError:
                pass
        else:
            warn(f"Specified Age key import path {src} does not exist, skipping.")


def export_keys_backup(cfg: InstallConfig, target_root: Path = Path("/mnt")) -> None:
    """Backup generated or imported SSH/Age keys to external destination."""
    dest_path = cfg.ssh_key_export_path or cfg.age_key_export_path
    if not dest_path:
        return

    try:
        backup_dir = Path(dest_path) / f"northstar-keys-{cfg.hostname}"
        backup_dir.mkdir(parents=True, exist_ok=True)

        host_ssh_dir = target_root / "etc" / "ssh"
        if host_ssh_dir.exists():
            shutil.copytree(host_ssh_dir, backup_dir / "ssh", dirs_exist_ok=True)
            if cfg.username:
                user_ssh = target_root / "home" / cfg.username / ".ssh"
                if user_ssh.exists():
                    shutil.copytree(user_ssh, backup_dir / f"user_{cfg.username}_ssh", dirs_exist_ok=True)

            host_priv = host_ssh_dir / "ssh_host_ed25519_key"
            host_pub = host_ssh_dir / "ssh_host_ed25519_key.pub"
            if host_priv.exists():
                shutil.copy2(host_priv, backup_dir / f"{cfg.hostname}_ssh_host_ed25519_key")
            if host_pub.exists():
                shutil.copy2(host_pub, backup_dir / f"{cfg.hostname}_ssh_host_ed25519_key.pub")

        age_key = target_root / "var" / "lib" / "sops-nix" / "key.txt"
        if age_key.exists():
            (backup_dir / "age").mkdir(parents=True, exist_ok=True)
            shutil.copy2(age_key, backup_dir / "age" / "key.txt")
            shutil.copy2(age_key, backup_dir / f"{cfg.hostname}_age_key.txt")

        msg(f"Exported key backup to {backup_dir}")
    except Exception as e:
        warn(f"Failed to export keys backup: {e}")


def do_setup_keys(cfg: InstallConfig, target_root: Path = Path("/mnt")) -> None:
    """Run full SSH & Age key setup lifecycle."""
    setup_ssh_keys(cfg, target_root)
    setup_age_keys(cfg, target_root)
    export_keys_backup(cfg, target_root)


def do_generate_config(cfg: InstallConfig, work_dir: Path) -> None:
    """Write disko.nix, default.nix, and stub hardware.nix to host directory and stage in git."""
    host_dir = work_dir / "hosts" / cfg.hostname
    host_dir.mkdir(parents=True, exist_ok=True)

    if cfg.mode == InstallMode.WHOLE_DISK:
        disko_content = generate_disko_whole_disk(cfg)
    else:
        disko_content = generate_disko_partition_only(cfg)
    (host_dir / "disko.nix").write_text(disko_content)

    default_content = generate_host_default_nix(cfg)
    (host_dir / "default.nix").write_text(default_content)

    # Stub hardware.nix to satisfy discoverHosts and mkHostModules during initial Disko evaluation
    hw_stub = """{ config, lib, pkgs, ... }:

{
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware = {
    graphics.enable = lib.mkDefault true;
    firmware = [ pkgs.linux-firmware ];
  };
}
"""
    hw_file = host_dir / "hardware.nix"
    if not hw_file.exists():
        hw_file.write_text(hw_stub)

    msg("Staging generated files for flake...")
    try:
        run("git add -A", check=False)
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

    # Generate real hardware.nix from the mounted system
    msg("Generating hardware configuration...")
    try:
        hw = run_capture("nixos-generate-config --root /mnt --show-hardware-config")
        hw = strip_filesystems_from_hardware(hw)
        (host_dir / "hardware.nix").write_text(hw + "\n")
        run("git add -A", check=False)
    except Exception as e:
        warn(f"Could not generate hardware.nix: {e}")


@retry(max_attempts=3, delay=10)
def do_install_nixos(cfg: InstallConfig) -> None:
    """Run nixos-install with memory protection, mount verification, and key setup."""
    ensure_mounted(cfg)
    do_setup_keys(cfg, Path("/mnt"))
    msg(f"\nInstalling NixOS (host: {cfg.hostname})...")
    with MemoryProtector():
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
        f'&& git config user.email "installer@northstar.local" && git add -A '
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


def _execute_install_steps(cfg: InstallConfig, state: State, script_dir: Path) -> None:
    """Run the step-by-step installation execution pipeline with checkpointing."""
    state.set_config(cfg)

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


# ════════════════════════════════════════════════════════════════
#  Interactive Wizard CLI
# ════════════════════════════════════════════════════════════════

def interactive_wizard(script_dir: Path, resume: bool = False, no_root_check: bool = False) -> None:
    ensure_nix_config()

    print(f"{CYAN}")
    print("  ❄️  Northstar NixOS Installer  ❄️")
    print("  =================================")
    print(f"{NC}")

    if not no_root_check and os.geteuid() != 0:
        die("Please run as root")

    state = State()

    # Check for resume
    resumed_cfg = state.get_config()
    if state.current_step() != STEP_ORDER[0] and state.current_step() in STEP_ORDER and resumed_cfg is not None:
        warn(f"Found saved installation checkpoint at step: {state.current_step()}")
        if resume:
            ans = "y"
        else:
            ans = input("Continue from last checkpoint? [Y/n]: ").strip() or "Y"
        if ans.lower() == "y":
            cfg = resumed_cfg
            msg("\nResuming installation with saved configuration:")
            print(f"  Hostname:     {cfg.hostname}")
            print(f"  Username:     {cfg.username}")
            print(f"  Profile:      {cfg.profile.value}")
            print(f"  Bootloader:   {cfg.bootloader.value}")
            print(f"  Resolution:   {cfg.resolution}")
            print(f"  Secure Boot:  {cfg.secure_boot}")
            print(f"  Mode:         {cfg.mode.value}")
            print(f"  Disk:         /dev/{cfg.disk_dev}")
            print(f"  Step:         {state.current_step()}")
            print()
            _execute_install_steps(cfg, state, script_dir)
            return
        else:
            state.clear()
            msg("Starting fresh.")
    elif state.current_step() != STEP_ORDER[0] and state.current_step() in STEP_ORDER:
        warn(f"Found previous step checkpoint: {state.current_step()}")
        ans = input("Continue from last checkpoint? [Y/n]: ").strip() or "Y"
        if ans.lower() != "y":
            state.clear()
            msg("Starting fresh.")

    cfg = InstallConfig()

    # 1. Hostname
    step("1/12", "Host Configuration")
    cfg.hostname = confirm_input(
        "Enter Target Hostname (e.g., Makima): ", "Hostname cannot be empty"
    )

    # 2. User & Password
    step("2/12", "User Configuration")
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
    step("3/12", "Profile Selection")
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
    step("4/12", "Feature Customization")
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

    # Auto-detect hardware
    msg("\nScanning system hardware (disks, GPUs, ESPs, display modes)...")
    hw_info = detect_all()

    # 5. Bootloader & Security Selection
    step("5/12", "Bootloader & Display")
    cfg.bootloader = BootloaderChoice.LIMINE
    msg("Bootloader: Limine (Modern Ultra-Fast UEFI)")

    detected_res = hw_info.get("resolutions") or detect_display_resolutions()
    print("\nSelect Limine display resolution:")
    for r_idx, res_str in enumerate(detected_res[:8], 1):
        tag = " (Detected / Native)" if r_idx == 1 else ""
        print(f"  {r_idx}) {res_str}{tag}")
    res_choice = input("Choice [1] or enter custom WIDTHxHEIGHT: ").strip() or "1"
    try:
        r_num = int(res_choice) - 1
        if 0 <= r_num < len(detected_res):
            cfg.resolution = detected_res[r_num]
        else:
            cfg.resolution = res_choice
    except ValueError:
        cfg.resolution = res_choice
    msg(f"Limine Resolution set to: {cfg.resolution}")

    sb_ans = input("\nEnable UEFI Secure Boot with Lanzaboote? [y/N]: ").strip().lower()
    cfg.secure_boot = sb_ans == "y"
    if cfg.secure_boot:
        msg("UEFI Secure Boot (Lanzaboote) enabled.")

    # 6. SSH & Age Key Management
    step("6/12", "SSH & Age Key Management")
    print("Select SSH Host Key Action:")
    print("  1) Generate fresh Ed25519 host/user keys (Default)")
    print("  2) Import existing SSH keys from file/directory")
    print("  3) Keep existing keys on target filesystem")
    print("  4) None (Skip SSH key setup)")
    ssh_act = input("Choice [1]: ").strip() or "1"
    if ssh_act == "2":
        cfg.ssh_key_action = "import"
        cfg.ssh_key_import_path = confirm_input("Enter path to SSH key file/directory: ")
    elif ssh_act == "3":
        cfg.ssh_key_action = "keep"
    elif ssh_act == "4":
        cfg.ssh_key_action = "none"
    else:
        cfg.ssh_key_action = "generate"
    msg(f"SSH Key Action: {cfg.ssh_key_action}")

    print("\nSelect Age Secret Key Action (sops-nix):")
    print("  1) Derive from SSH host key (ssh-to-age) (Default)")
    print("  2) Generate fresh Age key (age-keygen)")
    print("  3) Import existing Age key")
    print("  4) Keep existing key on target filesystem")
    print("  5) None (Skip Age key setup)")
    age_act = input("Choice [1]: ").strip() or "1"
    if age_act == "2":
        cfg.age_key_action = "generate"
    elif age_act == "3":
        cfg.age_key_action = "import"
        cfg.age_key_import_path = confirm_input("Enter path to Age key file: ")
    elif age_act == "4":
        cfg.age_key_action = "keep"
    elif age_act == "5":
        cfg.age_key_action = "none"
    else:
        cfg.age_key_action = "derive"
    msg(f"Age Key Action: {cfg.age_key_action}")

    key_bk = input("\nEnter external directory to backup keys (or Enter to skip): ").strip()
    if key_bk:
        cfg.ssh_key_export_path = key_bk
        cfg.age_key_export_path = key_bk
        msg(f"Key backup destination: {key_bk}")

    # 7. Installation Mode
    step("7/12", "Installation Mode")
    print("Select installation mode:")
    print(f"  {BOLD}1) Whole disk{NC} — fresh install, wipes entire disk")
    print(f"  {BOLD}2) Partition only{NC} — dual-boot, installs to a specific partition")
    m_choice = input("Choice [1]: ").strip() or "1"
    cfg.mode = InstallMode.PARTITION_ONLY if m_choice == "2" else InstallMode.WHOLE_DISK

    # 8. Disk & Partition Selection
    step("8/12", "Disk Selection")
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

    # 9. Filesystem, Swap, Root Size
    step("9/12", "Filesystem & Swap")
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

    swap = input("Swap size [16G] (or 0 to disable): ").strip() or "16G"
    if swap != "0" and not re.match(r"^\d+[GMgm]$", swap):
        die("Invalid swap size format.")
    cfg.swap_size = swap

    if cfg.mode == InstallMode.PARTITION_ONLY and cfg.fs_type == "ext4" and cfg.swap_size != "0":
        swap_part = input("Enter dedicated swap partition device (e.g. /dev/nvme0n1p6): ").strip()
        cfg.swap_partition = swap_part

    # 10. GPU Configuration
    step("10/12", "GPU Configuration")
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

    # 11. Custom Partitioning & Dual-Boot
    step("11/12", "Custom Partitioning & Dual-Boot")
    print("Advanced Custom Partitioning (Disko):")
    print("  You can optionally provide raw Nix code to merge into your disko config (extraConfig).")
    print("  Leave blank to use standard generated layouts.")
    cfg.extra_disko_config = input("  extraConfig [None]: ").strip()

    detected_oses: list[DualBootEntry] = hw_info.get("detected_os", [])
    if detected_oses:
        print("Detected other OSes on ESP:")
        for idx, os_entry in enumerate(detected_oses, 1):
            status = f"{GREEN}[✓]{NC}" if os_entry.enabled else f"{RED}[ ]{NC}"
            print(f"  {idx}) {status} {os_entry.name} ({os_entry.efi_path})")
        cfg.dual_boot_entries = detected_oses
    else:
        print("No other OS installations found on scanned ESPs.")

    # 12. Summary & Confirmation
    step("12/12", "Configuration Summary")
    print(f"  Hostname:     {cfg.hostname}")
    print(f"  Username:     {cfg.username}")
    print(f"  Profile:      {cfg.profile.value}")
    print(f"  Bootloader:   {cfg.bootloader.value}")
    if cfg.bootloader == BootloaderChoice.LIMINE:
        print(f"  Resolution:   {cfg.resolution}")
    print(f"  Secure Boot:  {cfg.secure_boot}")
    print(f"  Mode:         {cfg.mode.value}")
    print(f"  Disk:         /dev/{cfg.disk_dev}")
    if cfg.mode == InstallMode.PARTITION_ONLY:
        print(f"  NixOS Part:   {cfg.nixos_part}")
        print(f"  EFI Part:     {cfg.efi_part}")
    print(f"  Filesystem:   {cfg.fs_type}")
    print(f"  Swap:         {cfg.swap_size}")
    print(f"  GPU:          {cfg.gpu_choice.value}")
    print(f"  SSH Keys:     {cfg.ssh_key_action}")
    print(f"  Age Key:      {cfg.age_key_action}")
    if cfg.ssh_key_export_path or cfg.age_key_export_path:
        print(f"  Key Backup:   {cfg.ssh_key_export_path or cfg.age_key_export_path}")

    print()
    ans = input("Proceed with installation? [Y/n]: ").strip() or "Y"
    if ans.lower() != "y":
        die("Aborted.")

    # Execute Steps
    _execute_install_steps(cfg, state, script_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description="Northstar NixOS Installer")
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Resume installation from last checkpoint without prompting",
    )
    parser.add_argument(
        "--no-root-check",
        action="store_true",
        help="Bypass root user check (for testing)",
    )
    args, _ = parser.parse_known_args()

    script_dir = Path(
        os.environ.get("NORTHSTAR_REMOTE", Path(__file__).resolve().parent.parent)
    )
    os.chdir(script_dir)
    interactive_wizard(
        script_dir,
        resume=args.resume,
        no_root_check=args.no_root_check or bool(os.environ.get("NORTHSTAR_TEST")),
    )


if __name__ == "__main__":
    main()
