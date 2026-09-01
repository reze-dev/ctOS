"""
Unit tests for validating Nix syntax and AST compliance of generated configs.
Uses nix-instantiate --parse when available, with fallback bracket/brace parser.
"""

import shutil
import subprocess
import unittest

from installer.install import (
    BootloaderChoice,
    DualBootEntry,
    FeatureOption,
    GpuChoice,
    IgpuType,
    InstallConfig,
    InstallMode,
    ProfileChoice,
    default_features,
    generate_disko_partition_only,
    generate_disko_whole_disk,
    generate_host_default_nix,
)


def parse_nix_code(code: str) -> tuple[bool, str]:
    """Validate Nix code syntax using nix-instantiate --parse - if installed."""
    if shutil.which("nix-instantiate"):
        proc = subprocess.run(
            ["nix-instantiate", "--parse", "-"],
            input=code,
            capture_output=True,
            text=True,
        )
        return proc.returncode == 0, proc.stderr or proc.stdout

    # Fallback syntactic checks
    open_curly = code.count("{") - code.count("}")
    open_square = code.count("[") - code.count("]")
    open_paren = code.count("(") - code.count(")")
    if open_curly != 0 or open_square != 0 or open_paren != 0:
        return False, f"Unbalanced braces/brackets: curly={open_curly}, square={open_square}, paren={open_paren}"
    return True, "Passed basic AST/balance checks (nix-instantiate not found)"


class TestNixSyntax(unittest.TestCase):
    def test_generated_default_nix_syntax(self):
        # Matrix of configurations
        configs = [
            # 1. Base + Limine + No GPU
            InstallConfig(
                hostname="server-node",
                username="rootuser",
                hashed_pw="$6$12345",
                profile=ProfileChoice.BASE,
                shell="zsh",
                bootloader=BootloaderChoice.LIMINE,
                features=default_features(ProfileChoice.BASE),
                gpu_choice=GpuChoice.NONE,
            ),
            # 2. Desktop + Limine + Dual-boot Windows + Custom features
            InstallConfig(
                hostname="desktop-node",
                username="developer",
                hashed_pw="$6$67890",
                profile=ProfileChoice.DESKTOP,
                shell="fish",
                bootloader=BootloaderChoice.LIMINE,
                features=[
                    FeatureOption("hyprland", "Hyprland", "Desktop", False),
                    FeatureOption("niri", "Niri", "Desktop", True),
                    FeatureOption("emacs", "Emacs", "Dev", True),
                ],
                dual_boot_entries=[
                    DualBootEntry(
                        name="Windows 11",
                        efi_path="/EFI/Microsoft/Boot/bootmgfw.efi",
                        disk_uuid="1234-5678",
                        enabled=True,
                    ),
                    DualBootEntry(
                        name="Arch Linux",
                        efi_path="/EFI/arch/grubx64.efi",
                        disk_uuid="1234-5678",
                        enabled=True,
                    ),
                ],
                gpu_choice=GpuChoice.NVIDIA,
                nvidia_bus_id="PCI:1:0:0",
            ),
            # 3. Workstation + Limine + NVIDIA Prime AMD
            InstallConfig(
                hostname="workstation-rig",
                username="alice",
                hashed_pw="$6$abcdef",
                profile=ProfileChoice.WORKSTATION,
                shell="zsh",
                bootloader=BootloaderChoice.LIMINE,
                features=default_features(ProfileChoice.WORKSTATION),
                gpu_choice=GpuChoice.NVIDIA_PRIME,
                nvidia_bus_id="PCI:1:0:0",
                igpu_bus_id="PCI:5:0:0",
                igpu_type=IgpuType.AMD,
            ),
            # 4. Workstation + Limine + NVIDIA Prime Intel
            InstallConfig(
                hostname="workstation-intel",
                username="bob",
                hashed_pw="$6$fedcba",
                profile=ProfileChoice.WORKSTATION,
                shell="zsh",
                bootloader=BootloaderChoice.LIMINE,
                features=default_features(ProfileChoice.WORKSTATION),
                gpu_choice=GpuChoice.NVIDIA_PRIME,
                nvidia_bus_id="PCI:1:0:0",
                igpu_bus_id="PCI:0:2:0",
                igpu_type=IgpuType.INTEL,
            ),
        ]

        for idx, cfg in enumerate(configs):
            with self.subTest(config_index=idx, hostname=cfg.hostname):
                nix_code = generate_host_default_nix(cfg)
                valid, msg = parse_nix_code(nix_code)
                self.assertTrue(valid, f"Invalid Nix syntax generated for {cfg.hostname}:\n{msg}\nCode:\n{nix_code}")

    def test_generated_disko_nix_syntax(self):
        disko_configs = [
            # 1. Whole disk btrfs with custom swap
            InstallConfig(
                hostname="host-btrfs",
                disk_dev="nvme0n1",
                fs_type="btrfs",
                swap_size="16G",
                root_size="100%",
                mode=InstallMode.WHOLE_DISK,
            ),
            # 2. Whole disk ext4 with swap=0 and root=500G
            InstallConfig(
                hostname="host-ext4",
                disk_dev="sda",
                fs_type="ext4",
                swap_size="0",
                root_size="500G",
                mode=InstallMode.WHOLE_DISK,
            ),
            # 3. Partition only btrfs
            InstallConfig(
                hostname="host-part-btrfs",
                nixos_part="/dev/nvme0n1p2",
                efi_part="/dev/nvme0n1p1",
                fs_type="btrfs",
                swap_size="8G",
                mode=InstallMode.PARTITION_ONLY,
            ),
            # 4. Partition only ext4 with dedicated swap partition
            InstallConfig(
                hostname="host-part-ext4",
                nixos_part="/dev/sda2",
                efi_part="/dev/sda1",
                fs_type="ext4",
                swap_size="8G",
                swap_partition="/dev/sda3",
                mode=InstallMode.PARTITION_ONLY,
            ),
        ]

        for idx, cfg in enumerate(disko_configs):
            with self.subTest(config_index=idx, hostname=cfg.hostname):
                if cfg.mode == InstallMode.WHOLE_DISK:
                    disko_code = generate_disko_whole_disk(cfg)
                else:
                    disko_code = generate_disko_partition_only(cfg, efi_uuid="1234-5678")

                valid, msg = parse_nix_code(disko_code)
                self.assertTrue(valid, f"Invalid Disko Nix syntax for {cfg.hostname}:\n{msg}\nCode:\n{disko_code}")

    def test_state_version_compliance(self):
        cfg = InstallConfig(
            hostname="StateVersionTest",
            username="tester",
            hashed_pw="$6$dummy",
        )
        content = generate_host_default_nix(cfg)
        self.assertIn('system.stateVersion = "26.11";', content)
        self.assertNotIn('system.stateVersion = "26.05";', content)


if __name__ == "__main__":
    unittest.main()
