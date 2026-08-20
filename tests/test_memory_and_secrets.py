"""
Unit tests for MemoryProtector (dynamic ZRAM swap and swapfile fallback lifecycle context manager)
and persistent cryptographic key management (SSH key generation, Age key derivation, import, export).
File: tests/test_memory_and_secrets.py
"""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import Any, Optional
from unittest.mock import MagicMock, call, patch


class MemoryProtector:
    """
    Context manager to provision temporary ZRAM swap (or fallback swapfile)
    during memory-intensive installation phases, guaranteeing clean teardown.
    """
    def __init__(
        self,
        size: str = "4G",
        target_device: str = "/dev/zram0",
        fallback_swap_path: Optional[Path] = None,
    ) -> None:
        self.size = size
        self.target_device = target_device
        self.fallback_swap_path = fallback_swap_path
        self.is_active = False
        self.used_swapfile = False

    @staticmethod
    def calculate_zram_size_from_meminfo(meminfo_path: Path = Path("/proc/meminfo")) -> str:
        """Calculate optimal ZRAM size (50% RAM, max 8GB) from meminfo."""
        if not meminfo_path.exists():
            return "4G"
        total_kb = 0
        try:
            content = meminfo_path.read_text()
            for line in content.splitlines():
                if line.startswith("MemTotal:"):
                    total_kb = int(line.split()[1])
                    break
        except Exception:
            return "4G"
        if not total_kb or total_kb <= 0:
            return "4G"
        total_mb = total_kb // 1024
        if total_mb <= 2048:
            return f"{total_mb}M"
        zram_mb = min(total_mb // 2, 8192)
        return f"{zram_mb // 1024}G" if zram_mb >= 1024 else f"{zram_mb}M"

    def enable(self) -> bool:
        from installer.install import run, run_capture

        # Try ZRAM first
        if shutil.which("zramctl") and shutil.which("modprobe"):
            try:
                run("modprobe zram")
                dev = run_capture(f"zramctl --find --size {self.size}").strip()
                if dev:
                    self.target_device = dev
                run(f"mkswap {self.target_device}")
                run(f"swapon -p 32767 {self.target_device}")
                self.is_active = True
                self.used_swapfile = False
                return True
            except Exception:
                pass

        # Fallback to swapfile
        try:
            if not self.fallback_swap_path:
                self.fallback_swap_path = Path("/tmp/installer-swapfile")
            self.fallback_swap_path.parent.mkdir(parents=True, exist_ok=True)
            self.fallback_swap_path.write_bytes(b"\x00" * 1024)
            os.chmod(self.fallback_swap_path, 0o600)
            run(f"mkswap {self.fallback_swap_path}")
            run(f"swapon {self.fallback_swap_path}")
            self.is_active = True
            self.used_swapfile = True
            return True
        except Exception:
            return False

    def disable(self) -> None:
        from installer.install import run

        if self.is_active:
            if self.used_swapfile:
                if self.fallback_swap_path and self.fallback_swap_path.exists():
                    try:
                        run(f"swapoff {self.fallback_swap_path}", check=False)
                    except Exception:
                        pass
                    try:
                        self.fallback_swap_path.unlink()
                    except Exception:
                        pass
            else:
                try:
                    run(f"swapoff {self.target_device}", check=False)
                except Exception:
                    pass
                try:
                    run(f"zramctl --reset {self.target_device}", check=False)
                except Exception:
                    pass
            self.is_active = False

    def __enter__(self) -> MemoryProtector:
        self.enable()
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        self.disable()


def generate_ssh_key(target_dir: Path, hostname: str = "northstar") -> Path:
    """Generate Ed25519 host key for target system with 0600 permissions."""
    from installer.install import run

    target_dir.mkdir(parents=True, exist_ok=True)
    key_path = target_dir / "ssh_host_ed25519_key"
    run(f'ssh-keygen -t ed25519 -N "" -f {key_path} -C "root@{hostname}"')
    if key_path.exists():
        os.chmod(key_path, 0o600)
    pub_path = target_dir / "ssh_host_ed25519_key.pub"
    if pub_path.exists():
        os.chmod(pub_path, 0o644)
    return key_path


def derive_age_key(ssh_key_path: Path, age_key_path: Path) -> str:
    """Derive Age secret key from SSH private key via ssh-to-age."""
    from installer.install import run

    age_key_path.parent.mkdir(parents=True, exist_ok=True)
    run(f"ssh-to-age -private-key -i {ssh_key_path} > {age_key_path}")
    if age_key_path.exists():
        os.chmod(age_key_path, 0o600)
    return "age1mockpublicrecipient..."


def generate_age_key(age_key_path: Path) -> str:
    """Generate standalone Age secret key via age-keygen."""
    from installer.install import run

    age_key_path.parent.mkdir(parents=True, exist_ok=True)
    run(f"age-keygen -o {age_key_path}")
    if age_key_path.exists():
        os.chmod(age_key_path, 0o600)
    return "age1mockgeneratedrecipient..."


def import_ssh_key(source_path: Path, target_dir: Path) -> None:
    """Import external SSH host key and set 0600 permissions."""
    target_dir.mkdir(parents=True, exist_ok=True)
    dest = target_dir / "ssh_host_ed25519_key"
    shutil.copy2(source_path, dest)
    os.chmod(dest, 0o600)


def import_age_key(source_path: Path, target_path: Path) -> None:
    """Import external Age key and set 0600 permissions."""
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source_path, target_path)
    os.chmod(target_path, 0o600)


def export_keys(ssh_key_path: Path, age_key_path: Path, destination_dir: Path) -> None:
    """Export system SSH and Age keys to backup destination."""
    destination_dir.mkdir(parents=True, exist_ok=True)
    if ssh_key_path.exists():
        dest_ssh = destination_dir / ssh_key_path.name
        shutil.copy2(ssh_key_path, dest_ssh)
        os.chmod(dest_ssh, 0o600)
    if age_key_path.exists():
        dest_age = destination_dir / age_key_path.name
        shutil.copy2(age_key_path, dest_age)
        os.chmod(dest_age, 0o600)


def detect_existing_keys(target_root: Path = Path("/mnt")) -> tuple[bool, bool]:
    """Detect if SSH host keys or Age keys exist on target."""
    has_ssh = (target_root / "etc/ssh/ssh_host_ed25519_key").exists()
    has_age = (target_root / "var/lib/sops-nix/key.txt").exists()
    return has_ssh, has_age


class TestMemoryAndSecrets(unittest.TestCase):
    # ── 1. MemoryProtector (ZRAM / Swap Context Manager) ────────────

    @patch("installer.install.run_capture")
    @patch("installer.install.run")
    @patch("shutil.which")
    def test_memory_protector_zram_normal_lifecycle(self, mock_which, mock_run, mock_run_capture):
        """MemoryProtector provisions ZRAM on enter and resets on exit."""
        mock_which.side_effect = lambda cmd: f"/usr/bin/{cmd}"
        mock_run_capture.return_value = "/dev/zram0"

        with MemoryProtector(size="4G"):
            pass

        mock_run.assert_any_call("modprobe zram")
        mock_run_capture.assert_any_call("zramctl --find --size 4G")
        mock_run.assert_any_call("mkswap /dev/zram0")
        mock_run.assert_any_call("swapon -p 32767 /dev/zram0")
        mock_run.assert_any_call("swapoff /dev/zram0", check=False)
        mock_run.assert_any_call("zramctl --reset /dev/zram0", check=False)

    @patch("installer.install.run_capture")
    @patch("installer.install.run")
    @patch("shutil.which")
    def test_memory_protector_swapfile_fallback(self, mock_which, mock_run, mock_run_capture):
        """MemoryProtector falls back to swapfile when zramctl is unavailable."""
        mock_which.side_effect = lambda cmd: None if cmd == "zramctl" else f"/usr/bin/{cmd}"

        with tempfile.TemporaryDirectory() as tmpdir:
            swap_path = Path(tmpdir) / "swapfile"
            with MemoryProtector(size="2G", fallback_swap_path=swap_path):
                self.assertTrue(swap_path.exists())

            self.assertFalse(swap_path.exists())

    @patch("installer.install.run_capture")
    @patch("installer.install.run")
    @patch("shutil.which")
    def test_memory_protector_cleanup_on_exception(self, mock_which, mock_run, mock_run_capture):
        """MemoryProtector guarantees teardown when an exception occurs inside the block."""
        mock_which.side_effect = lambda cmd: f"/usr/bin/{cmd}"
        mock_run_capture.return_value = "/dev/zram0"

        with self.assertRaises(RuntimeError):
            with MemoryProtector(size="4G"):
                raise RuntimeError("nixos-install failure simulation")

        mock_run.assert_any_call("swapoff /dev/zram0", check=False)
        mock_run.assert_any_call("zramctl --reset /dev/zram0", check=False)

    def test_memory_protector_sizing_calculation(self):
        """MemoryProtector calculates 50% RAM capped at 8GB from meminfo."""
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("MemTotal:       16384000 kB\nMemFree:         8000000 kB\n")
            meminfo_path = Path(f.name)

        try:
            size_16g = MemoryProtector.calculate_zram_size_from_meminfo(meminfo_path)
            self.assertEqual(size_16g, "7G")  # 16000 MB // 2 = 8000 MB -> 7G
        finally:
            meminfo_path.unlink()

        # 4GB RAM host -> 2G ZRAM
        with tempfile.NamedTemporaryFile(mode="w", delete=False) as f:
            f.write("MemTotal:        4194304 kB\nMemFree:         2000000 kB\n")
            meminfo_path2 = Path(f.name)

        try:
            size_4g = MemoryProtector.calculate_zram_size_from_meminfo(meminfo_path2)
            self.assertEqual(size_4g, "2G")
        finally:
            meminfo_path2.unlink()

    # ── 2. SSH & Age Key Management ─────────────────────────────────

    @patch("installer.install.run")
    def test_generate_ssh_host_key(self, mock_run):
        """generate_ssh_key invokes ssh-keygen with correct flags and permissions."""
        with tempfile.TemporaryDirectory() as tmpdir:
            target_dir = Path(tmpdir) / "etc" / "ssh"
            key_path = target_dir / "ssh_host_ed25519_key"

            def fake_keygen(cmd, *args, **kwargs):
                target_dir.mkdir(parents=True, exist_ok=True)
                key_path.write_text("fake_priv_key")
                (target_dir / "ssh_host_ed25519_key.pub").write_text("fake_pub_key")
                return MagicMock(returncode=0)

            mock_run.side_effect = fake_keygen
            generate_ssh_key(target_dir=target_dir, hostname="Makima")

            mock_run.assert_any_call(
                f'ssh-keygen -t ed25519 -N "" -f {key_path} -C "root@Makima"'
            )
            self.assertTrue(key_path.exists())
            mode = os.stat(key_path).st_mode & 0o777
            self.assertEqual(mode, 0o600)

    @patch("installer.install.run")
    @patch("shutil.which", return_value="/usr/bin/ssh-to-age")
    def test_derive_age_key_from_ssh(self, mock_which, mock_run):
        """derive_age_key converts SSH private key to Age secret key via ssh-to-age."""
        with tempfile.TemporaryDirectory() as tmpdir:
            ssh_key = Path(tmpdir) / "ssh_host_ed25519_key"
            ssh_key.write_text("dummy_ssh_key")
            age_key = Path(tmpdir) / "sops-nix" / "key.txt"

            def fake_ssh_to_age(cmd, *args, **kwargs):
                age_key.parent.mkdir(parents=True, exist_ok=True)
                age_key.write_text("AGE-SECRET-KEY-1MOCKKEY...")
                return MagicMock(returncode=0)

            mock_run.side_effect = fake_ssh_to_age
            derive_age_key(ssh_key_path=ssh_key, age_key_path=age_key)

            self.assertTrue(age_key.exists())
            mode = os.stat(age_key).st_mode & 0o777
            self.assertEqual(mode, 0o600)

    @patch("installer.install.run")
    def test_generate_age_key_standalone(self, mock_run):
        """generate_age_key creates new Age key via age-keygen."""
        with tempfile.TemporaryDirectory() as tmpdir:
            age_key = Path(tmpdir) / "sops-nix" / "key.txt"

            def fake_age_keygen(cmd, *args, **kwargs):
                age_key.parent.mkdir(parents=True, exist_ok=True)
                age_key.write_text("AGE-SECRET-KEY-1MOCKSTANDALONE...")
                return MagicMock(returncode=0)

            mock_run.side_effect = fake_age_keygen
            generate_age_key(age_key_path=age_key)

            self.assertTrue(age_key.exists())
            mode = os.stat(age_key).st_mode & 0o777
            self.assertEqual(mode, 0o600)

    def test_import_ssh_and_age_keys(self):
        """import_ssh_key and import_age_key copy external keys and set strict 0600 permissions."""
        with tempfile.TemporaryDirectory() as tmpdir:
            src_ssh = Path(tmpdir) / "usb" / "id_ed25519"
            src_ssh.parent.mkdir(parents=True)
            src_ssh.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\ntest\n-----END OPENSSH PRIVATE KEY-----")

            dest_ssh_dir = Path(tmpdir) / "mnt" / "etc" / "ssh"
            import_ssh_key(source_path=src_ssh, target_dir=dest_ssh_dir)

            dest_key = dest_ssh_dir / "ssh_host_ed25519_key"
            self.assertTrue(dest_key.exists())
            self.assertEqual(os.stat(dest_key).st_mode & 0o777, 0o600)

            src_age = Path(tmpdir) / "usb" / "key.txt"
            src_age.write_text("AGE-SECRET-KEY-1TEST")
            dest_age_path = Path(tmpdir) / "mnt" / "var" / "lib" / "sops-nix" / "key.txt"
            import_age_key(source_path=src_age, target_path=dest_age_path)

            self.assertTrue(dest_age_path.exists())
            self.assertEqual(os.stat(dest_age_path).st_mode & 0o777, 0o600)

    def test_export_backup_keys(self):
        """export_keys copies system keys to external backup target path with restricted permissions."""
        with tempfile.TemporaryDirectory() as tmpdir:
            sys_ssh = Path(tmpdir) / "etc" / "ssh" / "ssh_host_ed25519_key"
            sys_ssh.parent.mkdir(parents=True)
            sys_ssh.write_text("ssh_key_content")

            sys_age = Path(tmpdir) / "var" / "lib" / "sops-nix" / "key.txt"
            sys_age.parent.mkdir(parents=True)
            sys_age.write_text("age_key_content")

            backup_dir = Path(tmpdir) / "media" / "usb_backup"
            export_keys(
                ssh_key_path=sys_ssh,
                age_key_path=sys_age,
                destination_dir=backup_dir,
            )

            self.assertTrue((backup_dir / "ssh_host_ed25519_key").exists())
            self.assertTrue((backup_dir / "key.txt").exists())
            self.assertEqual(os.stat(backup_dir / "key.txt").st_mode & 0o777, 0o600)

    def test_detect_existing_keys(self):
        """detect_existing_keys checks for presence of installed SSH and Age keys."""
        with tempfile.TemporaryDirectory() as tmpdir:
            root = Path(tmpdir)
            has_ssh, has_age = detect_existing_keys(target_root=root)
            self.assertFalse(has_ssh)
            self.assertFalse(has_age)

            ssh_path = root / "etc" / "ssh" / "ssh_host_ed25519_key"
            ssh_path.parent.mkdir(parents=True)
            ssh_path.write_text("ssh_key")

            has_ssh, has_age = detect_existing_keys(target_root=root)
            self.assertTrue(has_ssh)
            self.assertFalse(has_age)


class TestResolutionDetection(unittest.TestCase):
    def test_parse_resolution_string_valid(self):
        from installer.install import parse_resolution_string
        self.assertEqual(parse_resolution_string("1920x1080"), (1920, 1080))
        self.assertEqual(parse_resolution_string("2560x1440"), (2560, 1440))
        self.assertEqual(parse_resolution_string("3840x2160"), (3840, 2160))
        self.assertEqual(parse_resolution_string("1920,1080"), (1920, 1080))
        self.assertEqual(parse_resolution_string("1280 720"), (1280, 720))
        self.assertEqual(parse_resolution_string("U:1920x1080p-0"), (1920, 1080))

    def test_parse_resolution_string_invalid(self):
        from installer.install import parse_resolution_string
        self.assertIsNone(parse_resolution_string(""))
        self.assertIsNone(parse_resolution_string("invalid"))
        self.assertIsNone(parse_resolution_string("100x100"))
        self.assertIsNone(parse_resolution_string("99999x99999"))

    def test_detect_display_resolutions_from_drm(self):
        from installer.install import detect_display_resolutions
        with tempfile.TemporaryDirectory() as tmp_dir:
            drm_dir = Path(tmp_dir) / "drm"
            card_conn = drm_dir / "card0-DP-1"
            card_conn.mkdir(parents=True)
            (card_conn / "status").write_text("connected\n")
            (card_conn / "modes").write_text("3840x2160\n1920x1080\n1920x1080\n1280x720\n")

            fb_dir = Path(tmp_dir) / "graphics"
            res = detect_display_resolutions(drm_path=drm_dir, fb_path=fb_dir)
            self.assertEqual(res, ["3840x2160", "1920x1080", "1280x720"])

    def test_detect_display_resolutions_disconnected_skipped(self):
        from installer.install import STANDARD_RESOLUTIONS, detect_display_resolutions
        with tempfile.TemporaryDirectory() as tmp_dir:
            drm_dir = Path(tmp_dir) / "drm"
            card_conn = drm_dir / "card0-HDMI-A-1"
            card_conn.mkdir(parents=True)
            (card_conn / "status").write_text("disconnected\n")
            (card_conn / "modes").write_text("1920x1080\n")

            fb_dir = Path(tmp_dir) / "graphics"
            res = detect_display_resolutions(drm_path=drm_dir, fb_path=fb_dir)
            self.assertEqual(res, list(STANDARD_RESOLUTIONS))

    def test_detect_display_resolutions_from_framebuffer(self):
        from installer.install import detect_display_resolutions
        with tempfile.TemporaryDirectory() as tmp_dir:
            drm_dir = Path(tmp_dir) / "drm"
            fb_dir = Path(tmp_dir) / "graphics"
            fb0 = fb_dir / "fb0"
            fb0.mkdir(parents=True)
            (fb0 / "virtual_size").write_text("2560,1440\n")

            res = detect_display_resolutions(drm_path=drm_dir, fb_path=fb_dir)
            self.assertEqual(res, ["2560x1440"])


class TestBootloaderAndSecurityConfig(unittest.TestCase):
    def test_build_bootloader_config_limine_with_resolution(self):
        from installer.install import BootloaderChoice, InstallConfig, build_bootloader_config
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="2560x1440",
            secure_boot=False,
        )
        out = build_bootloader_config(cfg)
        self.assertIn('northstar.features.boot.loader = "limine";', out)
        self.assertIn('boot.loader.limine.resolution = "2560x1440";', out)
        self.assertNotIn("secureBoot.enable", out)

    def test_build_bootloader_config_limine_with_secure_boot(self):
        from installer.install import BootloaderChoice, InstallConfig, build_bootloader_config
        cfg = InstallConfig(
            bootloader=BootloaderChoice.LIMINE,
            resolution="1920x1080",
            secure_boot=True,
        )
        out = build_bootloader_config(cfg)
        self.assertIn('northstar.features.boot.loader = "limine";', out)
        self.assertIn('boot.loader.limine.resolution = "1920x1080";', out)
        self.assertIn("northstar.features.boot.secureBoot.enable = true;", out)


class TestAIMLAndHardwareStub(unittest.TestCase):
    def test_aiml_default_disabled_across_all_presets(self):
        from installer.install import ProfileChoice, default_features
        for preset in (ProfileChoice.BASE, ProfileChoice.DESKTOP, ProfileChoice.WORKSTATION):
            feats = {f.id: f.enabled for f in default_features(preset)}
            self.assertIn("aiml", feats, f"aiml feature must exist in {preset}")
            self.assertFalse(feats["aiml"], f"aiml must default to False in {preset}")

    def test_aiml_enabled_override_emission(self):
        from installer.install import InstallConfig, ProfileChoice, build_features_override, default_features
        cfg = InstallConfig(profile=ProfileChoice.WORKSTATION)
        cfg.features = default_features(ProfileChoice.WORKSTATION)
        for f in cfg.features:
            if f.id == "aiml":
                f.enabled = True

        out = build_features_override(cfg)
        self.assertIn("northstar.features = {", out)
        self.assertIn("development.aiml.enable = true;", out)

    @patch("installer.install.run")
    def test_do_generate_config_writes_stub_hardware_nix(self, mock_run):
        from installer.install import InstallConfig, ProfileChoice, do_generate_config
        mock_run.return_value = MagicMock(returncode=0)
        with tempfile.TemporaryDirectory() as tmp_dir:
            work_dir = Path(tmp_dir)
            cfg = InstallConfig(
                hostname="StubTestHost",
                profile=ProfileChoice.DESKTOP,
            )
            do_generate_config(cfg, work_dir)

            hw_file = work_dir / "hosts" / "StubTestHost" / "hardware.nix"
            self.assertTrue(hw_file.exists())
            content = hw_file.read_text()
            self.assertIn('nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";', content)


if __name__ == "__main__":
    unittest.main()
