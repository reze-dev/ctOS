#!/usr/bin/env python3
"""
test_m3_adversarial_challenger.py - Empirical Adversarial Stress Test Suite for Milestone 3:
Requirement R5: Add Bluetooth Toggle to Bar.

Author: challenger_m3_2 (Critic & Specialist)
Purpose: Rigorously challenge assumptions, parser edge cases, state machine transitions,
         geometric bounds, zero-polling policies, and runtime reactivity under stress.
"""

import os
import re
import sys
import subprocess
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell", "desktop")

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
print("ctOS Empirical Challenger: Milestone 3 Adversarial Audit & Stress Suite")
print("=" * 80)

# ==============================================================================
# SECTION 1: Zero-Polling & Subshell Policy Verification
# ==============================================================================
print("\n--- Section 1: Zero-Polling & Subshell Policy ---")

# 1.1: Literal running: true in shell/desktop
res_running_true = subprocess.run(
    ["grep", "-rnE", r"running:\s*true", SHELL_DIR],
    capture_output=True, text=True
)
record(
    "ADV.POLL.01",
    "Zero literal 'running: true' declarations across shell/desktop",
    res_running_true.returncode != 0 and len(res_running_true.stdout.strip()) == 0,
    f"hits={len(res_running_true.stdout.strip().splitlines()) if res_running_true.stdout else 0}"
)

# 1.2: Persistent sh -c or bash -c subshells
res_sh_c = subprocess.run(
    ["git", "grep", "-inE", r"(sh|bash)\s+-c", "shell/desktop/"],
    capture_output=True, text=True, cwd=PROJECT_ROOT
)
record(
    "ADV.POLL.02",
    "Zero 'sh -c' or 'bash -c' subshell commands in shell/desktop",
    res_sh_c.returncode != 0 and len(res_sh_c.stdout.strip()) == 0,
    f"hits={len(res_sh_c.stdout.strip().splitlines()) if res_sh_c.stdout else 0}"
)

# 1.3: Subshell file append logging (echo ... >> /tmp/...)
res_echo = subprocess.run(
    ["git", "grep", "-inE", r"echo.*>>", "shell/desktop/"],
    capture_output=True, text=True, cwd=PROJECT_ROOT
)
record(
    "ADV.POLL.03",
    "Zero subshell file append logging (echo >>) in shell/desktop",
    res_echo.returncode != 0 and len(res_echo.stdout.strip()) == 0,
    f"hits={len(res_echo.stdout.strip().splitlines()) if res_echo.stdout else 0}"
)

# 1.4: Prototype while-sleep loops
res_while = subprocess.run(
    ["git", "grep", "-inE", r"while\s+true\s*;", "shell/desktop/"],
    capture_output=True, text=True, cwd=PROJECT_ROOT
)
record(
    "ADV.POLL.04",
    "Zero prototype while-sleep shell loops in shell/desktop",
    res_while.returncode != 0 and len(res_while.stdout.strip()) == 0,
    f"hits={len(res_while.stdout.strip().splitlines()) if res_while.stdout else 0}"
)

# ==============================================================================
# SECTION 2: Layout, Geometry, and Decoupling Invariants
# ==============================================================================
print("\n--- Section 2: Layout, Geometry & Decoupling ---")

bar_path = os.path.join(SHELL_DIR, "surfaces", "AmbientBar.qml")
widget_path = os.path.join(SHELL_DIR, "surfaces", "components", "BluetoothWidget.qml")

with open(bar_path, "r", encoding="utf-8") as f:
    bar_content = f.read()

with open(widget_path, "r", encoding="utf-8") as f:
    widget_content = f.read()

# 2.1: bluetoothSection positioned between batterySection and clockSection
order_match = re.search(r'id\s*:\s*batterySection[\s\S]*?id\s*:\s*bluetoothSection[\s\S]*?id\s*:\s*clockSection', bar_content)
record(
    "ADV.LAYOUT.01",
    "bluetoothSection is sequenced between batterySection and clockSection",
    bool(order_match),
    "verified sequence batterySection -> bluetoothSection -> clockSection"
)

# 2.2: bluetoothSection height is 34px (Theme.barHeight - 6)
h_match = re.search(r'id\s*:\s*bluetoothSection[\s\S]*?height\s*:\s*Theme\.barHeight\s*-\s*6', bar_content)
record(
    "ADV.LAYOUT.02",
    "bluetoothSection height is Theme.barHeight - 6 (34px)",
    bool(h_match),
    "height: Theme.barHeight - 6"
)

# 2.3: bluetoothSection radius is 8px (Theme.radiusMedium)
r_match = re.search(r'id\s*:\s*bluetoothSection[\s\S]*?radius\s*:\s*Theme\.radiusMedium', bar_content)
record(
    "ADV.LAYOUT.03",
    "bluetoothSection radius is Theme.radiusMedium (8px)",
    bool(r_match),
    "radius: Theme.radiusMedium"
)

# 2.4: BluetoothWidget has zero internal MouseArea
record(
    "ADV.DECOUPLE.01",
    "BluetoothWidget has zero internal MouseArea",
    "MouseArea" not in widget_content,
    "MouseArea absent from widget"
)

# 2.5: BluetoothWidget has zero internal container Rectangle
has_internal_rect = bool(re.search(r'^\s*Rectangle\s*\{', widget_content, re.MULTILINE))
record(
    "ADV.DECOUPLE.02",
    "BluetoothWidget has zero internal container Rectangle",
    not has_internal_rect,
    "container Rectangle absent from widget"
)

# 2.6: BluetoothWidget root is Item
record(
    "ADV.DECOUPLE.03",
    "BluetoothWidget root element is Item",
    bool(re.match(r'^(?:import[^\n]+\n+)+Item\s*\{', widget_content.strip())),
    "root is Item"
)

# 2.7: AmbientBar hosts hover and click interaction
click_match = re.search(r'bluetoothMouseArea[\s\S]*?BluetoothService\.togglePower\(\)', bar_content)
record(
    "ADV.DECOUPLE.04",
    "bluetoothSection hosts mouse area triggering BluetoothService.togglePower()",
    bool(click_match),
    "togglePower() wired on outer mouse area"
)

# ==============================================================================
# SECTION 3: Deep Parser & String Stress Testing
# ==============================================================================
print("\n--- Section 3: Deep Parser & String Stress Testing ---")

# We test parser logic against a wide battery of adversarial inputs using python regex mirroring BluetoothService.qml
def parse_show_output(raw):
    if not raw or raw.strip() == "" or "No default controller available" in raw or "Waiting to connect to bluetoothd" in raw:
        return {"available": False, "powered": False, "isConnected": False, "deviceName": ""}
    available = True
    is_powered = bool(re.search(r'^\s*Powered:\s*yes', raw, re.MULTILINE))
    return {"available": available, "powered": is_powered, "isConnected": False, "deviceName": ""}

def parse_connected_output(raw, powered):
    if not powered or not raw or raw.strip() == "":
        return {"isConnected": False, "deviceName": ""}
    lines = raw.strip().split("\n")
    for line in lines:
        line_clean = line.strip()
        match = re.match(r'^Device\s+([0-9A-Fa-f:]{17})(?:\s+(.*))?$', line_clean)
        if match:
            raw_name = match.group(2).strip() if match.group(2) else ""
            name = re.sub(r'[\x00-\x1F\x7F]', '', raw_name)
            dev_name = name[:24] if len(name) > 0 else "Device"
            return {"isConnected": True, "deviceName": dev_name}
    return {"isConnected": False, "deviceName": ""}

# 3.1: Missing controller strings
for idx, input_str in enumerate([
    "No default controller available\n",
    "Waiting to connect to bluetoothd...\n",
    "",
    "   \n\t  \n",
]):
    res = parse_show_output(input_str)
    record(
        f"ADV.PARSE.MISSING.{idx+1}",
        f"Missing controller correctly parsed (input: {repr(input_str[:25])})",
        res["available"] is False and res["powered"] is False,
        f"available={res['available']}, powered={res['powered']}"
    )

# 3.2: Powered off strings
res_off = parse_show_output("Controller 00:1A:7D:DA:71:13 ctOS-Host\n\tPowered: no\n\tPowerState: off\n")
record(
    "ADV.PARSE.OFF.01",
    "Powered: no correctly parsed",
    res_off["available"] is True and res_off["powered"] is False,
    f"available={res_off['available']}, powered={res_off['powered']}"
)

# 3.3: Powered on strings (multiline indentation)
res_on = parse_show_output("Controller 00:1A:7D:DA:71:13 ctOS-Host\n\tName: ctOS-Host\n\tPowered: yes\n\tDiscoverable: no\n")
record(
    "ADV.PARSE.ON.01",
    "Powered: yes correctly parsed",
    res_on["available"] is True and res_on["powered"] is True,
    f"available={res_on['available']}, powered={res_on['powered']}"
)

# 3.4: Adversarial trick: Device name containing "Powered: yes" should NOT fool controller parser
res_trick = parse_show_output("Controller 00:1A:7D:DA:71:13 ctOS-Host\n\tPowered: no\nDevice 11:22:33:44:55:66 Powered: yes headphone\n")
record(
    "ADV.PARSE.TRICK.01",
    "Device name containing 'Powered: yes' does not falsely power on controller",
    res_trick["powered"] is False,
    f"powered={res_trick['powered']}"
)

# 3.5: Connected device with normal name
res_conn = parse_connected_output("Device 12:34:56:78:9A:BC Toad 8\n", powered=True)
record(
    "ADV.PARSE.CONN.01",
    "Connected device correctly parsed",
    res_conn["isConnected"] is True and res_conn["deviceName"] == "Toad 8",
    f"isConnected={res_conn['isConnected']}, deviceName={res_conn['deviceName']}"
)

# 3.6: Connected device with 60+ chars name (bounding to 24 chars)
long_name = "Super Ultra Mega Extremely Extended High Definition Bluetooth Audio Receiver 3000 Max"
res_long = parse_connected_output(f"Device 12:34:56:78:9A:BC {long_name}\n", powered=True)
record(
    "ADV.PARSE.BOUND.01",
    "Connected device with 60+ chars is bounded to <= 24 chars",
    res_long["isConnected"] is True and len(res_long["deviceName"]) <= 24 and res_long["deviceName"] == long_name[:24],
    f"len={len(res_long['deviceName'])}, deviceName={repr(res_long['deviceName'])}"
)

# 3.7: Connected device with unicode and emojis
res_uni = parse_connected_output("Device 12:34:56:78:9A:BC 🎧 Sony WH-1000XM4\n", powered=True)
record(
    "ADV.PARSE.UNI.01",
    "Unicode emoji device name preserved and parsed",
    res_uni["isConnected"] is True and "🎧" in res_uni["deviceName"],
    f"deviceName={res_uni['deviceName']}"
)

# 3.8: Connected device with control characters (0x07, 0x1B, 0x7F)
res_ctrl = parse_connected_output("Device 12:34:56:78:9A:BC \x07AirPods\x1b[31mPro\x7f\n", powered=True)
record(
    "ADV.PARSE.CTRL.01",
    "Control characters stripped from device name",
    res_ctrl["isConnected"] is True and "\x07" not in res_ctrl["deviceName"] and "\x7f" not in res_ctrl["deviceName"],
    f"deviceName={repr(res_ctrl['deviceName'])}"
)

# 3.9: Connected device with only whitespace in name
res_spaces = parse_connected_output("Device 12:34:56:78:9A:BC      \n", powered=True)
record(
    "ADV.PARSE.SPACE.01",
    "Device with blank name falls back to 'Device'",
    res_spaces["isConnected"] is True and res_spaces["deviceName"] == "Device",
    f"deviceName={res_spaces['deviceName']}"
)

# ==============================================================================
# SECTION 4: Headless Quickshell Live Dynamic Runtime Verification
# ==============================================================================
print("\n--- Section 4: Headless Quickshell Live Dynamic Runtime ---")

# Run test_reproduce_deadlock.qml to test the live visibility recovery
qs_bin = "/nix/store/gvgrz4bh8hryjzrvkqjiwyh4acpn27aj-quickshell-0.3.1/bin/quickshell"
env = os.environ.copy()
env["QML_IMPORT_PATH"] = os.path.join(PROJECT_ROOT, "shell")

res_deadlock = subprocess.run(
    [qs_bin, "-p", "tests/e2e/harness/test_reproduce_deadlock.qml"],
    capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=15
)
deadlock_detected = "CRITICAL BUG CONFIRMED: bluetoothSection is DEADLOCKED in invisible state" in (res_deadlock.stderr + res_deadlock.stdout)
record(
    "ADV.LIVE.DEADLOCK.01",
    "bluetoothSection recovers visibility when controller goes from Missing -> Powered",
    not deadlock_detected,
    "DEADLOCKED in invisible state due to parent-child visible binding loop!" if deadlock_detected else "recovered cleanly"
)

# Test width bounding in live layout
res_width = subprocess.run(
    [qs_bin, "-p", "tests/e2e/harness/test_layout_measure2.qml"],
    capture_output=True, text=True, env=env, cwd=PROJECT_ROOT, timeout=15
)
out_width = res_width.stdout + res_width.stderr
width_bounded = "btSec.width: 152" in out_width and "textItem.width: 120" in out_width
record(
    "ADV.LIVE.BOUND.01",
    "bluetoothSection width strictly bounded to <= 152px under 24-char text",
    width_bounded,
    f"measured width verified bounded via Layout.maximumWidth: 120"
)

# ==============================================================================
# SECTION 5: Regressions & Existing Test Suites Execution
# ==============================================================================
print("\n--- Section 5: Regressions & Existing Test Suites ---")

for script in [
    ("tests/e2e/test_m3_bluetooth_audit.py", "M3 Bluetooth AST Audit"),
    ("tests/e2e/test_m2_per_section_audit.py", "M2 Per-Section Audit"),
    ("tests/e2e/test_m1_adversarial_audit.py", "M1 Adversarial Audit"),
]:
    t0 = time.time()
    res = subprocess.run(["python3", script[0]], capture_output=True, text=True, cwd=PROJECT_ROOT)
    elapsed = time.time() - t0
    record(
        f"ADV.REGRESS.{script[0].split('/')[-1]}",
        f"{script[1]} passes cleanly",
        res.returncode == 0,
        f"returncode={res.returncode}, time={elapsed:.2f}s"
    )

res_zero = subprocess.run(["./tests/e2e/tier2_boundaries/test_zero_polling_boundaries.sh"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
record(
    "ADV.REGRESS.zero_polling",
    "test_zero_polling_boundaries.sh passes cleanly",
    res_zero.returncode == 0,
    f"returncode={res_zero.returncode}"
)

print("\n" + "=" * 80)
print(f"ADVERSARIAL SUITE SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT > 0:
    print(f"\nCRITICAL FAILURES DETECTED ({FAIL_COUNT}):", file=sys.stderr)
    for f_id, f_desc, f_det in FINDINGS:
        print(f"  - [{f_id}] {f_desc}: {f_det}", file=sys.stderr)
print("=" * 80)

sys.exit(0 if FAIL_COUNT == 0 else 1)
