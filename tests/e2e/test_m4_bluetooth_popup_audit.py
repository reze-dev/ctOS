#!/usr/bin/env python3
"""
test_m4_bluetooth_popup_audit.py - Comprehensive AST & Token Audit for Milestone 4:
Requirement R3: Test Suite Expansion & Comprehensive Acceptance for ctOS Bluetooth
drop-down module, shell integration, and system rail session actions.

Verifies:
1. File Existence & Module Registration:
   - shell/desktop/surfaces/components/BluetoothPopup.qml exists
   - shell/desktop/surfaces/components/qmldir declares BluetoothPopup 1.0 BluetoothPopup.qml
2. BluetoothPopup Theming & Dimensions:
   - implicitWidth: 320 and width: 320
   - color: Theme.gray900
   - radius: Theme.radiusSmall
   - border.color: Theme.borderMuted
   - border.width: Theme.borderWidth
3. Cyberpunk Corner Brackets:
   - Item id cornerBrackets with z: 10
   - bracketColor: Theme.acidGreen
   - Exactly 8 arm rectangles in Theme.acidGreen
   - Margin, arm length, thickness coupled to Theme tokens
4. Typography & Monospace Purity:
   - 100% Theme.fontFamilyMonospace on all Text elements
   - text_count == font_count (> 0)
5. Color Token Purity:
   - Zero raw #hex colors (#...); all colors use Theme tokens
6. Event Shield & Public Interface:
   - Inside click consumer MouseArea with preventStealing: true and mouse.accepted = true
   - Public signal closeRequested
7. Functional UI Elements & State Controls:
   - Power button with [PWR ON] / [PWR OFF] calling BluetoothService.togglePower()
   - Scan button with [SCAN] / [SCANNING] calling BluetoothService.toggleScan()
   - Close button calling root.closeRequested()
   - Categorized sections: Connected, Paired, Discovered
   - Device actions: connectDevice, disconnectDevice, pairDevice, forgetDevice
   - Action in-flight indicators: [WAIT...], [CONN...], [PAIRING...]
   - Refresh button calling BluetoothService.refresh()
8. AmbientBar.qml Integration:
   - Declares signal toggleBluetooth
   - Dual mouse handler: right-click togglePower(), left-click root.toggleBluetooth()
   - Section sequence: batterySection -> bluetoothSection -> clockSection
   - Section dimensions: height Theme.barHeight - 6, radius Theme.radiusMedium
   - Preferred width: bluetoothWidget.implicitWidth + Theme.paddingMedium * 2
9. Shell.qml Multi-Surface Overlay Wiring:
   - Imports desktop/surfaces/components
   - Declares property bool bluetoothVisible and property var bluetoothScreen
   - Declares function toggleBluetooth and function closeBluetooth
   - IpcHandler exposes function toggleBluetooth(): void
   - AmbientBar delegate forwards onToggleBluetooth: root.toggleBluetooth(modelData)
   - Dual PanelWindow hosts: ctos-bluetooth-backdrop (WlrLayer.Top) and ctos-bluetooth-popup (WlrLayer.Overlay)
   - Both hosts specify WlrKeyboardFocus.None
   - Mutual exclusivity: opening Bluetooth closes Calendar; opening Calendar closes Bluetooth
   - Overlay preemption: OverlayController.onOverlayOpened closes both popups
   - Disconnect cleanup: dead screen reference resets bluetoothVisible = false
10. System Rail Session Actions:
   - Declarative Process nodes: lockProcess, logoutProcess, rebootProcess, poweroffProcess
   - Allowlisted discrete binaries: loginctl, hyprctl, systemctl
   - Initialized with running: false; zero literal running: true
   - Zero shell wrappers (sh -c / bash -c)
11. Static Inspectors & Linter Validation:
   - qml_inspector check-greeter, check-polling, check-format
   - qmllint on all touched files
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell")
DESKTOP_DIR = os.path.join(SHELL_DIR, "desktop")
COMPONENTS_DIR = os.path.join(DESKTOP_DIR, "surfaces", "components")

PASS_COUNT = 0
FAIL_COUNT = 0


def check(id_str, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {id_str}: {desc}" + (f" ({details})" if details else ""))
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {id_str}: {desc}" + (f" ({details})" if details else ""), file=sys.stderr)


print("=" * 80)
print("ctOS Milestone 4: Comprehensive Bluetooth Popup & Shell Wiring AST Audit")
print("=" * 80)

# ==============================================================================
# 1. File Existence & Module Registration
# ==============================================================================
popup_path = os.path.join(COMPONENTS_DIR, "BluetoothPopup.qml")
qmldir_path = os.path.join(COMPONENTS_DIR, "qmldir")
bar_path = os.path.join(DESKTOP_DIR, "surfaces", "AmbientBar.qml")
shell_path = os.path.join(SHELL_DIR, "shell.qml")
rail_path = os.path.join(DESKTOP_DIR, "surfaces", "SystemRail.qml")

check("BT.M4.FILE.01", "BluetoothPopup.qml exists in components/", os.path.isfile(popup_path), popup_path)
check("BT.M4.FILE.02", "components/qmldir exists", os.path.isfile(qmldir_path), qmldir_path)

with open(qmldir_path, "r", encoding="utf-8") as f:
    qmldir_content = f.read()

check("BT.M4.QMLDIR.01", "BluetoothPopup 1.0 registered in qmldir",
      bool(re.search(r'BluetoothPopup\s+1\.0\s+BluetoothPopup\.qml', qmldir_content)),
      "registered as BluetoothPopup 1.0")

# ==============================================================================
# 2. BluetoothPopup Theming, Dimensions & Styling Tokens
# ==============================================================================
with open(popup_path, "r", encoding="utf-8") as f:
    popup_content = f.read()

check("BT.M4.STYLE.DIM", "implicitWidth is 320 and width is 320",
      bool(re.search(r'implicitWidth:\s*320', popup_content)) and bool(re.search(r'width:\s*320', popup_content)),
      "width=320, implicitWidth=320")

check("BT.M4.STYLE.SURFACE", "Popup uses Theme.gray900, radiusSmall, borderMuted, borderWidth",
      "color: Theme.gray900" in popup_content and
      "radius: Theme.radiusSmall" in popup_content and
      "border.color: Theme.borderMuted" in popup_content and
      "border.width: Theme.borderWidth" in popup_content,
      "cyberpunk dark surface styling verified")

# ==============================================================================
# 3. Cyberpunk Corner Brackets
# ==============================================================================
if "CornerBrackets" in popup_content:
    check("BT.M4.BRACKET.DECL", "cornerBrackets defined with bracketColor Theme.acidGreen and z: 10",
          "id: cornerBrackets" in popup_content and
          "bracketColor: Theme.acidGreen" in popup_content and
          bool(re.search(r'CornerBrackets[\s\S]*?id:\s*cornerBrackets[\s\S]*?z:\s*10', popup_content) or re.search(r'CornerBrackets[\s\S]*?z:\s*10[\s\S]*?id:\s*cornerBrackets', popup_content)),
          "corner brackets present on top z-index")

    cb_path = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/widgets/CornerBrackets.qml")
    with open(cb_path, "r", encoding="utf-8") as f:
        cb_content = f.read()
    bracket_arm_rects = re.findall(r'Rectangle\s*\{[^}]*?color:\s*root\.bracketColor[^}]*?\}', cb_content)
    check("BT.M4.BRACKET.ARMS", "Exactly 8 corner bracket arms declared in Theme.acidGreen",
          len(bracket_arm_rects) == 8,
          f"found {len(bracket_arm_rects)} arm rects")

    check("BT.M4.BRACKET.TOKENS", "Corner brackets couple to Theme margin, arm length, and thickness tokens",
          "Theme.cornerBracketMargin" in cb_content and
          "Theme.cornerBracketArmLength" in cb_content and
          "Theme.cornerBracketThickness" in cb_content,
          "corner brackets adhere strictly to Theme token metrics")
else:
    bracket_block_match = re.search(r'id:\s*cornerBrackets[\s\S]*?readonly\s+property\s+color\s+bracketColor:\s*Theme\.acidGreen([\s\S]*?)\n\s*\}', popup_content)
    check("BT.M4.BRACKET.DECL", "cornerBrackets defined with bracketColor Theme.acidGreen and z: 10",
          "id: cornerBrackets" in popup_content and
          "readonly property color bracketColor: Theme.acidGreen" in popup_content and
          bool(re.search(r'id:\s*cornerBrackets[\s\S]*?z:\s*10', popup_content)),
          "corner brackets present on top z-index")

    bracket_arm_rects = re.findall(r'Rectangle\s*\{[^}]*?color:\s*cornerBrackets\.bracketColor[^}]*?\}', popup_content)
    check("BT.M4.BRACKET.ARMS", "Exactly 8 corner bracket arms declared in Theme.acidGreen",
          len(bracket_arm_rects) == 8,
          f"found {len(bracket_arm_rects)} arm rects")

    check("BT.M4.BRACKET.TOKENS", "Corner brackets couple to Theme margin, arm length, and thickness tokens",
          "Theme.cornerBracketMargin" in popup_content and
          "Theme.cornerBracketArmLength" in popup_content and
          "Theme.cornerBracketThickness" in popup_content,
          "corner brackets adhere strictly to Theme token metrics")

# ==============================================================================
# 4. Typography & Monospace Purity
# ==============================================================================
text_blocks = re.findall(r'\bText\s*\{', popup_content)
text_count = len(text_blocks)
font_count = len(re.findall(r'font\.family:\s*Theme\.fontFamilyMonospace', popup_content))

check("BT.M4.TYPO.MONO", "100% Theme.fontFamilyMonospace compliance on all Text elements",
      text_count > 0 and text_count == font_count,
      f"Text elements={text_count}, Monospace declarations={font_count}")

# ==============================================================================
# 5. Color Token Purity (Zero Raw #Hex Colors)
# ==============================================================================
hex_matches = re.findall(r'#[0-9a-fA-F]{3,8}\b', popup_content)
check("BT.M4.TOKEN.NO_HEX", "Zero raw #hex colors (#...); 100% Theme token usage",
      len(hex_matches) == 0,
      f"raw hex matches={len(hex_matches)}")

# ==============================================================================
# 6. Event Shield & Public Interface
# ==============================================================================
check("BT.M4.SHIELD.PREVENT", "Click shield MouseArea has preventStealing: true",
      bool(re.search(r'preventStealing:\s*true', popup_content)),
      "preventStealing active")

check("BT.M4.SHIELD.ACCEPT", "Click shield MouseArea consumes events (mouse.accepted = true)",
      bool(re.search(r'mouse(?:\.accepted\s*=\s*true|\s*=>\s*mouse\.accepted\s*=\s*true)', popup_content)),
      "clicks consumed to prevent backdrop dismiss")

check("BT.M4.SIGNAL.CLOSE", "Declares public signal closeRequested",
      bool(re.search(r'signal\s+closeRequested\b', popup_content)),
      "closeRequested signal declared")

# ==============================================================================
# 7. Functional UI Elements & State Controls
# ==============================================================================
check("BT.M4.CTRL.POWER", "Power button wires BluetoothService.togglePower() with [PWR ON]/[PWR OFF]",
      "BluetoothService.togglePower()" in popup_content and
      "[PWR ON]" in popup_content and "[PWR OFF]" in popup_content,
      "power toggle control present")

check("BT.M4.CTRL.SCAN", "Scan button wires BluetoothService.toggleScan() with [SCAN]/[SCANNING]",
      "BluetoothService.toggleScan()" in popup_content and
      "[SCAN]" in popup_content and "[SCANNING]" in popup_content,
      "scan trigger control present")

check("BT.M4.CTRL.CLOSE", "Close button emits root.closeRequested()",
      bool(re.search(r'root\.closeRequested\(\)', popup_content)),
      "close button connected")

check("BT.M4.DEV.CONN", "Connected devices section renders and wires disconnectDevice",
      "BluetoothService.connectedDevices" in popup_content and
      "BluetoothService.disconnectDevice" in popup_content and
      "[DISCONNECT]" in popup_content,
      "connected devices handled")

check("BT.M4.DEV.PAIRED", "Paired devices section renders and wires connectDevice & forgetDevice",
      "BluetoothService.pairedDevices" in popup_content and
      "BluetoothService.connectDevice" in popup_content and
      "BluetoothService.forgetDevice" in popup_content and
      "[CONNECT]" in popup_content,
      "paired devices handled")

check("BT.M4.DEV.AVAIL", "Discovered devices section renders and wires pairDevice",
      "BluetoothService.availableDevices" in popup_content and
      "BluetoothService.pairDevice" in popup_content and
      "[PAIR]" in popup_content,
      "discovered devices handled")

check("BT.M4.DEV.PENDING", "Action in-flight state indicators present ([WAIT...], [CONN...], [PAIRING...])",
      "[WAIT...]" in popup_content and
      "[CONN...]" in popup_content and
      "[PAIRING...]" in popup_content and
      "BluetoothService.isActionPending" in popup_content,
      "in-flight pending indicators verified")

check("BT.M4.DEV.REFRESH", "Refresh button wires BluetoothService.refresh()",
      "BluetoothService.refresh()" in popup_content and
      "[REFRESH]" in popup_content,
      "manual refresh action present")

# ==============================================================================
# 8. AmbientBar.qml Integration
# ==============================================================================
with open(bar_path, "r", encoding="utf-8") as f:
    bar_content = f.read()

check("BT.M4.BAR.SIGNAL", "AmbientBar declares signal toggleBluetooth",
      bool(re.search(r'signal\s+toggleBluetooth\b', bar_content)),
      "signal toggleBluetooth declared")

check("BT.M4.BAR.MOUSE", "bluetoothMouseArea handles left-click (toggleBluetooth) and right-click (togglePower)",
      bool(re.search(r'acceptedButtons:\s*Qt\.LeftButton\s*\|\s*Qt\.RightButton', bar_content)) and
      bool(re.search(r'BluetoothService\.togglePower\(\)', bar_content)) and
      bool(re.search(r'root\.toggleBluetooth\(\)', bar_content)),
      "dual mouse action cleanly reconciled")

check("BT.M4.BAR.ORDER", "AmbientBar maintains slot order: batterySection -> bluetoothSection -> clockSection",
      bool(re.search(r'id:\s*batterySection[\s\S]*?id:\s*bluetoothSection[\s\S]*?id:\s*clockSection', bar_content)),
      "battery -> bluetooth -> clock slot order preserved")

check("BT.M4.BAR.METRICS", "bluetoothSection preserves height Theme.barHeight - 6 and radius Theme.radiusMedium",
      bool(re.search(r'id:\s*bluetoothSection[\s\S]*?height:\s*Theme\.barHeight\s*-\s*6[\s\S]*?radius:\s*Theme\.radiusMedium', bar_content)),
      "height=34, radius=8 verified")

# ==============================================================================
# 9. Shell.qml Overlay & Wiring Integration
# ==============================================================================
with open(shell_path, "r", encoding="utf-8") as f:
    shell_content = f.read()

check("BT.M4.SHELL.IMPORT", "shell.qml imports desktop/surfaces/components",
      bool(re.search(r'import\s+"desktop/surfaces/components"', shell_content)),
      "components imported")

check("BT.M4.SHELL.PROPS", "shell.qml declares bluetoothVisible and bluetoothScreen properties",
      bool(re.search(r'property\s+bool\s+bluetoothVisible:\s*false', shell_content)) and
      bool(re.search(r'property\s+var\s+bluetoothScreen:\s*null', shell_content)),
      "bluetoothVisible & bluetoothScreen properties declared")

check("BT.M4.SHELL.METHODS", "shell.qml declares toggleBluetooth and closeBluetooth methods",
      bool(re.search(r'function\s+toggleBluetooth\s*\(\s*targetScreen\s*\):\s*void', shell_content)) and
      bool(re.search(r'function\s+closeBluetooth\s*\(\s*\):\s*void', shell_content)),
      "toggleBluetooth & closeBluetooth declared")

check("BT.M4.SHELL.IPC", "shell.qml IpcHandler exposes toggleBluetooth",
      bool(re.search(r'IpcHandler\s*\{[\s\S]*?function\s+toggleBluetooth\(\):\s*void', shell_content)),
      "IpcHandler toggleBluetooth exposed")

check("BT.M4.SHELL.FORWARD", "barVariants forwards onToggleBluetooth to root.toggleBluetooth(modelData)",
      bool(re.search(r'onToggleBluetooth:\s*root\.toggleBluetooth\(modelData\)', shell_content)),
      "bar variant delegate forwards modelData")

check("BT.M4.SHELL.MUTUAL_BT", "toggleBluetooth invokes root.closeCalendar()",
      bool(re.search(r'function\s+toggleBluetooth[\s\S]*?root\.closeCalendar\(\)', shell_content)),
      "opening bluetooth dismisses calendar")

check("BT.M4.SHELL.MUTUAL_CAL", "toggleCalendar invokes root.closeBluetooth()",
      bool(re.search(r'function\s+toggleCalendar[\s\S]*?root\.closeBluetooth\(\)', shell_content)),
      "opening calendar dismisses bluetooth")

check("BT.M4.SHELL.PREEMPT", "OverlayController.onOverlayOpened closes both popups",
      bool(re.search(r'target:\s*OverlayController[\s\S]*?function\s+onOverlayOpened[\s\S]*?root\.closeCalendar\(\)[\s\S]*?root\.closeBluetooth\(\)', shell_content)),
      "preemption triggers cleanup on both popups")

check("BT.M4.SHELL.DISCONNECT", "Quickshell.onScreensChanged verifies and closes bluetooth if disconnected",
      bool(re.search(r'target:\s*Quickshell[\s\S]*?function\s+onScreensChanged[\s\S]*?root\.bluetoothVisible[\s\S]*?root\.bluetoothScreen[\s\S]*?root\.closeBluetooth\(\)', shell_content)),
      "disconnect handler protects against dangling screen")

check("BT.M4.SHELL.BACKDROP", "bluetoothBackdropHost configured on WlrLayer.Top with ctos-bluetooth-backdrop namespace",
      bool(re.search(r'PanelWindow\s*\{[\s\S]*?id:\s*bluetoothBackdropHost[\s\S]*?WlrLayershell\.layer:\s*WlrLayer\.Top[\s\S]*?WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None[\s\S]*?WlrLayershell\.namespace:\s*"ctos-bluetooth-backdrop"', shell_content)),
      "backdrop layer host configured correctly")

check("BT.M4.SHELL.BACKDROP_CLICK", "bluetoothBackdropHost mouse area triggers root.closeBluetooth()",
      bool(re.search(r'id:\s*bluetoothBackdropHost[\s\S]*?MouseArea\s*\{[\s\S]*?onClicked:\s*root\.closeBluetooth\(\)', shell_content)),
      "outside click dismisses popup")

check("BT.M4.SHELL.POPUP_HOST", "bluetoothPopupHost configured on WlrLayer.Overlay with ctos-bluetooth-popup namespace",
      bool(re.search(r'PanelWindow\s*\{[\s\S]*?id:\s*bluetoothPopupHost[\s\S]*?WlrLayershell\.layer:\s*WlrLayer\.Overlay[\s\S]*?WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None[\s\S]*?WlrLayershell\.namespace:\s*"ctos-bluetooth-popup"', shell_content)),
      "popup layer host configured correctly")

check("BT.M4.SHELL.POPUP_MOUNT", "bluetoothPopupHost mounts BluetoothPopup and wires onCloseRequested to root.closeBluetooth()",
      bool(re.search(r'id:\s*bluetoothPopupHost[\s\S]*?BluetoothPopup\s*\{[\s\S]*?onCloseRequested:\s*root\.closeBluetooth\(\)', shell_content)),
      "BluetoothPopup mounted with dismiss wiring")

# ==============================================================================
# 10. System Rail Session Actions Audit
# ==============================================================================
with open(rail_path, "r", encoding="utf-8") as f:
    rail_content = f.read()

check("BT.M4.RAIL.PROCESSES", "SystemRail declares lockProcess, logoutProcess, rebootProcess, poweroffProcess",
      "id: lockProcess" in rail_content and
      "id: logoutProcess" in rail_content and
      "id: rebootProcess" in rail_content and
      "id: poweroffProcess" in rail_content,
      "all 4 declarative Process nodes declared")

check("BT.M4.RAIL.CMDS", "SystemRail session processes use allowlisted discrete command arrays",
      bool(re.search(r'id:\s*lockProcess[\s\S]*?command:\s*\[\s*"loginctl",\s*"lock-session"\s*\]', rail_content)) and
      bool(re.search(r'id:\s*logoutProcess[\s\S]*?command:\s*\[\s*"hyprctl",\s*"dispatch",\s*"exit"\s*\]', rail_content)) and
      bool(re.search(r'id:\s*rebootProcess[\s\S]*?command:\s*\[\s*"systemctl",\s*"reboot"\s*\]', rail_content)) and
      bool(re.search(r'id:\s*poweroffProcess[\s\S]*?command:\s*\[\s*"systemctl",\s*"poweroff"\s*\]', rail_content)),
      "discrete arrays without shell wrappers verified")

check("BT.M4.RAIL.SAFETY", "SystemRail processes initialize with running: false and zero running: true",
      rail_content.count("running: false") >= 4 and
      rail_content.count("running: true") == 0,
      f"running:false count={rail_content.count('running: false')}, running:true count={rail_content.count('running: true')}")

# ==============================================================================
# 11. Static Inspectors & Linter Validation
# ==============================================================================
greet_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"],
                           capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.M4.STATIC.GREETER", "check-greeter reports zero violations across shell/desktop",
      greet_res.returncode == 0, greet_res.stdout.strip())

poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.M4.STATIC.POLLING", "check-polling reports zero violations across shell/desktop",
      poll_res.returncode == 0, poll_res.stdout.strip())

fmt_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.M4.STATIC.FORMAT", "check-format reports zero violations across shell/desktop",
      fmt_res.returncode == 0, fmt_res.stdout.strip())

qmllint_res = subprocess.run(["qmllint", "-I", "shell/desktop", popup_path, bar_path, shell_path, rail_path],
                             capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.M4.STATIC.QMLLINT", "qmllint succeeds on BluetoothPopup, AmbientBar, shell.qml, and SystemRail",
      qmllint_res.returncode == 0, "syntax verification clean")

print("=" * 80)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 4 BLUETOOTH & SYSTEM ACTION AUDITS PASSED CLEANLY ===")
else:
    print("=== MILESTONE 4 AUDITS FAILED ===", file=sys.stderr)
print("=" * 80)

sys.exit(0 if FAIL_COUNT == 0 else 1)
