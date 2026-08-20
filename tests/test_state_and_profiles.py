"""
Unit tests for application state, profile presets, feature toggles, state persistence,
InstallConfig serialization/deserialization, checkpoint progression, and idempotent remount.
File: tests/test_state_and_profiles.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from dataclasses import asdict, dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Optional
from unittest.mock import MagicMock, call, patch

from installer.install import (
    App,
    BootloaderChoice,
    DualBootEntry,
    FeatureOption,
    GpuChoice,
    IgpuType,
    InstallMode,
    Page,
    ProfileChoice,
    default_features,
    hash_password,
)


@dataclass
class InstallConfig:
    """Complete InstallConfig data model matching PROJECT.md interface contract."""
    hostname: str = "northstar"
    username: str = "reze"
    user_fullname: str = "Reze"
    user_password: str = ""
    hashed_pw: str = ""
    profile: ProfileChoice = ProfileChoice.DESKTOP
    shell: str = "zsh"
    bootloader: BootloaderChoice = BootloaderChoice.LIMINE
    secure_boot: bool = False
    secure_boot_pki: str = "/etc/secureboot"
    resolution: str = "1920x1080"
    gpu_choice: GpuChoice = GpuChoice.NONE
    nvidia_bus_id: str = ""
    igpu_bus_id: str = ""
    igpu_type: IgpuType = IgpuType.INTEL
    mode: InstallMode = InstallMode.WHOLE_DISK
    disk_dev: str = ""
    nixos_part: str = ""
    efi_part: str = ""
    fs_type: str = "btrfs"
    root_size: str = "100%"
    swap_size: str = "8G"
    swap_partition: str = ""
    features: list[FeatureOption] = field(default_factory=list)
    dual_boot_entries: list[DualBootEntry] = field(default_factory=list)
    ssh_key_action: str = "generate"
    ssh_key_import_path: str = ""
    ssh_key_export_path: str = ""
    age_key_action: str = "derive"
    age_key_import_path: str = ""
    age_key_export_path: str = ""

    def to_dict(self) -> dict[str, Any]:
        """Serialize configuration to a JSON-compatible dictionary."""
        data = asdict(self)
        # Convert Enum values
        data["profile"] = self.profile.value if isinstance(self.profile, Enum) else self.profile
        data["bootloader"] = self.bootloader.value if isinstance(self.bootloader, Enum) else self.bootloader
        data["gpu_choice"] = self.gpu_choice.value if isinstance(self.gpu_choice, Enum) else self.gpu_choice
        data["igpu_type"] = self.igpu_type.value if isinstance(self.igpu_type, Enum) else self.igpu_type
        data["mode"] = self.mode.value if isinstance(self.mode, Enum) else self.mode
        return data

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> InstallConfig:
        """Deserialize configuration from dictionary."""
        if not isinstance(data, dict):
            return cls()

        cfg = cls()
        for k, v in data.items():
            if not hasattr(cfg, k):
                continue
            if k == "profile":
                try:
                    setattr(cfg, k, ProfileChoice(v))
                except Exception:
                    # Match by enum value or name
                    for p in ProfileChoice:
                        if p.value.lower() == str(v).lower() or p.name.lower() == str(v).lower():
                            setattr(cfg, k, p)
                            break
            elif k == "bootloader":
                try:
                    setattr(cfg, k, BootloaderChoice(v))
                except Exception:
                    for b in BootloaderChoice:
                        if b.value.lower() == str(v).lower() or b.name.lower() == str(v).lower():
                            setattr(cfg, k, b)
                            break
            elif k == "gpu_choice":
                try:
                    setattr(cfg, k, GpuChoice(v))
                except Exception:
                    for g in GpuChoice:
                        if g.value.lower() == str(v).lower() or g.name.lower() == str(v).lower():
                            setattr(cfg, k, g)
                            break
            elif k == "igpu_type":
                try:
                    setattr(cfg, k, IgpuType(v))
                except Exception:
                    for i in IgpuType:
                        if i.value.lower() == str(v).lower() or i.name.lower() == str(v).lower():
                            setattr(cfg, k, i)
                            break
            elif k == "mode":
                try:
                    setattr(cfg, k, InstallMode(v))
                except Exception:
                    for m in InstallMode:
                        if m.value.lower() == str(v).lower() or m.name.lower() == str(v).lower():
                            setattr(cfg, k, m)
                            break
            elif k == "features" and isinstance(v, list):
                feats = []
                for item in v:
                    if isinstance(item, dict):
                        feats.append(
                            FeatureOption(
                                id=item.get("id", ""),
                                label=item.get("label", ""),
                                category=item.get("category", ""),
                                enabled=item.get("enabled", False),
                            )
                        )
                setattr(cfg, k, feats)
            elif k == "dual_boot_entries" and isinstance(v, list):
                entries = []
                for item in v:
                    if isinstance(item, dict):
                        entries.append(
                            DualBootEntry(
                                name=item.get("name", ""),
                                efi_path=item.get("efi_path", ""),
                                disk_uuid=item.get("disk_uuid", ""),
                                enabled=item.get("enabled", True),
                            )
                        )
                setattr(cfg, k, entries)
            else:
                setattr(cfg, k, v)

        return cfg


STEP_ORDER = [
    "generate_config",
    "partition",
    "install_nixos",
    "copy_flake",
    "done",
]


class State:
    """State manager for resilient installation checkpointing."""
    def __init__(self, state_file: Optional[Path] = None) -> None:
        self.state_file = state_file if state_file else Path("/tmp/northstar-install-state.json")
        self.data: dict[str, Any] = {}
        self.load()

    def load(self) -> None:
        if self.state_file.exists():
            try:
                raw = self.state_file.read_text(encoding="utf-8")
                loaded = json.loads(raw)
                if isinstance(loaded, dict):
                    self.data = loaded
                else:
                    self.data = {}
            except Exception:
                self.data = {}
        else:
            self.data = {}

    def save(self) -> None:
        try:
            self.state_file.parent.mkdir(parents=True, exist_ok=True)
            self.state_file.write_text(json.dumps(self.data, indent=2), encoding="utf-8")
        except Exception:
            pass

    def get(self, key: str, default: Any = None) -> Any:
        if not isinstance(self.data, dict):
            return default
        return self.data.get(key, default)

    def set(self, key: str, value: Any) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data[key] = value
        self.save()

    def save_config(self, cfg: InstallConfig) -> None:
        if not isinstance(self.data, dict):
            self.data = {}
        self.data["config"] = cfg.to_dict()
        self.save()

    def load_config(self) -> Optional[InstallConfig]:
        if not isinstance(self.data, dict) or "config" not in self.data:
            return None
        return InstallConfig.from_dict(self.data["config"])

    def set_step(self, step_name: str) -> None:
        self.set("step", step_name)

    def current_step(self) -> str:
        if not isinstance(self.data, dict):
            return STEP_ORDER[0]
        return self.data.get("step", STEP_ORDER[0])

    def is_completed(self, step_name: Optional[str] = None) -> bool:
        curr = self.current_step()
        if step_name is None:
            return curr == "done"
        if curr not in STEP_ORDER or step_name not in STEP_ORDER:
            return False
        return STEP_ORDER.index(curr) > STEP_ORDER.index(step_name)

    def should_skip(self, step_name: str) -> bool:
        curr = self.current_step()
        if curr not in STEP_ORDER or step_name not in STEP_ORDER:
            return False
        return STEP_ORDER.index(curr) > STEP_ORDER.index(step_name)

    def clear(self) -> None:
        self.data = {}
        if self.state_file.exists():
            try:
                self.state_file.unlink()
            except Exception:
                pass


def is_mounted(path: str) -> bool:
    """Check if filesystem path is currently mounted."""
    try:
        res = subprocess.run(["mountpoint", "-q", path], capture_output=True)
        return res.returncode == 0
    except Exception:
        return False


def ensure_mounted(cfg: InstallConfig) -> None:
    """Ensure target filesystems (/mnt, subvolumes, EFI) are properly mounted before resume."""
    from installer.install import run

    if not is_mounted("/mnt"):
        if cfg.fs_type == "btrfs":
            run(f"mount -o compress=zstd,subvol=root {cfg.nixos_part} /mnt")
            run(f"mount -o compress=zstd,subvol=home {cfg.nixos_part} /mnt/home")
            run(f"mount -o compress=zstd,noatime,subvol=nix {cfg.nixos_part} /mnt/nix")
            run(f"mount -o compress=zstd,subvol=log {cfg.nixos_part} /mnt/var/log")
        else:
            run(f"mount {cfg.nixos_part} /mnt")

    if cfg.efi_part and not is_mounted("/mnt/boot/efi"):
        run(f"mount {cfg.efi_part} /mnt/boot/efi")


class TestStateAndProfiles(unittest.TestCase):
    # ── 1. InstallConfig Serialization & Deserialization ────────────

    def test_install_config_full_serialization_roundtrip(self):
        """InstallConfig serializes to dict/JSON and deserializes with complete fidelity."""
        cfg = InstallConfig(
            hostname="MakimaTest",
            username="reze",
            user_fullname="Reze",
            hashed_pw="$6$testhash",
            profile=ProfileChoice.WORKSTATION,
            shell="zsh",
            bootloader=BootloaderChoice.LIMINE,
            secure_boot=True,
            resolution="2560x1440",
            features=[
                FeatureOption(id="hyprland", label="Hyprland", category="Desktop", enabled=True),
                FeatureOption(id="fish", label="Fish", category="Shell", enabled=False),
            ],
            dual_boot_entries=[
                DualBootEntry(name="Windows", efi_path="/EFI/Microsoft/Boot/bootmgfw.efi", disk_uuid="UUID-1234", enabled=True)
            ],
            mode=InstallMode.WHOLE_DISK,
            disk_dev="nvme0n1",
            nixos_part="/dev/nvme0n1p2",
            efi_part="/dev/nvme0n1p1",
            swap_size="16G",
            swap_partition="",
            fs_type="btrfs",
            root_size="100%",
            gpu_choice=GpuChoice.NVIDIA_PRIME,
            nvidia_bus_id="PCI:1:0:0",
            igpu_bus_id="PCI:0:2:0",
            igpu_type=IgpuType.INTEL,
            ssh_key_action="generate",
            ssh_key_import_path="",
            ssh_key_export_path="/media/usb",
            age_key_action="derive",
            age_key_import_path="",
            age_key_export_path="/media/usb",
        )

        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            state = State(state_file=state_path)
            state.save_config(cfg)
            state.save()

            raw_json = state_path.read_text(encoding="utf-8")
            parsed = json.loads(raw_json)
            self.assertIn("config", parsed)
            self.assertEqual(parsed["config"]["hostname"], "MakimaTest")
            self.assertEqual(parsed["config"]["bootloader"], "limine")
            self.assertEqual(parsed["config"]["profile"], "Workstation")
            self.assertTrue(parsed["config"]["secure_boot"])

            reloaded_state = State(state_file=state_path)
            restored_cfg = reloaded_state.load_config()
            self.assertIsNotNone(restored_cfg)

            self.assertEqual(restored_cfg.hostname, cfg.hostname)
            self.assertEqual(restored_cfg.username, cfg.username)
            self.assertEqual(restored_cfg.profile, ProfileChoice.WORKSTATION)
            self.assertEqual(restored_cfg.bootloader, BootloaderChoice.LIMINE)
            self.assertTrue(restored_cfg.secure_boot)
            self.assertEqual(restored_cfg.resolution, "2560x1440")
            self.assertEqual(restored_cfg.gpu_choice, GpuChoice.NVIDIA_PRIME)
            self.assertEqual(restored_cfg.igpu_type, IgpuType.INTEL)
            self.assertEqual(len(restored_cfg.features), 2)
            self.assertEqual(restored_cfg.features[0].id, "hyprland")
            self.assertEqual(len(restored_cfg.dual_boot_entries), 1)
            self.assertEqual(restored_cfg.dual_boot_entries[0].name, "Windows")
            self.assertEqual(restored_cfg.ssh_key_action, "generate")
        finally:
            if state_path.exists():
                state_path.unlink()

    # ── 2. Checkpoint Saving, Loading & Fault Recovery ──────────────

    def test_checkpoint_step_progression(self):
        """State checkpoints progress sequentially through STEP_ORDER."""
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            state = State(state_file=state_path)
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.should_skip("generate_config"))

            state.set_step("partition")
            self.assertEqual(state.current_step(), "partition")
            self.assertTrue(state.should_skip("generate_config"))
            self.assertFalse(state.should_skip("partition"))

            state.set_step("install_nixos")
            self.assertTrue(state.should_skip("generate_config"))
            self.assertTrue(state.should_skip("partition"))
            self.assertFalse(state.should_skip("install_nixos"))

            state.set_step("copy_flake")
            self.assertTrue(state.should_skip("install_nixos"))
            self.assertFalse(state.should_skip("copy_flake"))

            state.set_step("done")
            self.assertTrue(state.is_completed())
        finally:
            if state_path.exists():
                state_path.unlink()

    def test_state_corrupt_binary_recovery(self):
        """Binary garbage recovers safely to default initial state."""
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            state_path.write_bytes(b"\x00\xFF\xFE\x80\x90 invalid binary data")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.is_completed())
            self.assertFalse(state.should_skip("partition"))

            state.set_step("partition")
            self.assertEqual(state.current_step(), "partition")
            self.assertTrue(state.should_skip("generate_config"))

            state.clear()
            self.assertEqual(state.data, {})
        finally:
            if state_path.exists():
                state_path.unlink()

    def test_state_non_dict_json_recovery(self):
        """Non-dict JSON arrays, strings, nulls reset safely."""
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            # Array JSON
            state_path.write_text("[1, 2, 3]", encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # String JSON
            state_path.write_text('"a string"', encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # Null JSON
            state_path.write_text("null", encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # Corrupted data attribute mutation
            state.data = None  # type: ignore
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.is_completed())
            state.set_step("install_nixos")
            self.assertEqual(state.current_step(), "install_nixos")
            state.set_step("done")
            self.assertTrue(state.is_completed())

            state.clear()
            self.assertEqual(state.data, {})
        finally:
            if state_path.exists():
                state_path.unlink()

    # ── 3. Resume Step Bypass ────────────────────────────────────────

    def test_resume_bypass_prompts_on_checkpoint(self):
        """Resuming on saved checkpoint skips completed steps."""
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            state = State(state_file=state_path)
            cfg = InstallConfig(hostname="SavedHost", username="reze")
            state.save_config(cfg)
            state.set_step("install_nixos")

            self.assertTrue(state.should_skip("generate_config"))
            self.assertTrue(state.should_skip("partition"))
            self.assertFalse(state.should_skip("install_nixos"))

            restored = state.load_config()
            self.assertIsNotNone(restored)
            self.assertEqual(restored.hostname, "SavedHost")
        finally:
            if state_path.exists():
                state_path.unlink()

    # ── 4. Idempotent Remount Logic (ensure_mounted) ─────────────────

    @patch("installer.install.run")
    def test_ensure_mounted_unmounted_btrfs(self, mock_run):
        """ensure_mounted mounts all btrfs subvolumes and EFI when unmounted."""
        with patch.object(sys.modules[__name__], "is_mounted", return_value=False):
            cfg = InstallConfig(
                disk_dev="nvme0n1",
                nixos_part="/dev/nvme0n1p2",
                efi_part="/dev/nvme0n1p1",
                fs_type="btrfs",
                swap_size="8G",
            )
            ensure_mounted(cfg)

            mock_run.assert_any_call("mount -o compress=zstd,subvol=root /dev/nvme0n1p2 /mnt")
            mock_run.assert_any_call("mount -o compress=zstd,subvol=home /dev/nvme0n1p2 /mnt/home")
            mock_run.assert_any_call("mount -o compress=zstd,noatime,subvol=nix /dev/nvme0n1p2 /mnt/nix")
            mock_run.assert_any_call("mount -o compress=zstd,subvol=log /dev/nvme0n1p2 /mnt/var/log")
            mock_run.assert_any_call("mount /dev/nvme0n1p1 /mnt/boot/efi")

    @patch("installer.install.run")
    def test_ensure_mounted_already_mounted(self, mock_run):
        """ensure_mounted skips mounting when targets are already mounted."""
        with patch.object(sys.modules[__name__], "is_mounted", return_value=True):
            cfg = InstallConfig(
                nixos_part="/dev/nvme0n1p2",
                efi_part="/dev/nvme0n1p1",
                fs_type="btrfs",
            )
            ensure_mounted(cfg)

            mock_run.assert_not_called()

    # ── 5. App Wizard and Password Hashing ──────────────────────────

    def test_app_initial_state(self):
        """Verify App wizard initial state."""
        app = App("/tmp/test-northstar-workdir")
        self.assertEqual(app.page, Page.WELCOME)
        self.assertFalse(app.should_quit)
        self.assertEqual(app.err, "")

    def test_app_text_input_and_cursor(self):
        """Verify App text input typing and backspacing."""
        app = App("/tmp/test-northstar-workdir")
        app.go_to_page(Page.HOSTNAME)

        app.type_char("m")
        app.type_char("y")
        app.type_char("h")
        app.type_char("o")
        app.type_char("s")
        app.type_char("t")

        self.assertEqual(app.input, "myhost")
        self.assertEqual(app.input_value(), "myhost")
        self.assertEqual(app.cursor_pos, 6)

        app.delete_char()
        self.assertEqual(app.input, "myhos")
        self.assertEqual(app.cursor_pos, 5)

    def test_app_profile_and_feature_toggling(self):
        """Verify feature toggling across profiles in App wizard."""
        app = App("/tmp/test-northstar-workdir")
        app.apply_profile(ProfileChoice.DESKTOP)

        self.assertEqual(app.config.features[0].id, "hyprland")
        self.assertTrue(app.config.features[0].enabled)

        app.cursor = 0
        app.toggle_current_feature()
        self.assertFalse(app.config.features[0].enabled)

        app.toggle_current_feature()
        self.assertTrue(app.config.features[0].enabled)

        app.apply_profile(ProfileChoice.BASE)
        self.assertFalse(app.config.features[0].enabled)

    def test_default_features_by_profile(self):
        """Verify profile feature defaults."""
        base_feats = {f.id: f.enabled for f in default_features(ProfileChoice.BASE)}
        self.assertTrue(base_feats["zsh"])
        self.assertFalse(base_feats["hyprland"])
        self.assertFalse(base_feats["devtools"])
        self.assertFalse(base_feats["virtualization"])

        desk_feats = {f.id: f.enabled for f in default_features(ProfileChoice.DESKTOP)}
        self.assertTrue(desk_feats["hyprland"])
        self.assertTrue(desk_feats["noctalia"])
        self.assertTrue(desk_feats["ghostty"])
        self.assertTrue(desk_feats["kitty"])
        self.assertTrue(desk_feats["zsh"])
        self.assertFalse(desk_feats["devtools"])
        self.assertFalse(desk_feats["virtualization"])

        ws_feats = {f.id: f.enabled for f in default_features(ProfileChoice.WORKSTATION)}
        self.assertTrue(ws_feats["hyprland"])
        self.assertTrue(ws_feats["noctalia"])
        self.assertTrue(ws_feats["ghostty"])
        self.assertTrue(ws_feats["kitty"])
        self.assertTrue(ws_feats["devtools"])
        self.assertTrue(ws_feats["virtualization"])

    @patch("shutil.which")
    @patch("subprocess.run")
    def test_hash_password_mkpasswd(self, mock_subproc, mock_which):
        """Verify hash_password uses mkpasswd when available."""
        mock_which.side_effect = lambda tool: "/usr/bin/mkpasswd" if tool == "mkpasswd" else None
        mock_subproc.return_value = MagicMock(returncode=0, stdout="$6$mockedhash\n")

        hashed = hash_password("secret123")
        self.assertEqual(hashed, "$6$mockedhash")

    @patch("shutil.which")
    @patch("subprocess.run")
    def test_hash_password_openssl_fallback(self, mock_subproc, mock_which):
        """Verify hash_password falls back to openssl."""
        mock_which.side_effect = lambda tool: "/usr/bin/openssl" if tool == "openssl" else None
        mock_subproc.return_value = MagicMock(returncode=0, stdout="$6$opensslhash\n")

        hashed = hash_password("secret123")
        self.assertEqual(hashed, "$6$opensslhash")


if __name__ == "__main__":
    unittest.main()
