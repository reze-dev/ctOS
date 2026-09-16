#!/usr/bin/env python3
"""
================================================================================
CHALLENGER 1 EMPIRICAL AUDIT & VERIFICATION SUITE: MILESTONE 3
Bluetooth Popup UI & Shell Window Integration (BluetoothPopup.qml)
================================================================================
Target:
- shell/desktop/surfaces/components/BluetoothPopup.qml
- shell/desktop/surfaces/components/qmldir
- shell/desktop/surfaces/AmbientBar.qml
- shell/shell.qml
================================================================================
"""

import os
import re
import subprocess
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
POPUP_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components/BluetoothPopup.qml")
QMLDIR_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components/qmldir")
BAR_PATH = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/AmbientBar.qml")
SHELL_PATH = os.path.join(PROJECT_ROOT, "shell/shell.qml")
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

total_tests = 0
passed_tests = 0
failed_tests = []

def record(test_id, cond, desc, details=""):
    global total_tests, passed_tests, failed_tests
    total_tests += 1
    if cond:
        passed_tests += 1
        print(f"  [PASS] {test_id}: {desc} {details}")
    else:
        failed_tests.append((test_id, desc, details))
        print(f"  [FAIL] {test_id}: {desc} | Details: {details}", file=sys.stderr)

print("=" * 80)
print("CHALLENGER 1 EMPIRICAL SUITE: MILESTONE 3 (BLUETOOTH POPUP UI)")
print("=" * 80)

# ==============================================================================
# PHASE 1: STATIC & CONTRACT AUDIT: BluetoothPopup.qml
# ==============================================================================
print("\n--- Phase 1: BluetoothPopup.qml Static & Contract Audit ---")

with open(POPUP_PATH, "r", encoding="utf-8") as f:
    popup_content = f.read()

record("STAT.POP.01", "pragma ComponentBehavior: Bound" in popup_content, "Declares pragma ComponentBehavior: Bound")
record("STAT.POP.02", "signal closeRequested" in popup_content, "Declares signal closeRequested")
record("STAT.POP.03", "width: 320" in popup_content and "implicitWidth: 320" in popup_content, "Defines fixed width 320px and implicitWidth 320px")
record("STAT.POP.04", "color: Theme.gray900" in popup_content, "Uses Theme.gray900 surface color")
record("STAT.POP.05", "radius: Theme.radiusSmall" in popup_content, "Uses Theme.radiusSmall corner radius")
record("STAT.POP.06", "border.color: Theme.borderMuted" in popup_content, "Uses Theme.borderMuted border color")
record("STAT.POP.07", "border.width: Theme.borderWidth" in popup_content, "Uses Theme.borderWidth border width")

# Zero raw hex colors
hex_matches = re.findall(r"#[0-9a-fA-F]{3,8}\b", popup_content)
record("STAT.POP.08", len(hex_matches) == 0, "Zero hardcoded hex colors (#...)", f"matches={hex_matches}")

# Backdrop click isolation
record("STAT.POP.09", "preventStealing: true" in popup_content and "mouse.accepted = true" in popup_content, "Root MouseArea isolates backdrop click")

# Cyberpunk corner brackets
record("STAT.POP.10", "Theme.cornerBracketMargin" in popup_content and "Theme.cornerBracketArmLength" in popup_content and "Theme.cornerBracketThickness" in popup_content and "Theme.acidGreen" in popup_content, "Cyberpunk corner brackets use standard Theme tokens and Theme.acidGreen")

# Header controls
record("STAT.POP.11", "BluetoothService.togglePower()" in popup_content, "Header wires BluetoothService.togglePower()")
record("STAT.POP.12", "BluetoothService.toggleScan()" in popup_content, "Header wires BluetoothService.toggleScan()")
record("STAT.POP.13", "root.closeRequested()" in popup_content, "Header close button wires root.closeRequested()")

# Typography
non_mono_fonts = re.findall(r'font\.family:\s*"(?!Maple Mono)[^"]+"', popup_content)
record("STAT.POP.14", len(non_mono_fonts) == 0, "All typography uses Theme.fontFamilyMonospace", f"violations={non_mono_fonts}")

# Device action buttons
record("STAT.POP.15", "BluetoothService.disconnectDevice" in popup_content, "Wires BluetoothService.disconnectDevice in connected section")
record("STAT.POP.16", "BluetoothService.connectDevice" in popup_content, "Wires BluetoothService.connectDevice in paired and available sections")
record("STAT.POP.17", "BluetoothService.forgetDevice" in popup_content, "Wires BluetoothService.forgetDevice in paired section")
record("STAT.POP.18", "BluetoothService.pairDevice" in popup_content, "Wires BluetoothService.pairDevice in available section")
record("STAT.POP.19", "BluetoothService.refresh()" in popup_content, "Wires BluetoothService.refresh() in footer")

# ==============================================================================
# PHASE 2: WIRING & SHELL INTEGRATION AUDIT
# ==============================================================================
print("\n--- Phase 2: Wiring & Shell Integration Audit ---")

with open(QMLDIR_PATH, "r", encoding="utf-8") as f:
    qmldir_content = f.read()
record("STAT.WIRE.01", "BluetoothPopup 1.0 BluetoothPopup.qml" in qmldir_content, "qmldir registers BluetoothPopup 1.0")

with open(BAR_PATH, "r", encoding="utf-8") as f:
    bar_content = f.read()
record("STAT.WIRE.02", "signal toggleBluetooth" in bar_content, "AmbientBar declares signal toggleBluetooth")
record("STAT.WIRE.03", "root.toggleBluetooth()" in bar_content and "BluetoothService.togglePower()" in bar_content, "AmbientBar handles left click (toggleBluetooth) and right click (togglePower)")

with open(SHELL_PATH, "r", encoding="utf-8") as f:
    shell_content = f.read()
record("STAT.WIRE.04", "property bool bluetoothVisible: false" in shell_content, "shell.qml declares bluetoothVisible")
record("STAT.WIRE.05", "property var bluetoothScreen: null" in shell_content, "shell.qml declares bluetoothScreen")
record("STAT.WIRE.06", "function toggleBluetooth(targetScreen)" in shell_content, "shell.qml declares toggleBluetooth function")
record("STAT.WIRE.07", "function closeBluetooth()" in shell_content, "shell.qml declares closeBluetooth function")
record("STAT.WIRE.08", "id: bluetoothBackdropHost" in shell_content and "WlrLayershell.layer: WlrLayer.Top" in shell_content, "shell.qml declares bluetoothBackdropHost on WlrLayer.Top")
record("STAT.WIRE.09", "id: bluetoothPopupHost" in shell_content and "WlrLayershell.layer: WlrLayer.Overlay" in shell_content, "shell.qml declares bluetoothPopupHost on WlrLayer.Overlay")
record("STAT.WIRE.10", "BluetoothPopup" in shell_content and "onCloseRequested: root.closeBluetooth()" in shell_content, "BluetoothPopup mounted with onCloseRequested: root.closeBluetooth()")
record("STAT.WIRE.11", "root.closeBluetooth()" in shell_content and "root.closeCalendar()" in shell_content, "Mutual preemption between CalendarPopup and BluetoothPopup")

# ==============================================================================
# PHASE 3: LIVE QUICKSHELL RUNTIME VERIFICATION
# ==============================================================================
print("\n--- Phase 3: Live Quickshell Runtime Verification ---")

harness_path = os.path.join(PROJECT_ROOT, "tests/e2e/harness/test_m3_bluetooth_popup_challenger.qml")
env = dict(os.environ, QML_IMPORT_PATH=os.path.join(PROJECT_ROOT, "shell"), CTOS_SETTINGS_PATH="/tmp/ctos_test_settings.json")

proc = subprocess.run([QUICKSHELL_BIN, "-p", harness_path], capture_output=True, text=True, timeout=10, env=env)

record("RUN.POP.01", proc.returncode == 0, f"Quickshell test harness exited with code 0 (rc={proc.returncode})")
record("RUN.POP.02", "M3 BLUETOOTH POPUP RESULTS: Passed=54, Failed=0" in proc.stdout, "All 54 runtime assertions passed in harness")
record("RUN.POP.03", "=== PASS: M3 BLUETOOTH POPUP CHALLENGER RUNTIME SUCCESSFUL ===" in proc.stdout, "Test harness emitted SUCCESS banner")

# ==============================================================================
# SUMMARY & VERDICT
# ==============================================================================
print("\n" + "=" * 80)
print(f"CHALLENGER 1 AUDIT SUMMARY: Passed={passed_tests}, Failed={len(failed_tests)}")
if len(failed_tests) == 0:
    print("=== VERDICT: APPROVE (100% OF ALL TESTS AND INVARIANTS PASSED) ===")
    sys.exit(0)
else:
    print("=== VERDICT: CHALLENGE_FAILED ===")
    for fid, fdesc, fdet in failed_tests:
        print(f"  - {fid}: {fdesc} ({fdet})")
    sys.exit(1)
