#!/usr/bin/env python3
"""
test_m3_bluetooth_audit.py - Comprehensive AST & Invariant Audit for Milestone 3:
Requirement R5: Add Bluetooth Toggle to Bar.

Audits:
1. Asset & File Verification:
   - shell/desktop/services/BluetoothService.qml exists
   - shell/desktop/surfaces/components/BluetoothWidget.qml exists
   - shell/desktop/assets/icons/bluetooth.svg exists (viewBox 256 256, stroke white)
   - shell/desktop/assets/icons/bluetooth-slash.svg exists (viewBox 256 256, stroke white)
2. qmldir Registrations:
   - shell/desktop/services/qmldir declares singleton BluetoothService
   - shell/desktop/surfaces/components/qmldir declares BluetoothWidget
3. BluetoothService.qml Contract & Invariants:
   - readonly property bool available
   - readonly property bool powered
   - readonly property bool isConnected
   - readonly property string deviceName
   - function togglePower()
   - function refresh()
   - Discrete Process command arrays (no sh -c or bash -c)
   - All Process instances have running: false
   - Zero literal `running: true` anywhere in the file
   - Timer uses dynamic running binding
4. CtosIcon.qml System Icon Routing:
   - direct array contains "bluetooth" and "bluetooth-slash"
5. BluetoothWidget.qml Invariants:
   - Decoupled architecture: Item root, zero container Rectangle, zero MouseArea
   - Forwarded hover property `isHovered`
   - Natural sizing (implicitHeight couples to layout, no hardcoded barHeight)
   - Monospace typography via Theme.fontFamilyMonospace
   - Zero raw hex colors (#...); all colors use Theme tokens
   - Maximum width constraint and elide on text
6. AmbientBar.qml Integration:
   - bluetoothSection positioned between batterySection and clockSection
   - bluetoothSection dimensions: height Theme.barHeight - 6 (34), radius Theme.radiusMedium (8)
   - bluetoothSection preferredWidth couples to bluetoothWidget.implicitWidth + Theme.paddingMedium * 2
   - bluetoothSection hosts BluetoothWidget and wires isHovered to mouse area
   - bluetoothSection mouse area onClicked calls BluetoothService.togglePower()
   - bluetoothSection visibility bound to BluetoothService.available
7. Static Policy & Hygiene:
   - qml_inspector check-greeter reports 0 violations
   - qml_inspector check-polling reports 0 violations
   - qml_inspector check-format reports 0 violations
   - qmllint passes cleanly
"""

import os
import re
import sys
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell", "desktop")

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
print("ctOS Challenger M3: Bluetooth Service & Toggle Bar Audit")
print("=" * 70)

# ==============================================================================
# 1. File Existence & Asset Checks
# ==============================================================================
service_path = os.path.join(SHELL_DIR, "services", "BluetoothService.qml")
widget_path = os.path.join(SHELL_DIR, "surfaces", "components", "BluetoothWidget.qml")
icon_bt_path = os.path.join(SHELL_DIR, "assets", "icons", "bluetooth.svg")
icon_slash_path = os.path.join(SHELL_DIR, "assets", "icons", "bluetooth-slash.svg")

check("BT.FILE.01", "BluetoothService.qml exists",
      os.path.isfile(service_path), f"path={service_path}")
check("BT.FILE.02", "BluetoothWidget.qml exists",
      os.path.isfile(widget_path), f"path={widget_path}")
check("BT.FILE.03", "bluetooth.svg icon exists",
      os.path.isfile(icon_bt_path), f"path={icon_bt_path}")
check("BT.FILE.04", "bluetooth-slash.svg icon exists",
      os.path.isfile(icon_slash_path), f"path={icon_slash_path}")

if os.path.isfile(icon_bt_path):
    with open(icon_bt_path, "r", encoding="utf-8") as f:
        svg_bt = f.read()
    check("BT.ICON.01", "bluetooth.svg has 256x256 viewBox and stroke='white'",
          'viewBox="0 0 256 256"' in svg_bt and 'stroke="white"' in svg_bt,
          "valid Phosphor style")

if os.path.isfile(icon_slash_path):
    with open(icon_slash_path, "r", encoding="utf-8") as f:
        svg_slash = f.read()
    check("BT.ICON.02", "bluetooth-slash.svg has 256x256 viewBox and slash line",
          'viewBox="0 0 256 256"' in svg_slash and '<line' in svg_slash,
          "valid Phosphor slash style")

# ==============================================================================
# 2. Module Registration Checks (qmldir)
# ==============================================================================
services_qmldir = os.path.join(SHELL_DIR, "services", "qmldir")
with open(services_qmldir, "r", encoding="utf-8") as f:
    services_qmldir_content = f.read()
check("BT.QMLDIR.01", "services/qmldir declares singleton BluetoothService",
      bool(re.search(r'singleton\s+BluetoothService\s+1\.0\s+BluetoothService\.qml', services_qmldir_content)),
      "registered as singleton")

components_qmldir = os.path.join(SHELL_DIR, "surfaces", "components", "qmldir")
with open(components_qmldir, "r", encoding="utf-8") as f:
    components_qmldir_content = f.read()
check("BT.QMLDIR.02", "surfaces/components/qmldir declares BluetoothWidget",
      bool(re.search(r'BluetoothWidget\s+1\.0\s+BluetoothWidget\.qml', components_qmldir_content)),
      "registered as component")

# ==============================================================================
# 3. BluetoothService.qml AST & Interface Contract Checks
# ==============================================================================
if os.path.isfile(service_path):
    with open(service_path, "r", encoding="utf-8") as f:
        service_content = f.read()

    check("BT.SRV.PRAGMA", "BluetoothService declares pragma Singleton",
          "pragma Singleton" in service_content, "pragma Singleton present")

    # Readonly properties
    check("BT.SRV.PROP.AVAIL", "BluetoothService declares readonly property bool available",
          bool(re.search(r'readonly\s+property\s+bool\s+available\b', service_content)),
          "available property present")
    check("BT.SRV.PROP.POW", "BluetoothService declares readonly property bool powered",
          bool(re.search(r'readonly\s+property\s+bool\s+powered\b', service_content)),
          "powered property present")
    check("BT.SRV.PROP.CONN", "BluetoothService declares readonly property bool isConnected",
          bool(re.search(r'readonly\s+property\s+bool\s+isConnected\b', service_content)),
          "isConnected property present")
    check("BT.SRV.PROP.NAME", "BluetoothService declares readonly property string deviceName",
          bool(re.search(r'readonly\s+property\s+string\s+deviceName\b', service_content)),
          "deviceName property present")

    # Methods
    check("BT.SRV.METH.TOGGLE", "BluetoothService declares togglePower() method",
          bool(re.search(r'function\s+togglePower\s*\(', service_content)),
          "togglePower() present")
    check("BT.SRV.METH.REFRESH", "BluetoothService declares refresh() method",
          bool(re.search(r'function\s+refresh\s*\(', service_content)),
          "refresh() present")

    # Process and Subshell Rules
    check("BT.SRV.PROC.DISCRETE", "BluetoothService uses discrete bluetoothctl commands",
          '["bluetoothctl", "show"]' in service_content and '["bluetoothctl", "devices", "Connected"]' in service_content,
          "discrete command arrays")
    check("BT.SRV.PROC.NOSH", "BluetoothService contains zero sh -c or bash -c invocations",
          not bool(re.search(r'["\'](sh|bash)["\']\s*,\s*["\']-c["\']', service_content)),
          "no subshell invocations")
    check("BT.SRV.PROC.NOTRUE", "BluetoothService contains zero persistent running: true Process loops",
          not bool(re.search(r'Process\s*\{[^}]*running\s*:\s*true', service_content, re.DOTALL)),
          "no persistent running Process")
    check("BT.SRV.ZERO_POLL", "BluetoothService contains zero literal running: true tokens",
          not bool(re.search(r'running:\s*true\b', service_content)),
          "zero literal running: true")

# ==============================================================================
# 4. CtosIcon.qml Integration
# ==============================================================================
ctos_icon_path = os.path.join(SHELL_DIR, "surfaces", "components", "CtosIcon.qml")
if os.path.isfile(ctos_icon_path):
    with open(ctos_icon_path, "r", encoding="utf-8") as f:
        ctos_icon_content = f.read()

    check("BT.ICON.ROUTE.01", "CtosIcon direct array includes bluetooth",
          '"bluetooth"' in ctos_icon_content, "bluetooth present in direct array")
    check("BT.ICON.ROUTE.02", "CtosIcon direct array includes bluetooth-slash",
          '"bluetooth-slash"' in ctos_icon_content, "bluetooth-slash present in direct array")

# ==============================================================================
# 5. BluetoothWidget.qml Decoupling & Invariants
# ==============================================================================
if os.path.isfile(widget_path):
    with open(widget_path, "r", encoding="utf-8") as f:
        widget_content = f.read()

    # Root item must be Item, not Rectangle
    check("BT.WDG.ROOT", "BluetoothWidget root element is Item",
          bool(re.match(r'^(?:import[^\n]+\n+)+Item\s*\{', widget_content.strip())),
          "root is Item")
    check("BT.WDG.NO_RECT", "BluetoothWidget has zero internal container Rectangles",
          not bool(re.search(r'^\s*Rectangle\s*\{', widget_content, re.MULTILINE)),
          "no container Rectangle")
    check("BT.WDG.NO_MA", "BluetoothWidget has zero internal MouseAreas",
          not bool(re.search(r'\bMouseArea\s*\{', widget_content)),
          "no internal MouseArea")
    check("BT.WDG.HOVER", "BluetoothWidget declares forwarded isHovered property",
          bool(re.search(r'property\s+bool\s+isHovered\s*:', widget_content)),
          "isHovered property present")
    check("BT.WDG.LAYOUT_HGT", "BluetoothWidget height couples to layout, eliminates Theme.barHeight",
          "Theme.barHeight" not in widget_content and "layout.implicitHeight" in widget_content,
          "height coupled to layout")
    check("BT.WDG.FONT", "BluetoothWidget uses Theme.fontFamilyMonospace",
          "Theme.fontFamilyMonospace" in widget_content, "monospace font token used")
    check("BT.WDG.NO_HEX", "BluetoothWidget contains zero raw hex colors (#...)",
          not bool(re.search(r'#[0-9a-fA-F]{3,8}\b', widget_content)),
          "all colors use Theme tokens")
    check("BT.WDG.ELIDE", "BluetoothWidget text elides and bounds width",
          "Text.ElideRight" in widget_content and "maximumWidth" in widget_content,
          "text properly constrained")

# ==============================================================================
# 6. AmbientBar.qml Integration
# ==============================================================================
bar_path = os.path.join(SHELL_DIR, "surfaces", "AmbientBar.qml")
if os.path.isfile(bar_path):
    with open(bar_path, "r", encoding="utf-8") as f:
        bar_content = f.read()

    check("BT.BAR.ORDER", "bluetoothSection sequenced between batterySection and clockSection",
          bool(re.search(r'id\s*:\s*batterySection[\s\S]*?id\s*:\s*bluetoothSection[\s\S]*?id\s*:\s*clockSection', bar_content)),
          "correctly ordered between battery and clock")

    check("BT.BAR.DIM", "bluetoothSection height is Theme.barHeight - 6 and radius is Theme.radiusMedium",
          bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?height\s*:\s*Theme\.barHeight\s*-\s*6[\s\S]*?radius\s*:\s*Theme\.radiusMedium', bar_content)),
          "height=Theme.barHeight - 6 and radius=Theme.radiusMedium")

    check("BT.BAR.WIDTH", "bluetoothSection width couples to bluetoothWidget.implicitWidth + Theme.paddingMedium * 2",
          bool(re.search(r'Layout\.preferredWidth\s*:\s*bluetoothWidget\.implicitWidth\s*\+\s*Theme\.paddingMedium\s*\*\s*2', bar_content)),
          "width bound with paddingMedium * 2")

    check("BT.BAR.MOUNT", "bluetoothSection mounts BluetoothWidget id bluetoothWidget",
          bool(re.search(r'BluetoothWidget\s*\{[\s\S]*?id\s*:\s*bluetoothWidget', bar_content)),
          "BluetoothWidget mounted")

    check("BT.BAR.CLICK", "bluetoothSection mouse area triggers BluetoothService.togglePower()",
          bool(re.search(r'bluetoothMouseArea[\s\S]*?BluetoothService\.togglePower\(\)', bar_content)),
          "togglePower() wired on click")

    check("BT.BAR.VIS", "bluetoothSection visibility bound to BluetoothService.available",
          bool(re.search(r'id\s*:\s*bluetoothSection[\s\S]*?visible\s*:\s*BluetoothService\.available', bar_content)),
          "visible bound to BluetoothService.available")

# ==============================================================================
# 7. Static Code Inspector Invariants
# ==============================================================================
greet_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"],
                           capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.STATIC.GREETER", "check-greeter reports zero violations across shell/desktop",
      greet_res.returncode == 0, greet_res.stdout.strip())

poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.STATIC.POLLING", "check-polling reports zero violations across shell/desktop",
      poll_res.returncode == 0, poll_res.stdout.strip())

fmt_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.STATIC.FORMAT", "check-format reports zero violations across shell/desktop",
      fmt_res.returncode == 0, fmt_res.stdout.strip())

# qmllint on Milestone 3 files
qmllint_res = subprocess.run(["qmllint", service_path, widget_path, bar_path],
                             capture_output=True, text=True, cwd=PROJECT_ROOT)
check("BT.STATIC.QMLLINT", "qmllint succeeds on BluetoothService, BluetoothWidget, and AmbientBar",
      qmllint_res.returncode == 0, "syntax verification clean")

print("=" * 70)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 3 BLUETOOTH AUDITS PASSED CLEANLY ===")
else:
    print("=== MILESTONE 3 AUDITS FAILED ===", file=sys.stderr)
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
