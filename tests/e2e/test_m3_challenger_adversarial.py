#!/usr/bin/env python3
"""
test_m3_challenger_adversarial.py - Challenger 2 Adversarial Stress Suite for Milestone 3:
Bluetooth Popup UI & Shell Wiring.

Adversarial Challenge Dimensions:
1. Click propagation & isolation:
   - Root MouseArea preventStealing: true
   - onClicked consumption (mouse.accepted = true)
   - Dual PanelWindow layer isolation (WlrLayer.Overlay vs WlrLayer.Top)
   - Sub-component button MouseAreas (powerBtn, scanBtn, closeBtn)
2. Rapid toggleBluetooth & mutual preemption stress:
   - Deterministic toggle state under rapid sequential invocations
   - Multi-monitor target transfer without visual jitter or desync
   - Strict mutual preemption invariant with CalendarPopup
   - Dismissal via closeAllPopups and OverlayController
3. Dual-button mouse routing on AmbientBar bluetoothSection:
   - acceptedButtons: Qt.LeftButton | Qt.RightButton
   - Left-click triggers signal toggleBluetooth
   - Right-click triggers BluetoothService.togglePower()
   - bluetoothSection visibility strictly bound to BluetoothService.available
4. IPC handler & dynamic screen hotplug (screensChanged):
   - IPC toggle with null target resolves via resolveTargetScreen()
   - Quickshell.onScreensChanged safely dismisses if host screen is disconnected
   - Unrelated screen disconnection preserves active popup state
   - Zero crash on empty screens list or null screen references
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell")
POPUP_PATH = os.path.join(SHELL_DIR, "desktop", "surfaces", "components", "BluetoothPopup.qml")
BAR_PATH = os.path.join(SHELL_DIR, "desktop", "surfaces", "AmbientBar.qml")
SHELL_PATH = os.path.join(SHELL_DIR, "shell.qml")
QMLDIR_PATH = os.path.join(SHELL_DIR, "desktop", "surfaces", "components", "qmldir")
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

PASS_COUNT = 0
FAIL_COUNT = 0


def check(id_str, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {id_str}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {id_str}: {desc} ({details})", file=sys.stderr)


print("=" * 70)
print("CHALLENGER 2: MILESTONE 3 BLUETOOTH POPUP & SHELL WIRING ADVERSARIAL AUDIT")
print("=" * 70)

# ==============================================================================
# 1. BluetoothPopup.qml Invariants & Click Shield Inspection
# ==============================================================================
if os.path.isfile(POPUP_PATH):
    with open(POPUP_PATH, "r", encoding="utf-8") as f:
        popup_src = f.read()

    check("POP.PRAGMA", "BluetoothPopup declares pragma ComponentBehavior: Bound",
          "pragma ComponentBehavior: Bound" in popup_src, "Bound component pragma")

    check("POP.SIGNAL", "BluetoothPopup declares signal closeRequested",
          bool(re.search(r'signal\s+closeRequested\b', popup_src)), "signal closeRequested present")

    check("POP.WIDTH", "BluetoothPopup enforces 320px width",
          "implicitWidth: 320" in popup_src and "width: 320" in popup_src, "width=320 implicitWidth=320")

    check("POP.HEIGHT_BOUND", "BluetoothPopup bounds body container height to max 320px",
          "Math.min(320" in popup_src, "clamped via Math.min(320, ...)")

    check("POP.THEME_SURF", "BluetoothPopup uses Theme.gray900 and Theme.borderMuted",
          "color: Theme.gray900" in popup_src and "border.color: Theme.borderMuted" in popup_src,
          "Theme.gray900 & Theme.borderMuted")

    # Click Shield: MouseArea at root with preventStealing and accepted
    shield_pattern = re.search(r'MouseArea\s*\{[^}]*preventStealing\s*:\s*true[^}]*\}', popup_src, re.DOTALL)
    check("POP.SHIELD.PREVENT", "Root MouseArea declares preventStealing: true",
          bool(shield_pattern), "preventStealing: true found in root MouseArea")

    check("POP.SHIELD.ACCEPT", "Root MouseArea consumes click via mouse.accepted = true",
          bool(re.search(r'onClicked\s*:\s*mouse\s*=>\s*mouse\.accepted\s*=\s*true', popup_src)),
          "mouse.accepted = true found")

    # Close button emits closeRequested
    check("POP.CLOSE.EMIT", "Close button MouseArea emits closeRequested()",
          bool(re.search(r'closeMouse[\s\S]*?root\.closeRequested\(\)', popup_src)),
          "closeRequested() emitted on close click")

    # Flickable clipping and bounds behavior
    check("POP.FLICK.CLIP", "Device flickable enables clip and StopAtBounds",
          "clip: true" in popup_src and "boundsBehavior: Flickable.StopAtBounds" in popup_src,
          "clip and StopAtBounds enabled")

    # Zero running: true literal Process nodes
    check("POP.ZERO_PROC", "BluetoothPopup contains zero Process execution nodes",
          "Process {" not in popup_src, "clean UI component without Process nodes")

# ==============================================================================
# 2. AmbientBar.qml Dual Click & Signal Wiring Inspection
# ==============================================================================
if os.path.isfile(BAR_PATH):
    with open(BAR_PATH, "r", encoding="utf-8") as f:
        bar_src = f.read()

    check("BAR.SIG.DECL", "AmbientBar declares signal toggleBluetooth",
          bool(re.search(r'signal\s+toggleBluetooth\b', bar_src)), "signal toggleBluetooth present")

    # Mouse area dual button handling
    check("BAR.MA.BUTTONS", "bluetoothMouseArea accepts LeftButton and RightButton",
          "acceptedButtons: Qt.LeftButton | Qt.RightButton" in bar_src,
          "acceptedButtons: Qt.LeftButton | Qt.RightButton")

    check("BAR.MA.RIGHT_CLICK", "RightButton click invokes BluetoothService.togglePower()",
          bool(re.search(r'mouse\.button\s*===\s*Qt\.RightButton[\s\S]*?BluetoothService\.togglePower\(\)', bar_src)),
          "RightButton routes to togglePower()")

    check("BAR.MA.LEFT_CLICK", "LeftButton click invokes root.toggleBluetooth()",
          bool(re.search(r'else\s*\{[\s\S]*?root\.toggleBluetooth\(\);', bar_src)),
          "LeftButton routes to toggleBluetooth()")

    check("BAR.VIS.BOUND", "bluetoothSection visibility bound to BluetoothService.available",
          bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?visible\s*:\s*BluetoothService\.available', bar_src)),
          "visible: BluetoothService.available")

# ==============================================================================
# 3. shell.qml Shell Wiring, Layer Shell & Preemption Inspection
# ==============================================================================
if os.path.isfile(SHELL_PATH):
    with open(SHELL_PATH, "r", encoding="utf-8") as f:
        shell_src = f.read()

    check("SHL.PROP.VIS", "shell.qml defines property bool bluetoothVisible",
          bool(re.search(r'property\s+bool\s+bluetoothVisible\s*:\s*false', shell_src)),
          "property bool bluetoothVisible: false")

    check("SHL.PROP.SCRN", "shell.qml defines property var bluetoothScreen",
          bool(re.search(r'property\s+var\s+bluetoothScreen\s*:\s*null', shell_src)),
          "property var bluetoothScreen: null")

    check("SHL.FN.TOGGLE", "shell.qml defines function toggleBluetooth(targetScreen)",
          bool(re.search(r'function\s+toggleBluetooth\s*\(\s*targetScreen\s*\)', shell_src)),
          "toggleBluetooth function present")

    check("SHL.FN.CLOSE", "shell.qml defines function closeBluetooth()",
          bool(re.search(r'function\s+closeBluetooth\s*\(\s*\)', shell_src)),
          "closeBluetooth function present")

    check("SHL.FN.CLOSEALL", "shell.qml defines function closeAllPopups()",
          bool(re.search(r'function\s+closeAllPopups\s*\(\s*\)', shell_src)),
          "closeAllPopups function present")

    # Mutual preemption: opening bluetooth closes calendar, opening calendar closes bluetooth
    check("SHL.PREEMPT.CAL", "toggleCalendar calls root.closeBluetooth()",
          bool(re.search(r'function\s+toggleCalendar[\s\S]*?root\.closeBluetooth\(\)', shell_src)),
          "closeBluetooth called in toggleCalendar")

    check("SHL.PREEMPT.BT", "toggleBluetooth calls root.closeCalendar()",
          bool(re.search(r'function\s+toggleBluetooth[\s\S]*?root\.closeCalendar\(\)', shell_src)),
          "closeCalendar called in toggleBluetooth")

    check("SHL.PREEMPT.OVL", "OverlayController.onOverlayOpened closes bluetooth popup",
          bool(re.search(r'onOverlayOpened[\s\S]*?root\.closeBluetooth\(\)', shell_src)),
          "closeBluetooth called in onOverlayOpened")

    # IPC Handler
    check("SHL.IPC.TOGGLE", "IpcHandler defines toggleBluetooth delegating to root.toggleBluetooth(null)",
          bool(re.search(r'function\s+toggleBluetooth\(\)[\s\S]*?root\.toggleBluetooth\(null\)', shell_src)),
          "IpcHandler.toggleBluetooth delegates to null target")

    # Hotplug screensChanged handling
    check("SHL.HOTPLUG.BT", "onScreensChanged verifies bluetoothScreen survival and closes if disconnected",
          bool(re.search(r'if\s*\(\s*root\.bluetoothVisible\s*\)[\s\S]*?Quickshell\.screens[\s\S]*?root\.closeBluetooth\(\)', shell_src)),
          "screensChanged guards bluetoothVisible and closes on disconnect")

    # Dual PanelWindow Hosts
    check("SHL.WIN.BACKDROP", "bluetoothBackdropHost declared at WlrLayer.Top with dismiss click",
          bool(re.search(r'id\s*:\s*bluetoothBackdropHost[\s\S]*?WlrLayershell\.layer\s*:\s*WlrLayer\.Top[\s\S]*?root\.closeBluetooth\(\)', shell_src)),
          "backdrop at WlrLayer.Top dismisses on click")

    check("SHL.WIN.POPUP", "bluetoothPopupHost declared at WlrLayer.Overlay hosting BluetoothPopup",
          bool(re.search(r'id\s*:\s*bluetoothPopupHost[\s\S]*?WlrLayershell\.layer\s*:\s*WlrLayer\.Overlay[\s\S]*?BluetoothPopup\s*\{', shell_src)),
          "popup host at WlrLayer.Overlay hosts BluetoothPopup")

# ==============================================================================
# 4. qmldir Registration
# ==============================================================================
if os.path.isfile(QMLDIR_PATH):
    with open(QMLDIR_PATH, "r", encoding="utf-8") as f:
        qmldir_src = f.read()
    check("QMLDIR.BT_POPUP", "surfaces/components/qmldir registers BluetoothPopup 1.0",
          bool(re.search(r'BluetoothPopup\s+1\.0\s+BluetoothPopup\.qml', qmldir_src)),
          "BluetoothPopup registered in qmldir")

# ==============================================================================
# 5. Static Lint & Hygiene Invariants
# ==============================================================================
poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.ZERO_POLL", "Zero polling loops or persistent shell processes in shell/desktop",
      poll_res.returncode == 0, poll_res.stdout.strip())

fmt_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.FORMAT", "All files adhere to formatting rules",
      fmt_res.returncode == 0, fmt_res.stdout.strip())

qmllint_res = subprocess.run(["qmllint", POPUP_PATH, BAR_PATH, SHELL_PATH],
                             capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.QMLLINT", "qmllint succeeds on BluetoothPopup.qml, AmbientBar.qml, and shell.qml",
      qmllint_res.returncode == 0, "syntax verification clean")

# ==============================================================================
# 6. Execute Quickshell Runtime Adversarial Harnesses
# ==============================================================================
env = os.environ.copy()
env["CTOS_SETTINGS_PATH"] = "/tmp/ctos_test_settings.json"
env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")

challenger_qml = os.path.join(PROJECT_ROOT, "tests", "e2e", "harness", "test_m3_bluetooth_adversarial_challenger.qml")
res_challenger = subprocess.run([QUICKSHELL_BIN, "-p", challenger_qml],
                                capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=12)
check("RUN.CHALLENGER_M3", "Quickshell adversarial challenger harness exits cleanly with 0 failures",
      res_challenger.returncode == 0 and "CHALLENGER 2 ADVERSARIAL RESULTS: Passed=31, Failed=0" in res_challenger.stdout,
      "Passed=31, Failed=0")

popup_qml = os.path.join(PROJECT_ROOT, "tests", "e2e", "harness", "test_m3_bluetooth_popup_challenger.qml")
res_popup = subprocess.run([QUICKSHELL_BIN, "-p", popup_qml],
                           capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=12)
check("RUN.POPUP_CHALLENGER", "Quickshell popup challenger harness exits cleanly with 0 failures",
      res_popup.returncode == 0 and "Failed=0" in res_popup.stdout,
      "Popup UI harness passed cleanly")

runtime_qml = os.path.join(PROJECT_ROOT, "tests", "e2e", "harness", "test_m3_bluetooth_runtime.qml")
res_runtime = subprocess.run([QUICKSHELL_BIN, "-p", runtime_qml],
                            capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=12)
check("RUN.RUNTIME_M3", "Quickshell M3 runtime harness exits cleanly with 0 failures",
      res_runtime.returncode == 0 and "Failed=0" in res_runtime.stdout,
      "Runtime harness passed cleanly")

print("=" * 70)
print(f"CHALLENGER 2 AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 3 ADVERSARIAL CHALLENGES AND INVARIANTS PASSED (VERDICT: APPROVE) ===")
else:
    print("=== MILESTONE 3 ADVERSARIAL CHALLENGES FAILED (VERDICT: CHALLENGE_FAILED) ===", file=sys.stderr)
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
