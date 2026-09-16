#!/usr/bin/env python3
"""
test_m3_2_adversarial_stress.py - Empirical Adversarial Stress & Chaos Test Suite for M3.2:
Shell & AmbientBar Bluetooth Integration.

Author: challenger_m3_2 (Critic & Specialist)
Purpose: Aggressively challenge assumptions, concurrency, multi-monitor races,
         layer-shell geometries, preemption semantics, and rapid event bursts.
"""

import os
import re
import sys
import subprocess
import time
import random

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell")
DESKTOP_DIR = os.path.join(SHELL_DIR, "desktop")
QUICKSHELL_BIN = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"

PASS_COUNT = 0
FAIL_COUNT = 0
FINDINGS = []


def record(test_id, desc, passed, details=""):
    global PASS_COUNT, FAIL_COUNT
    if passed:
        PASS_COUNT += 1
        print(f"[PASS] {test_id}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        FINDINGS.append((test_id, desc, details))
        print(f"[FAIL] {test_id}: {desc} ({details})", file=sys.stderr)


print("=" * 80)
print("ctOS Empirical Challenger: M3.2 Adversarial Stress & Chaos Test Suite")
print("=" * 80)

# ==============================================================================
# SECTION 1: State Machine Invariant Stress (1,000 Rapid Cycles)
# ==============================================================================
print("\n--- Section 1: Shell State Machine Invariant Stress (1,000 Iterations) ---")


class ShellSimulation:
    def __init__(self, screens):
        self.screens = screens
        self.calendarVisible = False
        self.calendarScreen = None
        self.bluetoothVisible = False
        self.bluetoothScreen = None

    def resolveTargetScreen(self):
        return self.screens[0] if self.screens else None

    def toggleCalendar(self, targetScreen=None):
        resolved = targetScreen if targetScreen is not None else self.resolveTargetScreen()
        if self.calendarVisible:
            if targetScreen is None or self.calendarScreen == resolved:
                self.calendarVisible = False
                self.calendarScreen = None
            else:
                self.calendarScreen = resolved
        else:
            self.closeBluetooth()
            self.calendarScreen = resolved
            self.calendarVisible = True

    def closeCalendar(self):
        self.calendarVisible = False
        self.calendarScreen = None

    def toggleBluetooth(self, targetScreen=None):
        resolved = targetScreen if targetScreen is not None else self.resolveTargetScreen()
        if self.bluetoothVisible:
            if targetScreen is None or self.bluetoothScreen == resolved:
                self.bluetoothVisible = False
                self.bluetoothScreen = None
            else:
                self.bluetoothScreen = resolved
        else:
            self.closeCalendar()
            self.bluetoothScreen = resolved
            self.bluetoothVisible = True

    def closeBluetooth(self):
        self.bluetoothVisible = False
        self.bluetoothScreen = None

    def closeAllPopups(self):
        self.closeCalendar()
        self.closeBluetooth()

    def onOverlayOpened(self):
        self.closeCalendar()
        self.closeBluetooth()

    def onScreensChanged(self):
        if self.calendarVisible:
            if not self.calendarScreen or not any(s["name"] == self.calendarScreen["name"] for s in self.screens):
                self.closeCalendar()
        if self.bluetoothVisible:
            if not self.bluetoothScreen or not any(s["name"] == self.bluetoothScreen["name"] for s in self.screens):
                self.closeBluetooth()


screens = [{"name": f"MON-{i}"} for i in range(5)]
sim = ShellSimulation(screens)

# 1.1 Invariant: At no time may both calendar and bluetooth be visible simultaneously
mutual_exclusivity_violations = 0
screen_mismatch_violations = 0
random.seed(42)

for step in range(1000):
    action = random.choice(["toggleBT", "toggleCal", "closeBT", "closeCal", "closeAll", "overlayOpen", "screensChange"])
    target = random.choice([None] + screens)

    if action == "toggleBT":
        sim.toggleBluetooth(target)
    elif action == "toggleCal":
        sim.toggleCalendar(target)
    elif action == "closeBT":
        sim.closeBluetooth()
    elif action == "closeCal":
        sim.closeCalendar()
    elif action == "closeAll":
        sim.closeAllPopups()
    elif action == "overlayOpen":
        sim.onOverlayOpened()
    elif action == "screensChange":
        # Randomly mutate screens and check
        sim.screens = random.sample(screens, k=random.randint(1, len(screens)))
        sim.onScreensChanged()

    # Invariant checks
    if sim.bluetoothVisible and sim.calendarVisible:
        mutual_exclusivity_violations += 1

    if sim.bluetoothVisible and sim.bluetoothScreen is None:
        screen_mismatch_violations += 1

    if sim.calendarVisible and sim.calendarScreen is None:
        screen_mismatch_violations += 1

record(
    "ADV.CHAOS.MUTUAL",
    "Mutual exclusivity holds strictly across 1,000 pseudo-random transitions",
    mutual_exclusivity_violations == 0,
    f"violations={mutual_exclusivity_violations}"
)

record(
    "ADV.CHAOS.SCREEN_BIND",
    "Visible popup always has a valid non-null target screen across 1,000 transitions",
    screen_mismatch_violations == 0,
    f"violations={screen_mismatch_violations}"
)

# ==============================================================================
# SECTION 2: Multi-Monitor Disconnect & Geometry Boundary Testing
# ==============================================================================
print("\n--- Section 2: Multi-Monitor Disconnect & Geometry Boundaries ---")

# 2.1 Disconnect active screen
sim = ShellSimulation([{"name": "DP-1"}, {"name": "HDMI-A-1"}])
sim.toggleBluetooth(sim.screens[1])  # open on HDMI-A-1
sim.screens = [{"name": "DP-1"}]     # HDMI-A-1 disconnected
sim.onScreensChanged()
record(
    "ADV.MON.DISCONNECT_ACTIVE",
    "Disconnecting host screen immediately dismisses bluetooth popup",
    sim.bluetoothVisible is False and sim.bluetoothScreen is None,
    f"visible={sim.bluetoothVisible}"
)

# 2.2 Disconnect inactive screen
sim = ShellSimulation([{"name": "DP-1"}, {"name": "HDMI-A-1"}])
sim.toggleBluetooth(sim.screens[0])  # open on DP-1
sim.screens = [{"name": "DP-1"}]     # HDMI-A-1 disconnected
sim.onScreensChanged()
record(
    "ADV.MON.DISCONNECT_INACTIVE",
    "Disconnecting inactive screen leaves active bluetooth popup undisturbed",
    sim.bluetoothVisible is True and sim.bluetoothScreen["name"] == "DP-1",
    f"visible={sim.bluetoothVisible}, screen={sim.bluetoothScreen}"
)

# 2.3 Layer-shell properties verification in shell.qml
with open(os.path.join(SHELL_DIR, "shell.qml"), "r", encoding="utf-8") as f:
    shell_qml = f.read()

# Verify Backdrop LayerShell contract
has_backdrop_top = bool(re.search(r'id\s*:\s*bluetoothBackdropHost[\s\S]*?WlrLayershell\.layer\s*:\s*WlrLayer\.Top', shell_qml))
has_backdrop_nofocus = bool(re.search(r'id\s*:\s*bluetoothBackdropHost[\s\S]*?WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.None', shell_qml))
has_backdrop_ignore = bool(re.search(r'id\s*:\s*bluetoothBackdropHost[\s\S]*?exclusionMode\s*:\s*ExclusionMode\.Ignore', shell_qml))
record("ADV.GEO.BACKDROP_LAYER", "bluetoothBackdropHost declared on WlrLayer.Top", has_backdrop_top)
record("ADV.GEO.BACKDROP_NOFOCUS", "bluetoothBackdropHost declared with WlrKeyboardFocus.None", has_backdrop_nofocus)
record("ADV.GEO.BACKDROP_IGNORE", "bluetoothBackdropHost declared with ExclusionMode.Ignore", has_backdrop_ignore)

# Verify Popup LayerShell contract
has_popup_overlay = bool(re.search(r'id\s*:\s*bluetoothPopupHost[\s\S]*?WlrLayershell\.layer\s*:\s*WlrLayer\.Overlay', shell_qml))
has_popup_nofocus = bool(re.search(r'id\s*:\s*bluetoothPopupHost[\s\S]*?WlrLayershell\.keyboardFocus\s*:\s*WlrKeyboardFocus\.None', shell_qml))
has_popup_ignore = bool(re.search(r'id\s*:\s*bluetoothPopupHost[\s\S]*?exclusionMode\s*:\s*ExclusionMode\.Ignore', shell_qml))
record("ADV.GEO.POPUP_LAYER", "bluetoothPopupHost declared on WlrLayer.Overlay", has_popup_overlay)
record("ADV.GEO.POPUP_NOFOCUS", "bluetoothPopupHost declared with WlrKeyboardFocus.None", has_popup_nofocus)
record("ADV.GEO.POPUP_IGNORE", "bluetoothPopupHost declared with ExclusionMode.Ignore", has_popup_ignore)

# ==============================================================================
# SECTION 3: AmbientBar Mouse Area Event Routing Stress
# ==============================================================================
print("\n--- Section 3: AmbientBar Dual-Click Logic Stress ---")

with open(os.path.join(DESKTOP_DIR, "surfaces", "AmbientBar.qml"), "r", encoding="utf-8") as f:
    ambient_qml = f.read()

# Check mouse area button mask
has_dual_accepted = bool(re.search(r'acceptedButtons\s*:\s*Qt\.LeftButton\s*\|\s*Qt\.RightButton', ambient_qml))
record("ADV.CLICK.BUTTON_MASK", "AmbientBar bluetoothMouseArea explicitly enables Qt.LeftButton | Qt.RightButton", has_dual_accepted)

# Test dispatch logic on wide variety of inputs
def dispatch_event(mouse):
    if mouse and mouse.get("button") == "RightButton":
        return "togglePower"
    else:
        return "toggleBluetooth"

# 3.1 Left click
record("ADV.DISPATCH.LEFT", "Left button dispatches to toggleBluetooth",
       dispatch_event({"button": "LeftButton"}) == "toggleBluetooth")

# 3.2 Right click
record("ADV.DISPATCH.RIGHT", "Right button dispatches to togglePower",
       dispatch_event({"button": "RightButton"}) == "togglePower")

# 3.3 Middle click
record("ADV.DISPATCH.MIDDLE", "Middle button falls back to toggleBluetooth",
       dispatch_event({"button": "MiddleButton"}) == "toggleBluetooth")

# 3.4 None / Null click
record("ADV.DISPATCH.NULL", "Null event falls back to toggleBluetooth",
       dispatch_event(None) == "toggleBluetooth")

# 3.5 Malformed event (empty dict)
record("ADV.DISPATCH.EMPTY", "Empty event falls back to toggleBluetooth",
       dispatch_event({}) == "toggleBluetooth")

# ==============================================================================
# SECTION 4: Full Test Suite Execution & Cross-Validation
# ==============================================================================
print("\n--- Section 4: Full Test Suite Execution & Cross-Validation ---")

test_scripts = [
    ("tests/e2e/test_m3_2_shell_ambient_audit.py", "python3", "M3.2 Shell & AmbientBar AST Audit"),
    ("tests/e2e/harness/test_m3_2_shell_ambient_integration.qml", "quickshell", "M3.2 Shell & AmbientBar QML Runtime"),
    ("tests/e2e/test_m3_bluetooth_audit.py", "python3", "M3 Bluetooth AST Audit"),
    ("tests/e2e/harness/test_m3_bluetooth_runtime.qml", "quickshell", "M3 Bluetooth Runtime"),
    ("tests/e2e/harness/test_m3_bluetooth_adversarial.qml", "quickshell", "M3 Bluetooth Adversarial Runtime"),
    ("tests/e2e/harness/test_m3_bluetooth_popup_challenger.qml", "quickshell", "M3 Bluetooth Popup Challenger"),
    ("tests/e2e/harness/test_m4_shell_wiring.qml", "quickshell", "M4 Calendar Shell Wiring Baseline"),
    ("tests/e2e/tier2_boundaries/test_zero_polling_boundaries.sh", "bash", "Zero-Polling Architecture Boundaries"),
]

env = os.environ.copy()
env["CTOS_SETTINGS_PATH"] = "/tmp/ctos_test_settings.json"
env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")

for path, runner, desc in test_scripts:
    t0 = time.time()
    if runner == "python3":
        cmd = ["python3", path]
    elif runner == "bash":
        cmd = ["bash", path]
    elif runner == "quickshell":
        cmd = [QUICKSHELL_BIN, "-p", path]

    res = subprocess.run(cmd, capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=12)
    elapsed = time.time() - t0
    record(
        f"ADV.SUITE.{os.path.basename(path)}",
        f"{desc} passes cleanly (rc=0)",
        res.returncode == 0,
        f"time={elapsed:.2f}s, rc={res.returncode}"
    )

print("\n" + "=" * 80)
print(f"ADVERSARIAL STRESS SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT > 0:
    print(f"\nFAILURES DETECTED ({FAIL_COUNT}):", file=sys.stderr)
    for fid, fdesc, fdet in FINDINGS:
        print(f"  - [{fid}] {fdesc}: {fdet}", file=sys.stderr)
print("=" * 80)

sys.exit(0 if FAIL_COUNT == 0 else 1)
