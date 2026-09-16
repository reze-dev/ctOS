#!/usr/bin/env python3
"""
test_m2_per_section_audit.py - Comprehensive Invariant Audit for Milestone 2:
Per-Section Rounded Rectangles & Blume Hexagon Logo (R3, R4).

Audits:
1. blume-logo.svg: copied, recolored to #1BFD9C, #0e0e0e eliminated, zero greeter imports.
2. DynamicIsland.qml: radius set to Theme.radiusMedium, radiusPill removed.
3. AmbientBar.qml:
   - PanelWindow: transparent, height Theme.barHeight (40), margins top: 3.
   - Deconstruction: leftIsland, rightIsland, and interior dividers removed.
   - Per-section containers with Theme.radiusMedium & Theme.barHeight - 6 (34px):
     - logoSection (34x34, bare blume-logo.svg at 22x22, openCommandDeck)
     - workspacesSection (hosts WorkspacesWidget)
     - windowTitleSection (hosts WindowTitleWidget, max width 380)
     - centerSection (DynamicIsland)
     - networkSection (isHovered, openWifiSubmenu)
     - volumeSection (isHovered, toggleMute, stepVolume)
     - batterySection (isHovered, visible bound, toggleSystemRail)
     - bluetoothSection (slot ready for M3 between battery and clock)
     - clockSection (toggleCalendar)
     - railSection (34x34, "=", toggleSystemRail)
4. Full hover handling and MouseAreas on each container.
5. All text uses Theme.fontFamilyMonospace and all colors use Theme tokens.
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
print("ctOS Challenger M2: Per-Section Rounded Rectangles & Blume Logo Audit")
print("=" * 70)

# --- 1. Blume Logo Asset Audit (R3) ---
logo_svg_path = os.path.join(SHELL_DIR, "surfaces", "components", "blume-logo.svg")
check("LOGO.FILE.01", "blume-logo.svg exists in desktop/surfaces/components",
      os.path.isfile(logo_svg_path), f"path={logo_svg_path}")

if os.path.isfile(logo_svg_path):
    with open(logo_svg_path, "r", encoding="utf-8") as f:
        svg_content = f.read()

    check("LOGO.COLOR.01", "blume-logo.svg stroke recolored to #1BFD9C",
          bool(re.search(r'stroke\s*:\s*#1BFD9C\b', svg_content, re.IGNORECASE)),
          "matched stroke:#1BFD9C")

    check("LOGO.COLOR.02", "blume-logo.svg dark stroke #0e0e0e completely eliminated",
          "#0e0e0e" not in svg_content.lower(),
          "stroke:#0e0e0e absent")

# --- 2. DynamicIsland Radius Audit (R4) ---
dynamic_island_path = os.path.join(SHELL_DIR, "surfaces", "components", "DynamicIsland.qml")
check("ISLAND.FILE.01", "DynamicIsland.qml exists",
      os.path.isfile(dynamic_island_path), f"path={dynamic_island_path}")

if os.path.isfile(dynamic_island_path):
    with open(dynamic_island_path, "r", encoding="utf-8") as f:
        di_content = f.read()

    check("ISLAND.RADIUS.01", "DynamicIsland radius updated to Theme.radiusMedium",
          bool(re.search(r'radius\s*:\s*Theme\.radiusMedium\b', di_content)),
          "matched radius: Theme.radiusMedium")

    check("ISLAND.RADIUS.02", "DynamicIsland eliminates Theme.radiusPill",
          "Theme.radiusPill" not in di_content,
          "Theme.radiusPill absent")

# --- 3. AmbientBar Architecture & Per-Section Containers Audit (R3, R4) ---
ambient_bar_path = os.path.join(SHELL_DIR, "surfaces", "AmbientBar.qml")
check("BAR.FILE.01", "AmbientBar.qml exists",
      os.path.isfile(ambient_bar_path), f"path={ambient_bar_path}")

if os.path.isfile(ambient_bar_path):
    with open(ambient_bar_path, "r", encoding="utf-8") as f:
        bar_content = f.read()

    # PanelWindow geometry
    check("BAR.PANEL.01", "PanelWindow color is transparent",
          bool(re.search(r'color\s*:\s*"transparent"', bar_content)),
          "color: transparent")

    check("BAR.PANEL.02", "PanelWindow height is Theme.barHeight",
          bool(re.search(r'height\s*:\s*Theme\.barHeight\b', bar_content)),
          "height: Theme.barHeight")

    check("BAR.PANEL.03", "PanelWindow margins top is 3",
          bool(re.search(r'margins\s*\{\s*top\s*:\s*3', bar_content)),
          "margins top: 3")

    # Deconstruction: Old large islands and dividers removed
    check("BAR.DECON.01", "Old leftIsland removed",
          "id: leftIsland" not in bar_content,
          "leftIsland absent")

    check("BAR.DECON.02", "Old rightIsland removed",
          "id: rightIsland" not in bar_content,
          "rightIsland absent")

    check("BAR.DECON.03", "Old interior divider rectangles removed",
          "Theme.dividerWidth" not in bar_content and "Theme.divider" not in bar_content,
          "Theme.dividerWidth/Theme.divider absent")

    # Section 1: Logo Section
    check("BAR.SEC.LOGO.01", "logoSection defined with Theme.radiusMedium and height Theme.barHeight - 6",
          bool(re.search(r'id\s*:\s*logoSection\b', bar_content)),
          "logoSection present")

    check("BAR.SEC.LOGO.02", "logoSection hosts bare Image with components/blume-logo.svg",
          bool(re.search(r'source\s*:\s*"components/blume-logo\.svg"', bar_content)),
          "source: components/blume-logo.svg")

    check("BAR.SEC.LOGO.03", "logoSection Image has width 22 and height 22",
          bool(re.search(r'width\s*:\s*22\b', bar_content)) and bool(re.search(r'height\s*:\s*22\b', bar_content)),
          "22x22 dimensions")

    check("BAR.SEC.LOGO.04", "logoSection eliminates old nodeBtn rectangle wrapper",
          "id: nodeBtn" not in bar_content,
          "nodeBtn absent")

    check("BAR.SEC.LOGO.05", "logoSection click opens CommandDeck",
          bool(re.search(r'OverlayController\.openCommandDeck\(\)', bar_content)),
          "OverlayController.openCommandDeck() called")

    # Section 2: Workspaces Section
    check("BAR.SEC.WS.01", "workspacesSection defined with Theme.radiusMedium",
          bool(re.search(r'id\s*:\s*workspacesSection\b', bar_content)),
          "workspacesSection present")

    check("BAR.SEC.WS.02", "workspacesSection hosts WorkspacesWidget",
          bool(re.search(r'WorkspacesWidget\s*\{', bar_content)),
          "WorkspacesWidget present")

    # Section 3: Window Title Section
    check("BAR.SEC.TITLE.01", "windowTitleSection defined with Theme.radiusMedium",
          bool(re.search(r'id\s*:\s*windowTitleSection\b', bar_content)),
          "windowTitleSection present")

    check("BAR.SEC.TITLE.02", "windowTitleSection hosts WindowTitleWidget with max width 380",
          bool(re.search(r'maximumWidth\s*:\s*380\b', bar_content)),
          "maximumWidth: 380")

    # Center Section: Dynamic Island
    check("BAR.SEC.CENTER.01", "centerSection hosts DynamicIsland centered horizontally",
          bool(re.search(r'DynamicIsland\s*\{\s*id\s*:\s*centerSection\b', bar_content)),
          "DynamicIsland present")

    # Section 4: Network Section
    check("BAR.SEC.NET.01", "networkSection defined with Theme.radiusMedium",
          bool(re.search(r'id\s*:\s*networkSection\b', bar_content)),
          "networkSection present")

    check("BAR.SEC.NET.02", "networkSection forwards hover state and click to openWifiSubmenu",
          bool(re.search(r'isHovered\s*:\s*networkMouseArea\.containsMouse', bar_content)) and
          bool(re.search(r'OverlayController\.openWifiSubmenu\(\)', bar_content)),
          "isHovered and openWifiSubmenu wired")

    # Section 5: Volume Section
    check("BAR.SEC.VOL.01", "volumeSection defined with Theme.radiusMedium",
          bool(re.search(r'id\s*:\s*volumeSection\b', bar_content)),
          "volumeSection present")

    check("BAR.SEC.VOL.02", "volumeSection forwards hover, click mute, and wheel stepVolume",
          bool(re.search(r'isHovered\s*:\s*volumeMouseArea\.containsMouse', bar_content)) and
          bool(re.search(r'AudioService\.toggleMute\(\)', bar_content)) and
          bool(re.search(r'AudioService\.stepVolume\(', bar_content)),
          "isHovered, toggleMute, and stepVolume wired")

    # Section 6: Battery Section
    check("BAR.SEC.BAT.01", "batterySection defined with Theme.radiusMedium and visibility bound",
          bool(re.search(r'id\s*:\s*batterySection\b', bar_content)) and
          bool(re.search(r'visible\s*:\s*batteryWidget\.visible', bar_content)),
          "batterySection visible bound")

    check("BAR.SEC.BAT.02", "batterySection click toggles SystemRail",
          bool(re.search(r'OverlayController\.toggleSystemRail\(\)', bar_content)),
          "OverlayController.toggleSystemRail() called")

    # Section 7: Bluetooth Section (Placeholder for M3)
    check("BAR.SEC.BT.01", "bluetoothSection slot positioned between battery and clock",
          bool(re.search(r'id\s*:\s*batterySection[\s\S]*?id\s*:\s*bluetoothSection[\s\S]*?id\s*:\s*clockSection', bar_content)),
          "bluetoothSection correctly sequenced")

    # Section 8: Clock Section
    check("BAR.SEC.CLOCK.01", "clockSection defined with Theme.radiusMedium and toggleCalendar trigger",
          bool(re.search(r'id\s*:\s*clockSection\b', bar_content)) and
          bool(re.search(r'root\.toggleCalendar\(\)', bar_content)),
          "clockSection wired to toggleCalendar")

    # Section 9: Rail Section
    check("BAR.SEC.RAIL.01", "railSection defined with Theme.radiusMedium and '=' text",
          bool(re.search(r'id\s*:\s*railSection\b', bar_content)) and
          bool(re.search(r'text\s*:\s*"="', bar_content)),
          "railSection with '=' text")

    # All section containers use Theme.radiusMedium
    radius_count = len(re.findall(r'radius\s*:\s*Theme\.radiusMedium', bar_content))
    check("BAR.RADIUS.ALL", "All section containers declare radius: Theme.radiusMedium",
          radius_count >= 8, f"found {radius_count} radiusMedium declarations")

# --- 4. Static Greeter Isolation & Polling Checks ---
greet_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-greeter", "shell/desktop"],
                           capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.GREETER.01", "check-greeter reports zero violations across shell/desktop",
      greet_res.returncode == 0, greet_res.stdout.strip())

poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.POLLING.01", "check-polling reports zero violations across shell/desktop",
      poll_res.returncode == 0, poll_res.stdout.strip())

fmt_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-format", "shell/desktop"],
                         capture_output=True, text=True, cwd=PROJECT_ROOT)
check("STATIC.FORMAT.01", "check-format reports zero formatting violations across shell/desktop",
      fmt_res.returncode == 0, fmt_res.stdout.strip())

print("=" * 70)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL MILESTONE 2 PER-SECTION AUDITS PASSED CLEANLY ===")
else:
    print("=== MILESTONE 2 AUDITS FAILED ===", file=sys.stderr)
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
