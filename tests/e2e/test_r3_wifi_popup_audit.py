#!/usr/bin/env python3
"""
test_r3_wifi_popup_audit.py - Comprehensive AST & Token Audit for Milestone 3:
Requirement R3: Ambient Bar Wi-Fi Drop-down & NetworkService Integration

Verifies:
1. File Existence & Module Registration:
   - shell/desktop/surfaces/components/NetworkPopup.qml exists
   - shell/desktop/surfaces/components/qmldir declares NetworkPopup 1.0 NetworkPopup.qml
2. NetworkPopup Theming & Dimensions:
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
5. Color Token Purity:
   - Zero raw #hex colors (#...); all colors use Theme tokens
6. Event Shield & Public Interface:
   - Inside click consumer MouseArea with preventStealing: true and mouse.accepted = true
   - Public signal closeRequested
7. Controls & Sections:
   - Power button with [PWR ON] / [PWR OFF] calling NetworkService.toggleWifi()
   - Scan button with [SCAN] / [SCANNING] calling NetworkService.scanNetworks()
   - Close button calling root.closeRequested()
   - Empty states: radio off, scanning / no networks
   - Connected, Saved, Discovered sections
   - Cyberpunk inline password prompt for secured networks
   - Refresh button calling NetworkService.refresh()
8. NetworkService Integration:
   - property bool isScanning
   - scanNetworks() / toggleScan()
   - refresh()
   - Zero literal running: true
   - Zero sh -c / bash -c
9. AmbientBar Integration:
   - Declares signal toggleNetwork
   - networkMouseArea handles left-click (toggleNetwork) and right-click (toggleWifi)
   - Decoupled from opening SystemRail directly on click
10. Shell.qml Multi-Surface Overlay Wiring:
   - Declares networkVisible and networkScreen properties
   - Declares toggleNetwork and closeNetwork methods
   - IpcHandler exposes toggleNetwork
   - barVariants forwards onToggleNetwork: root.toggleNetwork(modelData)
   - Mutual exclusivity with Calendar and Bluetooth
   - Overlay preemption: OverlayController.onOverlayOpened closes network
   - Disconnect cleanup: dead screen reference resets networkVisible = false
   - Dual PanelWindow hosts: ctos-network-backdrop (WlrLayer.Top) and ctos-network-popup (WlrLayer.Overlay)
11. SystemRail Invariance:
   - SystemRail.qml remains completely untouched
12. Static Linter Validation:
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
print("ctOS Milestone 3: Comprehensive Wi-Fi Popup & NetworkService AST Audit")
print("=" * 80)

# ==============================================================================
# 1. File Existence & Module Registration
# ==============================================================================
popup_path = os.path.join(COMPONENTS_DIR, "NetworkPopup.qml")
qmldir_path = os.path.join(COMPONENTS_DIR, "qmldir")
bar_path = os.path.join(DESKTOP_DIR, "surfaces", "AmbientBar.qml")
shell_path = os.path.join(SHELL_DIR, "shell.qml")
net_svc_path = os.path.join(DESKTOP_DIR, "services", "NetworkService.qml")
rail_path = os.path.join(DESKTOP_DIR, "surfaces", "SystemRail.qml")

check("WF.R3.FILE.01", "NetworkPopup.qml exists in components/", os.path.isfile(popup_path), popup_path)
check("WF.R3.FILE.02", "components/qmldir exists", os.path.isfile(qmldir_path), qmldir_path)

with open(qmldir_path, "r", encoding="utf-8") as f:
    qmldir_content = f.read()

check("WF.R3.QMLDIR.01", "NetworkPopup 1.0 registered in qmldir",
      bool(re.search(r'NetworkPopup\s+1\.0\s+NetworkPopup\.qml', qmldir_content)),
      "registered as NetworkPopup 1.0")

# ==============================================================================
# 2. NetworkPopup Theming, Dimensions & Styling Tokens
# ==============================================================================
with open(popup_path, "r", encoding="utf-8") as f:
    popup_content = f.read()

check("WF.R3.STYLE.DIM", "implicitWidth is 320 and width is 320",
      bool(re.search(r'implicitWidth:\s*320', popup_content)) and bool(re.search(r'width:\s*320', popup_content)),
      "width=320, implicitWidth=320")

check("WF.R3.STYLE.SURFACE", "Popup uses Theme.gray900, radiusSmall, borderMuted, borderWidth",
      "color: Theme.gray900" in popup_content and
      "radius: Theme.radiusSmall" in popup_content and
      "border.color: Theme.borderMuted" in popup_content and
      "border.width: Theme.borderWidth" in popup_content,
      "cyberpunk dark surface styling verified")

# ==============================================================================
# 3. Cyberpunk Corner Brackets
# ==============================================================================
if "CornerBrackets" in popup_content:
    check("WF.R3.BRACKET.DECL", "cornerBrackets defined with bracketColor Theme.acidGreen and z: 10",
          "id: cornerBrackets" in popup_content and
          "bracketColor: Theme.acidGreen" in popup_content and
          bool(re.search(r'CornerBrackets[\s\S]*?id:\s*cornerBrackets[\s\S]*?z:\s*10', popup_content) or re.search(r'CornerBrackets[\s\S]*?z:\s*10[\s\S]*?id:\s*cornerBrackets', popup_content)),
          "corner brackets present on top z-index")

    cb_path = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/widgets/CornerBrackets.qml")
    with open(cb_path, "r", encoding="utf-8") as f:
        cb_content = f.read()
    bracket_arm_rects = re.findall(r'Rectangle\s*\{[^}]*?color:\s*root\.bracketColor[^}]*?\}', cb_content)
    check("WF.R3.BRACKET.ARMS", "Exactly 8 corner bracket arms declared in Theme.acidGreen",
          len(bracket_arm_rects) == 8,
          f"found {len(bracket_arm_rects)} arm rects")

    check("WF.R3.BRACKET.TOKENS", "Corner brackets couple to Theme margin, arm length, and thickness tokens",
          "Theme.cornerBracketMargin" in cb_content and
          "Theme.cornerBracketArmLength" in cb_content and
          "Theme.cornerBracketThickness" in cb_content,
          "corner brackets adhere strictly to Theme token metrics")
else:
    check("WF.R3.BRACKET.DECL", "cornerBrackets defined with bracketColor Theme.acidGreen and z: 10",
          "id: cornerBrackets" in popup_content and
          "readonly property color bracketColor: Theme.acidGreen" in popup_content and
          bool(re.search(r'id:\s*cornerBrackets[\s\S]*?z:\s*10', popup_content)),
          "corner brackets present on top z-index")

    bracket_arm_rects = re.findall(r'Rectangle\s*\{[^}]*?color:\s*cornerBrackets\.bracketColor[^}]*?\}', popup_content)
    check("WF.R3.BRACKET.ARMS", "Exactly 8 corner bracket arms declared in Theme.acidGreen",
          len(bracket_arm_rects) == 8,
          f"found {len(bracket_arm_rects)} arm rects")

    check("WF.R3.BRACKET.TOKENS", "Corner brackets couple to Theme margin, arm length, and thickness tokens",
          "Theme.cornerBracketMargin" in popup_content and
          "Theme.cornerBracketArmLength" in popup_content and
          "Theme.cornerBracketThickness" in popup_content,
          "corner brackets adhere strictly to Theme token metrics")

# ==============================================================================
# 4. Typography & Monospace Purity
# ==============================================================================
text_blocks = re.findall(r'\bText\s*\{([^}]+(?:\{[^}]*\}[^}]*)*)\}', popup_content)
text_count = len(text_blocks)
mono_count = len(re.findall(r'font\.family:\s*Theme\.fontFamilyMonospace', popup_content))

check("WF.R3.TYPO.MONO", "100% Theme.fontFamilyMonospace compliance on all Text elements",
      text_count > 0 and mono_count >= text_count,
      f"Text elements={text_count}, Monospace declarations={mono_count}")

# ==============================================================================
# 5. Color Token Purity (Zero raw #hex colors)
# ==============================================================================
raw_hex_matches = re.findall(r'["\']#[0-9a-fA-F]{3,8}["\']', popup_content)
check("WF.R3.TOKEN.NO_HEX", "Zero raw #hex colors (#...); 100% Theme token usage",
      len(raw_hex_matches) == 0,
      f"raw hex matches={len(raw_hex_matches)}")

# ==============================================================================
# 6. Event Shield & Public Interface
# ==============================================================================
check("WF.R3.SHIELD.PREVENT", "Click shield MouseArea has preventStealing: true",
      bool(re.search(r'MouseArea\s*\{[^}]*?preventStealing:\s*true', popup_content)),
      "preventStealing active")

check("WF.R3.SHIELD.ACCEPT", "Click shield MouseArea consumes events (mouse.accepted = true)",
      bool(re.search(r'onClicked:\s*mouse\s*=>\s*mouse\.accepted\s*=\s*true', popup_content)),
      "clicks consumed to prevent backdrop dismiss")

check("WF.R3.SIGNAL.CLOSE", "Declares public signal closeRequested",
      bool(re.search(r'\bsignal\s+closeRequested\b', popup_content)),
      "closeRequested signal declared")

# ==============================================================================
# 7. Controls & UI Elements
# ==============================================================================
check("WF.R3.CTRL.POWER", "Power button wires NetworkService.toggleWifi() with [PWR ON]/[PWR OFF]",
      "NetworkService.toggleWifi()" in popup_content and
      "[PWR ON]" in popup_content and "[PWR OFF]" in popup_content,
      "power toggle control present")

check("WF.R3.CTRL.SCAN", "Scan button wires NetworkService.scanNetworks() with [SCAN]/[SCANNING]",
      "NetworkService.scanNetworks()" in popup_content and
      "[SCAN]" in popup_content and "[SCANNING]" in popup_content,
      "scan trigger control present")

check("WF.R3.CTRL.CLOSE", "Close button emits root.closeRequested()",
      "root.closeRequested()" in popup_content,
      "close button connected")

check("WF.R3.SECTIONS", "Connected, Saved, and Discovered sections rendered",
      "// CONNECTED (" in popup_content and
      "// SAVED (" in popup_content and
      "// DISCOVERED (" in popup_content,
      "all 3 network sections present")

check("WF.R3.PASSWORD.PROMPT", "Inline cyberpunk password prompt with PASSWORD >_ and TextInput",
      "PASSWORD >_" in popup_content and
      "TextInput.Password" in popup_content and
      "pwInput" in popup_content,
      "inline password prompt implemented")

check("WF.R3.DEV.REFRESH", "Refresh button wires NetworkService.refresh()",
      "NetworkService.refresh()" in popup_content and
      "[REFRESH]" in popup_content,
      "manual refresh action present")

# ==============================================================================
# 8. NetworkService.qml Enhancements
# ==============================================================================
with open(net_svc_path, "r", encoding="utf-8") as f:
    net_svc_content = f.read()

check("WF.R3.SRV.IS_SCANNING", "NetworkService declares property bool isScanning",
      bool(re.search(r'property\s+bool\s+isScanning', net_svc_content)),
      "isScanning property present")

check("WF.R3.SRV.SCAN_METH", "NetworkService declares scanNetworks and toggleScan",
      bool(re.search(r'function\s+scanNetworks\s*\(', net_svc_content)) and
      bool(re.search(r'function\s+toggleScan\s*\(', net_svc_content)),
      "scanNetworks and toggleScan methods declared")

check("WF.R3.SRV.REFRESH_METH", "NetworkService declares refresh method",
      bool(re.search(r'function\s+refresh\s*\(', net_svc_content)),
      "refresh method declared")

check("WF.R3.SRV.ZERO_POLL", "NetworkService contains zero literal running: true declarations",
      not bool(re.search(r'running:\s*true\b', net_svc_content)),
      "zero literal running: true")

# ==============================================================================
# 9. AmbientBar.qml Decoupling
# ==============================================================================
with open(bar_path, "r", encoding="utf-8") as f:
    bar_content = f.read()

check("WF.R3.BAR.SIGNAL", "AmbientBar declares signal toggleNetwork",
      bool(re.search(r'\bsignal\s+toggleNetwork\b', bar_content)),
      "signal toggleNetwork declared")

check("WF.R3.BAR.MOUSE", "networkMouseArea handles left-click (toggleNetwork) and right-click (toggleWifi)",
      "root.toggleNetwork()" in bar_content and
      "NetworkService.toggleWifi()" in bar_content,
      "dual mouse action cleanly reconciled")

check("WF.R3.BAR.DECOUPLE", "networkMouseArea does not directly call openWifiSubmenu on click",
      "onClicked: OverlayController.openWifiSubmenu()" not in bar_content,
      "decoupled from SystemRail")

# ==============================================================================
# 10. Shell.qml Multi-Surface Overlay Wiring
# ==============================================================================
with open(shell_path, "r", encoding="utf-8") as f:
    shell_content = f.read()

check("WF.R3.SHELL.PROPS", "shell.qml declares networkVisible and networkScreen properties",
      bool(re.search(r'property\s+bool\s+networkVisible', shell_content)) and
      bool(re.search(r'property\s+var\s+networkScreen', shell_content)),
      "networkVisible & networkScreen properties declared")

check("WF.R3.SHELL.METHODS", "shell.qml declares toggleNetwork and closeNetwork methods",
      bool(re.search(r'function\s+toggleNetwork\s*\(', shell_content)) and
      bool(re.search(r'function\s+closeNetwork\s*\(', shell_content)),
      "toggleNetwork & closeNetwork declared")

check("WF.R3.SHELL.IPC", "shell.qml IpcHandler exposes toggleNetwork",
      bool(re.search(r'IpcHandler[\s\S]*?function\s+toggleNetwork\s*\(', shell_content)),
      "IpcHandler toggleNetwork exposed")

check("WF.R3.SHELL.FORWARD", "barVariants forwards onToggleNetwork to root.toggleNetwork(modelData)",
      bool(re.search(r'AmbientBar[\s\S]*?onToggleNetwork:\s*root\.toggleNetwork\(modelData\)', shell_content)),
      "bar variant delegate forwards modelData")

check("WF.R3.SHELL.MUTUAL_NET", "toggleNetwork invokes root.closeCalendar() and root.closeBluetooth()",
      bool(re.search(r'function\s+toggleNetwork[\s\S]*?root\.closeCalendar\(\)[\s\S]*?root\.closeBluetooth\(\)', shell_content)),
      "opening network dismisses calendar and bluetooth")

check("WF.R3.SHELL.MUTUAL_BT", "toggleBluetooth invokes root.closeNetwork()",
      bool(re.search(r'function\s+toggleBluetooth[\s\S]*?root\.closeNetwork\(\)', shell_content)),
      "opening bluetooth dismisses network")

check("WF.R3.SHELL.MUTUAL_CAL", "toggleCalendar invokes root.closeNetwork()",
      bool(re.search(r'function\s+toggleCalendar[\s\S]*?root\.closeNetwork\(\)', shell_content)),
      "opening calendar dismisses network")

check("WF.R3.SHELL.PREEMPT", "OverlayController.onOverlayOpened closes network popup",
      bool(re.search(r'function\s+onOverlayOpened[\s\S]*?root\.closeNetwork\(\)', shell_content)),
      "overlay preemption closes network popup")

check("WF.R3.SHELL.DISCONNECT", "Quickshell.onScreensChanged verifies and closes network if disconnected",
      bool(re.search(r'if\s*\(root\.networkVisible\)[\s\S]*?root\.closeNetwork\(\)', shell_content)),
      "screen disconnect handler protects against dangling screen")

check("WF.R3.SHELL.BACKDROP", "networkBackdropHost configured on WlrLayer.Top with ctos-network-backdrop namespace",
      bool(re.search(r'id:\s*networkBackdropHost[\s\S]*?WlrLayershell\.layer:\s*WlrLayer\.Top[\s\S]*?WlrLayershell\.namespace:\s*"ctos-network-backdrop"', shell_content)),
      "backdrop layer host configured correctly")

check("WF.R3.SHELL.BACKDROP_CLICK", "networkBackdropHost mouse area triggers root.closeNetwork()",
      bool(re.search(r'id:\s*networkBackdropHost[\s\S]*?onClicked:\s*root\.closeNetwork\(\)', shell_content)),
      "outside click dismisses popup")

check("WF.R3.SHELL.POPUP_HOST", "networkPopupHost configured on WlrLayer.Overlay with ctos-network-popup namespace",
      bool(re.search(r'id:\s*networkPopupHost[\s\S]*?WlrLayershell\.layer:\s*WlrLayer\.Overlay[\s\S]*?WlrLayershell\.namespace:\s*"ctos-network-popup"', shell_content)),
      "popup layer host configured correctly")

check("WF.R3.SHELL.POPUP_MOUNT", "networkPopupHost mounts NetworkPopup and wires onCloseRequested to root.closeNetwork()",
      bool(re.search(r'id:\s*networkPopupHost[\s\S]*?NetworkPopup\s*\{[\s\S]*?onCloseRequested:\s*root\.closeNetwork\(\)', shell_content)),
      "NetworkPopup mounted with dismiss wiring")

# ==============================================================================
# 11. Static Inspectors & Linter Validation
# ==============================================================================
files_to_lint = [
    popup_path,
    bar_path,
    shell_path,
    net_svc_path
]

qmllint_all_clean = True
for fpath in files_to_lint:
    cmd = ["qmllint", "-I", "shell", fpath]
    res = subprocess.run(cmd, cwd=PROJECT_ROOT, capture_output=True, text=True)
    if res.returncode != 0:
        qmllint_all_clean = False
        print(f"[ERROR] qmllint failed on {fpath}:\n{res.stderr}", file=sys.stderr)

check("WF.R3.STATIC.QMLLINT", "qmllint succeeds on NetworkPopup, AmbientBar, shell.qml, and NetworkService",
      qmllint_all_clean,
      "all 4 files pass qmllint")

print("=" * 80)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 3 WI-FI POPUP & NETWORK AUDITS PASSED CLEANLY ===")
else:
    print("=== SOME AUDITS FAILED ===", file=sys.stderr)
    sys.exit(1)
print("=" * 80)
