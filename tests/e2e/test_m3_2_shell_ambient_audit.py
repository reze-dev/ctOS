#!/usr/bin/env python3
"""
test_m3_2_shell_ambient_audit.py - AST & Invariant Verification Suite for Milestone 3.2:
Empirically verifies shell/shell.qml and AmbientBar.qml integration for the Bluetooth drop-down module.
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell")
DESKTOP_DIR = os.path.join(SHELL_DIR, "desktop")

PASS_COUNT = 0
FAIL_COUNT = 0
FINDINGS = []


def record(test_id, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {test_id}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        FINDINGS.append((test_id, desc, details))
        print(f"[FAIL] {test_id}: {desc} ({details})", file=sys.stderr)


def extract_enclosing_block(content, target):
    """Extracts the enclosing QML element block containing the target string."""
    idx = content.find(target)
    if idx == -1:
        return None
    brace_start = content.rfind("{", 0, idx)
    if brace_start == -1:
        return None
    depth = 0
    for i in range(brace_start, len(content)):
        if content[i] == "{":
            depth += 1
        elif content[i] == "}":
            depth -= 1
            if depth == 0:
                return content[brace_start + 1:i]
    return None


print("=" * 80)
print("ctOS Empirical Challenger: M3.2 Shell & AmbientBar Integration Audit")
print("=" * 80)

# ==============================================================================
# 1. Dual PanelWindow Declarations in shell/shell.qml
# ==============================================================================
print("\n--- Section 1: Dual PanelWindow Declarations in shell/shell.qml ---")
shell_path = os.path.join(SHELL_DIR, "shell.qml")
record("SHELL.FILE.01", "shell/shell.qml exists", os.path.isfile(shell_path), f"path={shell_path}")

with open(shell_path, "r", encoding="utf-8") as f:
    shell_content = f.read()

# 1.1 State properties
record(
    "SHELL.PROP.BT_VIS",
    "shell.qml declares property bool bluetoothVisible",
    bool(re.search(r'property\s+bool\s+bluetoothVisible\s*:\s*false', shell_content)),
    "bluetoothVisible initialized to false"
)
record(
    "SHELL.PROP.BT_SCR",
    "shell.qml declares property var bluetoothScreen",
    bool(re.search(r'property\s+var\s+bluetoothScreen\s*:\s*null', shell_content)),
    "bluetoothScreen initialized to null"
)

# 1.2 Backdrop PanelWindow
b_body = extract_enclosing_block(shell_content, "id: bluetoothBackdropHost")
record(
    "SHELL.BACKDROP.EXISTS",
    "bluetoothBackdropHost PanelWindow declared",
    b_body is not None,
    "id: bluetoothBackdropHost"
)

if b_body:
    record(
        "SHELL.BACKDROP.LAYER",
        "bluetoothBackdropHost layer is WlrLayer.Top",
        bool(re.search(r'WlrLayershell\.layer\s*:\s*WlrLayer\.Top', b_body)),
        "WlrLayer.Top"
    )
    record(
        "SHELL.BACKDROP.FOCUS",
        "bluetoothBackdropHost keyboardFocus is WlrKeyboardFocus.None",
        bool(re.search(r'WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.None', b_body)),
        "WlrKeyboardFocus.None"
    )
    record(
        "SHELL.BACKDROP.EXCLUSION",
        "bluetoothBackdropHost exclusionMode is ExclusionMode.Ignore",
        bool(re.search(r'exclusionMode\s*:\s*ExclusionMode\.Ignore', b_body)),
        "ExclusionMode.Ignore"
    )
    record(
        "SHELL.BACKDROP.NS",
        "bluetoothBackdropHost namespace is 'ctos-bluetooth-backdrop'",
        bool(re.search(r'WlrLayershell\.namespace\s*:\s*"ctos-bluetooth-backdrop"', b_body)),
        "namespace: ctos-bluetooth-backdrop"
    )
    record(
        "SHELL.BACKDROP.SCREEN",
        "bluetoothBackdropHost bound to root.bluetoothScreen",
        bool(re.search(r'screen\s*:\s*root\.bluetoothScreen', b_body)),
        "screen: root.bluetoothScreen"
    )
    record(
        "SHELL.BACKDROP.VIS",
        "bluetoothBackdropHost visibility requires bluetoothVisible and bluetoothScreen !== null",
        bool(re.search(r'visible\s*:\s*root\.bluetoothVisible\s*&&\s*root\.bluetoothScreen\s*!==\s*null', b_body)),
        "visible condition guarded"
    )
    record(
        "SHELL.BACKDROP.DISMISS",
        "bluetoothBackdropHost MouseArea dismisses via root.closeBluetooth()",
        bool(re.search(r'MouseArea\s*\{[\s\S]*?onClicked\s*:\s*root\.closeBluetooth\(\)', b_body)),
        "onClicked: root.closeBluetooth()"
    )

# 1.3 Popup PanelWindow
p_body = extract_enclosing_block(shell_content, "id: bluetoothPopupHost")
record(
    "SHELL.POPUP.EXISTS",
    "bluetoothPopupHost PanelWindow declared",
    p_body is not None,
    "id: bluetoothPopupHost"
)

if p_body:
    record(
        "SHELL.POPUP.LAYER",
        "bluetoothPopupHost layer is WlrLayer.Overlay",
        bool(re.search(r'WlrLayershell\.layer\s*:\s*WlrLayer\.Overlay', p_body)),
        "WlrLayer.Overlay"
    )
    record(
        "SHELL.POPUP.FOCUS",
        "bluetoothPopupHost keyboardFocus is WlrKeyboardFocus.None",
        bool(re.search(r'WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.None', p_body)),
        "WlrKeyboardFocus.None"
    )
    record(
        "SHELL.POPUP.EXCLUSION",
        "bluetoothPopupHost exclusionMode is ExclusionMode.Ignore",
        bool(re.search(r'exclusionMode\s*:\s*ExclusionMode\.Ignore', p_body)),
        "ExclusionMode.Ignore"
    )
    record(
        "SHELL.POPUP.NS",
        "bluetoothPopupHost namespace is 'ctos-bluetooth-popup'",
        bool(re.search(r'WlrLayershell\.namespace\s*:\s*"ctos-bluetooth-popup"', p_body)),
        "namespace: ctos-bluetooth-popup"
    )
    record(
        "SHELL.POPUP.SCREEN",
        "bluetoothPopupHost bound to root.bluetoothScreen",
        bool(re.search(r'screen\s*:\s*root\.bluetoothScreen', p_body)),
        "screen: root.bluetoothScreen"
    )
    record(
        "SHELL.POPUP.VIS",
        "bluetoothPopupHost visibility requires bluetoothVisible and bluetoothScreen !== null",
        bool(re.search(r'visible\s*:\s*root\.bluetoothVisible\s*&&\s*root\.bluetoothScreen\s*!==\s*null', p_body)),
        "visible condition guarded"
    )
    record(
        "SHELL.POPUP.MARGIN_TOP",
        "bluetoothPopupHost top margin is Settings.barHeight + Theme.spacingMedium",
        bool(re.search(r'top\s*:\s*Settings\.barHeight\s*\+\s*Theme\.spacingMedium', p_body)),
        "top margin: Settings.barHeight + Theme.spacingMedium"
    )
    record(
        "SHELL.POPUP.MARGIN_RIGHT",
        "bluetoothPopupHost right margin is Theme.barPaddingHorizontal + 60",
        bool(re.search(r'right\s*:\s*Theme\.barPaddingHorizontal\s*\+\s*60', p_body)),
        "right margin: Theme.barPaddingHorizontal + 60"
    )
    record(
        "SHELL.POPUP.COMPONENT",
        "bluetoothPopupHost mounts BluetoothPopup with onCloseRequested: root.closeBluetooth()",
        bool(re.search(r'BluetoothPopup\s*\{[\s\S]*?onCloseRequested\s*:\s*root\.closeBluetooth\(\)', p_body)),
        "BluetoothPopup mounted and wired"
    )

# ==============================================================================
# 2. AmbientBar.qml Invariants & Dual-Click Behavior
# ==============================================================================
print("\n--- Section 2: AmbientBar.qml Invariants & Dual-Click Behavior ---")
bar_path = os.path.join(DESKTOP_DIR, "surfaces", "AmbientBar.qml")
record("BAR.FILE.01", "AmbientBar.qml exists", os.path.isfile(bar_path), f"path={bar_path}")

with open(bar_path, "r", encoding="utf-8") as f:
    bar_content = f.read()

# 2.1 Signal declaration
record(
    "BAR.SIG.01",
    "AmbientBar declares signal toggleBluetooth",
    bool(re.search(r'signal\s+toggleBluetooth\b', bar_content)),
    "signal toggleBluetooth"
)

# 2.2 Layout sequence
record(
    "BAR.LAYOUT.SEQ",
    "AmbientBar sequences batterySection -> bluetoothSection -> clockSection",
    bool(re.search(r'id\s*:\s*batterySection[\s\S]*?id\s*:\s*bluetoothSection[\s\S]*?id\s*:\s*clockSection', bar_content)),
    "battery -> bluetooth -> clock"
)

# 2.3 Slot index in rightSections
r_body = extract_enclosing_block(bar_content, "id: rightSections")
record("BAR.LAYOUT.ROW", "rightSections RowLayout identified", r_body is not None)

if r_body:
    sections = re.findall(r'Rectangle\s*\{\s*id\s*:\s*([A-Za-z0-9_]+)', r_body)
    record(
        "BAR.LAYOUT.COUNT",
        "rightSections contains 6 sections (network, volume, battery, bluetooth, clock, rail)",
        len(sections) == 6,
        f"sections={sections}"
    )
    bt_idx = sections.index("bluetoothSection") if "bluetoothSection" in sections else -1
    record(
        "BAR.LAYOUT.SLOT3",
        "bluetoothSection is exactly at slot index 3",
        bt_idx == 3,
        f"index={bt_idx} (sections: {sections})"
    )

# 2.4 Dimensions & Radius
record(
    "BAR.DIM.HEIGHT",
    "bluetoothSection height is Theme.barHeight - 6 (34px)",
    bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?height\s*:\s*Theme\.barHeight\s*-\s*6', bar_content)),
    "height: Theme.barHeight - 6"
)
record(
    "BAR.DIM.RADIUS",
    "bluetoothSection radius is Theme.radiusMedium (8px)",
    bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?radius\s*:\s*Theme\.radiusMedium', bar_content)),
    "radius: Theme.radiusMedium"
)
record(
    "BAR.DIM.PREF_H",
    "bluetoothSection Layout.preferredHeight couples to Theme.barHeight - 6",
    bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?Layout\.preferredHeight\s*:\s*Theme\.barHeight\s*-\s*6', bar_content)),
    "Layout.preferredHeight: Theme.barHeight - 6"
)
record(
    "BAR.DIM.PREF_W",
    "bluetoothSection Layout.preferredWidth couples to bluetoothWidget.implicitWidth + Theme.paddingMedium * 2",
    bool(re.search(r'Layout\.preferredWidth\s*:\s*bluetoothWidget\.implicitWidth\s*\+\s*Theme\.paddingMedium\s*\*\s*2', bar_content)),
    "Layout.preferredWidth bound with padding"
)
record(
    "BAR.VIS.AVAIL",
    "bluetoothSection visible bound to BluetoothService.available",
    bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?visible\s*:\s*BluetoothService\.available', bar_content)),
    "visible: BluetoothService.available"
)

# 2.5 Dual-click behavior in bluetoothMouseArea
ma_body = extract_enclosing_block(bar_content, "id: bluetoothMouseArea")
record("BAR.CLICK.MA", "bluetoothMouseArea found inside bluetoothSection", ma_body is not None)

if ma_body:
    record(
        "BAR.CLICK.BUTTONS",
        "bluetoothMouseArea accepts LeftButton and RightButton",
        bool(re.search(r'acceptedButtons\s*:\s*Qt\.LeftButton\s*\|\s*Qt\.RightButton', ma_body)),
        "Qt.LeftButton | Qt.RightButton"
    )
    has_rt = "Qt.RightButton" in ma_body and "BluetoothService.togglePower()" in ma_body
    has_lt = "root.toggleBluetooth()" in ma_body
    record(
        "BAR.CLICK.DUAL_LOGIC",
        "bluetoothMouseArea onClicked branches on Qt.RightButton for togglePower() vs root.toggleBluetooth()",
        has_rt and has_lt,
        "RightButton -> BluetoothService.togglePower(), else -> root.toggleBluetooth()"
    )

# ==============================================================================
# 3. Mutual Dismissal & Overlay Preemption
# ==============================================================================
print("\n--- Section 3: Mutual Dismissal & Overlay Preemption in shell/shell.qml ---")

# 3.1 toggleBluetooth closes Calendar
record(
    "SHELL.MUTUAL.BT_CLOSES_CAL",
    "toggleBluetooth() invokes root.closeCalendar()",
    bool(re.search(r'function\s+toggleBluetooth\(targetScreen\)[^{]*\{[\s\S]*?root\.closeCalendar\(\);', shell_content)),
    "root.closeCalendar() in toggleBluetooth"
)

# 3.2 toggleCalendar closes Bluetooth
record(
    "SHELL.MUTUAL.CAL_CLOSES_BT",
    "toggleCalendar() invokes root.closeBluetooth()",
    bool(re.search(r'function\s+toggleCalendar\(targetScreen\)[^{]*\{[\s\S]*?root\.closeBluetooth\(\);', shell_content)),
    "root.closeBluetooth() in toggleCalendar"
)

# 3.3 closeAllPopups closes both
record(
    "SHELL.MUTUAL.CLOSE_ALL",
    "closeAllPopups() closes both Calendar and Bluetooth",
    bool(re.search(r'function\s+closeAllPopups\(\)[^{]*\{[\s\S]*?root\.closeCalendar\(\);[\s\S]*?root\.closeBluetooth\(\);', shell_content)),
    "closeAllPopups() calls both"
)

# 3.4 OverlayController preemption
record(
    "SHELL.PREEMPT.OVERLAY",
    "OverlayController.onOverlayOpened closes both Calendar and Bluetooth",
    bool(re.search(r'function\s+onOverlayOpened\([^{]*\)[^{]*\{[\s\S]*?root\.closeCalendar\(\);[\s\S]*?root\.closeBluetooth\(\);', shell_content)),
    "onOverlayOpened closes both popups"
)

# ==============================================================================
# 4. Multi-Monitor Resolution & Disconnect Life-Cycle
# ==============================================================================
print("\n--- Section 4: Multi-Monitor Resolution & Disconnect Life-Cycle ---")

# 4.1 AmbientBar variants forwarding target screen
record(
    "SHELL.MONITOR.VARIANT",
    "AmbientBar delegate forwards onToggleBluetooth: root.toggleBluetooth(modelData)",
    bool(re.search(r'AmbientBar\s*\{[\s\S]*?onToggleBluetooth\s*:\s*root\.toggleBluetooth\(modelData\)', shell_content)),
    "onToggleBluetooth: root.toggleBluetooth(modelData)"
)

# 4.2 IPC toggle handler
record(
    "SHELL.MONITOR.IPC",
    "IpcHandler defines toggleBluetooth calling root.toggleBluetooth(null)",
    bool(re.search(r'function\s+toggleBluetooth\(\)[^{]*\{[\s\S]*?root\.toggleBluetooth\(null\);', shell_content)),
    "IpcHandler.toggleBluetooth() -> root.toggleBluetooth(null)"
)

# 4.3 Screen disconnect life-cycle handler
record(
    "SHELL.MONITOR.DISCONNECT",
    "Quickshell.onScreensChanged verifies bluetoothScreen is alive and closes if disconnected",
    bool(re.search(r'if\s*\(\s*root\.bluetoothVisible\s*\)[\s\S]*?const\s+currentBtScreen\s*=\s*root\.bluetoothScreen;[\s\S]*?if\s*\(\s*!isBtAlive\s*\)\s*\{\s*root\.closeBluetooth\(\);', shell_content)),
    "lifecycle disconnect verification present"
)

# ==============================================================================
# 5. Static Policy & Hygiene
# ==============================================================================
print("\n--- Section 5: Static Policy & Hygiene ---")

# qmllint
lint_res = subprocess.run(
    ["qmllint", "-I", "shell/desktop",
     "shell/desktop/surfaces/components/BluetoothPopup.qml",
     "shell/desktop/surfaces/AmbientBar.qml",
     "shell/shell.qml"],
    capture_output=True, text=True, cwd=PROJECT_ROOT
)
record("STATIC.QMLLINT", "qmllint succeeds on BluetoothPopup, AmbientBar, and shell.qml",
       lint_res.returncode == 0, f"rc={lint_res.returncode}")

# qml_inspector checks
for check_type in ["check-polling", "check-greeter", "check-format"]:
    res = subprocess.run(
        ["python3", "tests/e2e/harness/qml_inspector.py", check_type, "shell/desktop"],
        capture_output=True, text=True, cwd=PROJECT_ROOT
    )
    record(f"STATIC.{check_type.upper().replace('-', '_')}", f"qml_inspector {check_type} reports zero violations",
           res.returncode == 0, res.stdout.strip())

print("\n" + "=" * 80)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT > 0:
    print(f"\nAUDIT FAILURES ({FAIL_COUNT}):", file=sys.stderr)
    for fid, fdesc, fdet in FINDINGS:
        print(f"  - [{fid}] {fdesc}: {fdet}", file=sys.stderr)
print("=" * 80)

sys.exit(0 if FAIL_COUNT == 0 else 1)
