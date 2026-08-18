"""
Unit tests for application state, profile presets, feature toggles, and state persistence.
Directly mirrors installer-rs/tests/app_state_tests.rs and provides additional coverage.
"""

import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

from installer.install import (
    App,
    DualBootEntry,
    Page,
    ProfileChoice,
    State,
    default_features,
    hash_password,
)


class TestStateAndProfiles(unittest.TestCase):
    def test_app_initial_state(self):
        app = App("/tmp/test-northstar-workdir")
        self.assertEqual(app.page, Page.WELCOME)
        self.assertFalse(app.should_quit)
        self.assertEqual(app.err, "")

    def test_app_text_input_and_cursor(self):
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
        app = App("/tmp/test-northstar-workdir")
        app.apply_profile(ProfileChoice.DESKTOP)

        # Hyprland is enabled by default on Desktop
        self.assertEqual(app.config.features[0].id, "hyprland")
        self.assertTrue(app.config.features[0].enabled)

        # Toggle hyprland off
        app.cursor = 0
        app.toggle_current_feature()
        self.assertFalse(app.config.features[0].enabled)

        # Toggle hyprland back on
        app.toggle_current_feature()
        self.assertTrue(app.config.features[0].enabled)

        # Switch to Base profile (minimal)
        app.apply_profile(ProfileChoice.BASE)
        self.assertFalse(app.config.features[0].enabled)

    def test_app_dual_boot_toggling(self):
        app = App("/tmp/test-northstar-workdir")
        app.config.dual_boot_entries = [
            DualBootEntry(
                name="Fedora Linux",
                efi_path="/EFI/fedora/shimx64.efi",
                disk_uuid="CB41-6695",
                enabled=True,
            )
        ]

        self.assertTrue(app.config.dual_boot_entries[0].enabled)
        app.cursor = 0
        app.toggle_current_dual_boot()
        self.assertFalse(app.config.dual_boot_entries[0].enabled)

    def test_state_step_transitions_and_skip(self):
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            state = State(state_file=state_path)
            state.clear()

            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.should_skip("generate_config"))
            self.assertFalse(state.should_skip("partition"))

            state.set_step("partition")
            self.assertEqual(state.current_step(), "partition")
            self.assertTrue(state.should_skip("generate_config"))
            self.assertFalse(state.should_skip("partition"))
            self.assertFalse(state.should_skip("install_nixos"))

            state.set_step("install_nixos")
            self.assertTrue(state.should_skip("generate_config"))
            self.assertTrue(state.should_skip("partition"))
            self.assertFalse(state.should_skip("install_nixos"))

            state.clear()
        finally:
            if state_path.exists():
                state_path.unlink()

    def test_default_features_by_profile(self):
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
        mock_which.side_effect = lambda tool: "/usr/bin/mkpasswd" if tool == "mkpasswd" else None
        mock_subproc.return_value = MagicMock(returncode=0, stdout="$6$mockedhash\n")

        hashed = hash_password("secret123")
        self.assertEqual(hashed, "$6$mockedhash")

    @patch("shutil.which")
    @patch("subprocess.run")
    def test_hash_password_openssl_fallback(self, mock_subproc, mock_which):
        mock_which.side_effect = lambda tool: "/usr/bin/openssl" if tool == "openssl" else None
        mock_subproc.return_value = MagicMock(returncode=0, stdout="$6$opensslhash\n")

        hashed = hash_password("secret123")
        self.assertEqual(hashed, "$6$opensslhash")

    def test_state_corrupt_binary_recovery(self):
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            # Write invalid non-UTF8 binary data
            state_path.write_bytes(b"\x00\xFF\xFE\x80\x90 invalid binary data")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.is_completed())
            self.assertFalse(state.should_skip("partition"))

            # State can continue to function and save clean checkpoints
            state.set_step("partition")
            self.assertEqual(state.current_step(), "partition")
            self.assertTrue(state.should_skip("generate_config"))

            state.clear()
            self.assertEqual(state.data, {})
        finally:
            if state_path.exists():
                state_path.unlink()

    def test_state_non_dict_json_recovery(self):
        with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
            state_path = Path(f.name)

        try:
            # Test array JSON
            state_path.write_text("[1, 2, 3]", encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.is_completed())

            # Test string JSON
            state_path.write_text('"a string"', encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # Test null JSON
            state_path.write_text("null", encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # Test integer JSON
            state_path.write_text("42", encoding="utf-8")
            state = State(state_file=state_path)
            self.assertEqual(state.data, {})
            self.assertEqual(state.current_step(), "generate_config")

            # Test corrupted data attribute mutation
            state.data = None  # type: ignore
            self.assertEqual(state.current_step(), "generate_config")
            self.assertFalse(state.is_completed())
            self.assertFalse(state.should_skip("install_nixos"))
            state.set_step("install_nixos")
            self.assertEqual(state.current_step(), "install_nixos")
            self.assertFalse(state.is_completed())
            state.set_step("done")
            self.assertTrue(state.is_completed())

            state.clear()
            self.assertEqual(state.data, {})
        finally:
            if state_path.exists():
                state_path.unlink()


if __name__ == "__main__":
    unittest.main()
