#!/usr/bin/env python3
"""
test_forensic_auditor_m3.py - Independent Forensic Audit for Milestone 3:
Bluetooth Popup UI & Shell Wiring.

Forensic Checks:
1. Scope & Working Tree Confinement
2. Facade, Dummy & Mock Detection
3. Hardcoded MAC and Value Detection
4. Button-to-Service Invocation Verification:
   - [POWER] -> BluetoothService.togglePower()
   - [SCAN] -> BluetoothService.toggleScan()
   - [CONNECT] -> BluetoothService.connectDevice(...)
   - [DISCONNECT] -> BluetoothService.disconnectDevice(...)
   - [PAIR] -> BluetoothService.pairDevice(...)
   - [FORGET] -> BluetoothService.forgetDevice(...)
   - [x] Close -> root.closeRequested()
5. AmbientBar Integration & Dual-Click Action
6. Shell Multi-Screen, Dual PanelWindow & Mutual Exclusivity Wiring
7. Component Registration in qmldir
8. Static Linter & Policy Verification
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

PASS_COUNT = 0
FAIL_COUNT = 0

def audit_assert(check_id, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {check_id}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {check_id}: {desc} ({details})", file=sys.stderr)

print("=" * 70)
print("FORENSIC INTEGRITY AUDIT: MILESTONE 3 (BLUETOOTH POPUP & SHELL WIRING)")
print("=" * 70)

# ==============================================================================
# 1. SCOPE & CONFINEMENT AUDIT
# ==============================================================================
proc = subprocess.run(["git", "diff", "--name-only"], cwd=PROJECT_ROOT, capture_output=True, text=True)
tracked_diff = [f.strip() for f in proc.stdout.strip().split("\n") if f.strip()]

# M1 and M2 files were modified in earlier milestones. In M3, allowed modifications are:
# shell/desktop/surfaces/components/qmldir, shell/desktop/surfaces/AmbientBar.qml, shell/shell.qml
# plus untracked shell/desktop/surfaces/components/BluetoothPopup.qml
allowed_tracked = {
    "shell/desktop/services/BluetoothService.qml", # M2
    "shell/desktop/surfaces/SystemRail.qml",       # M1
    "shell/desktop/surfaces/AmbientBar.qml",      # M3
    "shell/desktop/surfaces/components/qmldir",   # M3
    "shell/shell.qml"                            # M3
}
unauthorized_tracked = [f for f in tracked_diff if f not in allowed_tracked]
audit_assert("FA.SCOPE.01", "Zero unauthorized tracked file modifications in git diff",
             len(unauthorized_tracked) == 0, f"unauthorized={unauthorized_tracked}")

popup_path = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components/BluetoothPopup.qml")
qmldir_path = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components/qmldir")
bar_path = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/AmbientBar.qml")
shell_path = os.path.join(PROJECT_ROOT, "shell/shell.qml")

audit_assert("FA.FILE.01", "BluetoothPopup.qml exists", os.path.isfile(popup_path), f"path={popup_path}")
audit_assert("FA.FILE.02", "qmldir exists", os.path.isfile(qmldir_path), f"path={qmldir_path}")
audit_assert("FA.FILE.03", "AmbientBar.qml exists", os.path.isfile(bar_path), f"path={bar_path}")
audit_assert("FA.FILE.04", "shell.qml exists", os.path.isfile(shell_path), f"path={shell_path}")

# ==============================================================================
# 2. FACADE, DUMMY & HARDCODED DATA AUDIT (BluetoothPopup.qml)
# ==============================================================================
with open(popup_path, "r", encoding="utf-8") as f:
    popup_src = f.read()

# Check for hardcoded MAC addresses
mac_pattern = re.compile(r"\"([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\"")
hardcoded_macs = mac_pattern.findall(popup_src)
audit_assert("FA.INTEG.MAC", "Zero hardcoded MAC address string literals in BluetoothPopup.qml",
             len(hardcoded_macs) == 0, f"found={hardcoded_macs}")

# Check for forbidden mock / stub identifiers
for kw in ["mock", "dummy", "stub", "fake", "fixture", "test_device"]:
    matches = re.findall(rf"\b{kw}\b", popup_src, re.IGNORECASE)
    audit_assert(f"FA.INTEG.KW_{kw.upper()}", f"Zero \"{kw}\" tokens in BluetoothPopup.qml",
                 len(matches) == 0, f"count={len(matches)}")

# Check repeaters model bindings
repeater_models = re.findall(r"Repeater\s*\{[^}]*model:\s*([^;\n\r]+)", popup_src)
audit_assert("FA.INTEG.REPEATER_CONN", "Connected devices repeater binds directly to BluetoothService.connectedDevices",
             any("BluetoothService.connectedDevices" in m for m in repeater_models), f"models={repeater_models}")
audit_assert("FA.INTEG.REPEATER_PAIR", "Paired devices repeater binds directly to BluetoothService.pairedDevices",
             any("BluetoothService.pairedDevices" in m for m in repeater_models), f"models={repeater_models}")
audit_assert("FA.INTEG.REPEATER_AVAIL", "Available devices repeater binds directly to BluetoothService.availableDevices",
             any("BluetoothService.availableDevices" in m for m in repeater_models), f"models={repeater_models}")

# ==============================================================================
# 3. GENUINE BUTTON METHOD INVOCATION AUDIT (BluetoothPopup.qml)
# ==============================================================================
# Power button
power_wired = bool(re.search(r"onClicked:\s*BluetoothService\.togglePower\(\)", popup_src))
audit_assert("FA.INVOKE.POWER", "[POWER] button genuinely invokes BluetoothService.togglePower()",
             power_wired, "verified onClicked binding")

# Scan button
scan_wired = bool(re.search(r"onClicked:\s*BluetoothService\.toggleScan\(\)", popup_src))
audit_assert("FA.INVOKE.SCAN", "[SCAN] button genuinely invokes BluetoothService.toggleScan()",
             scan_wired, "verified onClicked binding")

# Disconnect button
disconnect_wired = bool(re.search(r"onClicked:\s*BluetoothService\.disconnectDevice\([^)]+\)", popup_src))
audit_assert("FA.INVOKE.DISCONNECT", "[DISCONNECT] button genuinely invokes BluetoothService.disconnectDevice(mac)",
             disconnect_wired, "verified onClicked binding")

# Connect button
connect_wired = bool(re.search(r"onClicked:\s*BluetoothService\.connectDevice\([^)]+\)", popup_src))
audit_assert("FA.INVOKE.CONNECT", "[CONNECT] button genuinely invokes BluetoothService.connectDevice(mac)",
             connect_wired, "verified onClicked binding")

# Pair button
pair_wired = bool(re.search(r"onClicked:\s*BluetoothService\.pairDevice\([^)]+\)", popup_src))
audit_assert("FA.INVOKE.PAIR", "[PAIR] button genuinely invokes BluetoothService.pairDevice(mac)",
             pair_wired, "verified onClicked binding")

# Forget button
forget_wired = bool(re.search(r"onClicked:\s*BluetoothService\.forgetDevice\([^)]+\)", popup_src))
audit_assert("FA.INVOKE.FORGET", "[FORGET] button genuinely invokes BluetoothService.forgetDevice(mac)",
             forget_wired, "verified onClicked binding")

# Close button & signal
close_signal_decl = bool(re.search(r"signal\s+closeRequested", popup_src))
close_wired = bool(re.search(r"onClicked:\s*root\.closeRequested\(\)", popup_src))
audit_assert("FA.INVOKE.CLOSE_DECL", "BluetoothPopup declares signal closeRequested",
             close_signal_decl, "signal declared")
audit_assert("FA.INVOKE.CLOSE_CALL", "[x] button genuinely emits closeRequested()",
             close_wired, "signal invoked")

# Cyberpunk visual compliance
audit_assert("FA.VISUAL.PRAGMA", "BluetoothPopup declares pragma ComponentBehavior: Bound",
             "pragma ComponentBehavior: Bound" in popup_src, "pragma verified")
audit_assert("FA.VISUAL.WIDTH", "BluetoothPopup specifies implicitWidth: 320",
             "implicitWidth: 320" in popup_src, "width verified")
audit_assert("FA.VISUAL.BG", "BluetoothPopup uses Theme.gray900 background",
             "color: Theme.gray900" in popup_src, "color verified")
audit_assert("FA.VISUAL.BORDER", "BluetoothPopup uses Theme.borderMuted border",
             "border.color: Theme.borderMuted" in popup_src, "border verified")
audit_assert("FA.VISUAL.BRACKETS", "BluetoothPopup renders 8 corner bracket arms in Theme.acidGreen",
             "bracketColor: Theme.acidGreen" in popup_src and popup_src.count("Theme.cornerBracketArmLength") >= 8,
             "corner brackets verified")
audit_assert("FA.VISUAL.SHIELD", "BluetoothPopup root contains click-shield MouseArea with preventStealing: true",
             "preventStealing: true" in popup_src, "shield verified")

# ==============================================================================
# 4. AMBIENTBAR.QML INTEGRATION & DUAL-CLICK AUDIT
# ==============================================================================
with open(bar_path, "r", encoding="utf-8") as f:
    bar_src = f.read()

audit_assert("FA.BAR.SIGNAL", "AmbientBar declares signal toggleBluetooth",
             bool(re.search(r"signal\s+toggleBluetooth", bar_src)), "signal verified")
audit_assert("FA.BAR.MOUSE_BUTTONS", "AmbientBar bluetoothMouseArea accepts LeftButton | RightButton",
             "Qt.LeftButton | Qt.RightButton" in bar_src, "buttons verified")
audit_assert("FA.BAR.RIGHT_CLICK", "AmbientBar RightButton invokes BluetoothService.togglePower()",
             "BluetoothService.togglePower()" in bar_src, "right click verified")
audit_assert("FA.BAR.LEFT_CLICK", "AmbientBar LeftButton invokes root.toggleBluetooth()",
             "root.toggleBluetooth()" in bar_src, "left click verified")

# ==============================================================================
# 5. SHELL.QML MULTI-SCREEN & WINDOW HOSTING AUDIT
# ==============================================================================
with open(shell_path, "r", encoding="utf-8") as f:
    shell_src = f.read()

audit_assert("FA.SHELL.PROP_VIS", "shell.qml defines property bool bluetoothVisible",
             "property bool bluetoothVisible: false" in shell_src, "property verified")
audit_assert("FA.SHELL.PROP_SCR", "shell.qml defines property var bluetoothScreen",
             "property var bluetoothScreen: null" in shell_src, "property verified")
audit_assert("FA.SHELL.FUNC_TOGGLE", "shell.qml defines toggleBluetooth(targetScreen)",
             "function toggleBluetooth(targetScreen)" in shell_src, "function verified")
audit_assert("FA.SHELL.FUNC_CLOSE", "shell.qml defines closeBluetooth()",
             "function closeBluetooth()" in shell_src, "function verified")
audit_assert("FA.SHELL.EXCLUSIVITY_CAL", "Opening Bluetooth closes Calendar",
             "root.closeCalendar()" in shell_src and "function toggleBluetooth" in shell_src, "exclusivity verified")
audit_assert("FA.SHELL.EXCLUSIVITY_BT", "Opening Calendar closes Bluetooth",
             "root.closeBluetooth()" in shell_src and "function toggleCalendar" in shell_src, "exclusivity verified")
audit_assert("FA.SHELL.OVERLAY_CLOSE", "Opening OverlayController closes Bluetooth",
             "root.closeBluetooth()" in shell_src and "function onOverlayOpened" in shell_src, "overlay close verified")
audit_assert("FA.SHELL.SCREEN_DISCONN", "Disconnecting screen closes Bluetooth popup",
             "isBtAlive" in shell_src and "root.closeBluetooth()" in shell_src, "screen disconnect verified")
audit_assert("FA.SHELL.IPC", "IpcHandler exposes toggleBluetooth",
             "function toggleBluetooth(): void" in shell_src, "IPC verified")
audit_assert("FA.SHELL.BAR_WIRE", "barVariants wires onToggleBluetooth",
             "onToggleBluetooth: root.toggleBluetooth(modelData)" in shell_src, "bar wiring verified")
audit_assert("FA.SHELL.BACKDROP_HOST", "bluetoothBackdropHost PanelWindow declared on WlrLayer.Top",
             "id: bluetoothBackdropHost" in shell_src and "ctos-bluetooth-backdrop" in shell_src, "backdrop host verified")
audit_assert("FA.SHELL.POPUP_HOST", "bluetoothPopupHost PanelWindow declared on WlrLayer.Overlay",
             "id: bluetoothPopupHost" in shell_src and "ctos-bluetooth-popup" in shell_src, "popup host verified")

# ==============================================================================
# 6. QMLDIR COMPONENT REGISTRATION AUDIT
# ==============================================================================
with open(qmldir_path, "r", encoding="utf-8") as f:
    qmldir_src = f.read()

audit_assert("FA.QMLDIR.REG", "components/qmldir registers BluetoothPopup 1.0",
             "BluetoothPopup 1.0 BluetoothPopup.qml" in qmldir_src, "qmldir entry verified")

# ==============================================================================
# SUMMARY & VERDICT
# ==============================================================================
print("=" * 70)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== FINAL VERDICT: CLEAN ===")
    sys.exit(0)
else:
    print("=== FINAL VERDICT: INTEGRITY VIOLATION ===", file=sys.stderr)
    sys.exit(1)
