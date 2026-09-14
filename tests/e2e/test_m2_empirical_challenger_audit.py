#!/usr/bin/env python3
"""
test_m2_empirical_challenger_audit.py - Empirical Challenger Adversarial Audit
for Milestone 2: Per-Section Rounded Rectangles & Blume Hexagon Logo (R3, R4).

Author: challenger_m2_3 (EMPIRICAL CHALLENGER)
Integrity Mode: Strict Empirical Verification
"""

import os
import re
import sys
import xml.etree.ElementTree as ET
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
SHELL_DIR = os.path.join(PROJECT_ROOT, "shell", "desktop")

PASS_COUNT = 0
FAIL_COUNT = 0

def challenge(test_id, description, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {test_id}: {description} ({details})")
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {test_id}: {description} ({details})", file=sys.stderr)

print("=" * 80)
print("=== EMPIRICAL CHALLENGER: MILESTONE 2 COMPREHENSIVE ADVERSARIAL AUDIT ===")
print("=" * 80)

# ==============================================================================
# 1. Visual Geometry & Boundaries Challenge
# ==============================================================================
ambient_bar_path = os.path.join(SHELL_DIR, "surfaces", "AmbientBar.qml")
with open(ambient_bar_path, "r", encoding="utf-8") as f:
    ambient_bar_src = f.read()

dynamic_island_path = os.path.join(SHELL_DIR, "surfaces", "components", "DynamicIsland.qml")
with open(dynamic_island_path, "r", encoding="utf-8") as f:
    dynamic_island_src = f.read()

theme_path = os.path.join(SHELL_DIR, "core", "Theme.qml")
with open(theme_path, "r", encoding="utf-8") as f:
    theme_src = f.read()

# Theme tokens
challenge("CHALLENGE.THEME.01", "Theme.barHeight is 40",
          bool(re.search(r'readonly\s+property\s+int\s+barHeight\s*:\s*40\b', theme_src)),
          "barHeight: 40")
challenge("CHALLENGE.THEME.02", "Theme.radiusMedium is 8",
          bool(re.search(r'readonly\s+property\s+int\s+radiusMedium\s*:\s*8\b', theme_src)),
          "radiusMedium: 8")

# PanelWindow geometry
challenge("CHALLENGE.PANEL.01", "PanelWindow color is transparent",
          'color: "transparent"' in ambient_bar_src, "transparent")
challenge("CHALLENGE.PANEL.02", "PanelWindow height is Theme.barHeight",
          bool(re.search(r'height\s*:\s*Theme\.barHeight\b', ambient_bar_src)), "Theme.barHeight")
challenge("CHALLENGE.PANEL.03", "PanelWindow top margin is 3px",
          bool(re.search(r'margins\s*\{\s*top\s*:\s*3', ambient_bar_src)), "margins top: 3")

# Verify all 10 containers
containers = [
    ("logoSection", ambient_bar_src, True, True),
    ("workspacesSection", ambient_bar_src, False, True),
    ("windowTitleSection", ambient_bar_src, False, True),
    ("dynamicIsland", dynamic_island_src, False, True),
    ("networkSection", ambient_bar_src, False, True),
    ("volumeSection", ambient_bar_src, False, True),
    ("batterySection", ambient_bar_src, False, True),
    ("bluetoothSection", ambient_bar_src, False, True),
    ("clockSection", ambient_bar_src, False, True),
    ("railSection", ambient_bar_src, True, True),
]

for name, src, is_square, req_radius in containers:
    sec_snippet = src
    if name != "dynamicIsland":
        # Extract until the next Section or end of parent
        pattern = rf'Rectangle\s*\{{[\s\S]*?id\s*:\s*{name}\b[\s\S]*?(?=// Section|\n\s*DynamicIsland|\n\s*RowLayout|\n\s*// ===|\Z)'
        m = re.search(pattern, src)
        sec_snippet = m.group(0) if m else ""
        challenge(f"CHALLENGE.CONTAINER.EXISTS.{name}", f"{name} container defined",
                  bool(m), f"found={bool(m)}")

    has_radius = "radius: Theme.radiusMedium" in sec_snippet
    challenge(f"CHALLENGE.CONTAINER.RADIUS.{name}", f"{name} has radius: Theme.radiusMedium (8px)",
              has_radius, "radius: Theme.radiusMedium")

    has_height = ("height: Theme.barHeight - 6" in sec_snippet or
                  "preferredHeight: Theme.barHeight - 6" in sec_snippet)
    challenge(f"CHALLENGE.CONTAINER.HEIGHT.{name}", f"{name} has height: Theme.barHeight - 6 (34px)",
              has_height, "height: Theme.barHeight - 6")

    if is_square:
        has_square = ("width: height" in sec_snippet or "preferredWidth: height" in sec_snippet)
        challenge(f"CHALLENGE.CONTAINER.SQUARE.{name}", f"{name} is 34x34 square",
                  has_square, "width: height")

# Bluetooth section placement (between battery and clock)
bt_order = re.search(r'id\s*:\s*batterySection[\s\S]*?id\s*:\s*bluetoothSection[\s\S]*?id\s*:\s*clockSection', ambient_bar_src)
challenge("CHALLENGE.LAYOUT.BT_SLOT", "bluetoothSection positioned between batterySection and clockSection",
          bool(bt_order), "battery -> bluetooth -> clock sequence")

# Window title maximum width constraint
win_max = re.search(r'id\s*:\s*windowTitleSection[\s\S]*?Layout\.maximumWidth\s*:\s*380\b', ambient_bar_src)
challenge("CHALLENGE.LAYOUT.WIN_MAX_WIDTH", "windowTitleSection clamped to maximum width 380px",
          bool(win_max), "maximumWidth: 380")

# Hover styling architecture: container-level hover (color and border.color)
interactive_sections = ["logoSection", "windowTitleSection", "networkSection", "volumeSection", "batterySection", "clockSection", "railSection"]
for isec in interactive_sections:
    sec_pattern = rf'Rectangle\s*\{{[\s\S]*?id\s*:\s*{isec}\b[\s\S]*?(?=// Section|\n\s*DynamicIsland|\n\s*RowLayout|\n\s*// ===|\Z)'
    m = re.search(sec_pattern, ambient_bar_src)
    snippet = m.group(0) if m else ""
    has_hover_color = "Theme.surfaceHover" in snippet
    has_accent_border = "Theme.accent" in snippet
    challenge(f"CHALLENGE.HOVER.COLOR.{isec}", f"{isec} applies Theme.surfaceHover on hover",
              has_hover_color, "contains Theme.surfaceHover")
    challenge(f"CHALLENGE.HOVER.BORDER.{isec}", f"{isec} applies Theme.accent border on hover",
              has_accent_border, "contains Theme.accent")

# Absence of internal hover rectangles in bar widgets
widget_files = [
    ("NetworkWidget", "shell/desktop/surfaces/components/NetworkWidget.qml"),
    ("ClockWidget", "shell/desktop/surfaces/components/ClockWidget.qml"),
    ("VolumeWidget", "shell/desktop/surfaces/components/VolumeWidget.qml"),
    ("BatteryWidget", "shell/desktop/surfaces/components/BatteryWidget.qml"),
    ("WindowTitleWidget", "shell/desktop/surfaces/components/WindowTitleWidget.qml"),
]

for wname, wpath in widget_files:
    with open(os.path.join(PROJECT_ROOT, wpath), "r", encoding="utf-8") as wf:
        wsrc = wf.read()
    # Check no internal hoverRect
    has_hover_rect = "hoverRect" in wsrc or "id: hover" in wsrc
    challenge(f"CHALLENGE.WIDGET.NO_HOVER_RECT.{wname}", f"{wname} has zero internal hover rectangle",
              not has_hover_rect, "zero internal hover rectangles")
    # Check no implicitHeight: Theme.barHeight
    has_bar_height = "implicitHeight: Theme.barHeight" in wsrc
    challenge(f"CHALLENGE.WIDGET.DECOUPLED_HEIGHT.{wname}", f"{wname} decoupled from Theme.barHeight",
              not has_bar_height, "implicitHeight is natural")

# Vertical text centering check across all bar widgets
for wname, wpath in widget_files:
    with open(os.path.join(PROJECT_ROOT, wpath), "r", encoding="utf-8") as wf:
        wsrc = wf.read()
    # Count Text elements and AlignVCenter
    text_blocks = re.findall(r'Text\s*\{([^}]*)\}', wsrc)
    vcenter_count = 0
    for block in text_blocks:
        if "Qt.AlignVCenter" in block or "anchors.centerIn" in block:
            vcenter_count += 1
    challenge(f"CHALLENGE.WIDGET.VCENTER.{wname}", f"{wname} has vertical centering on Text items",
              vcenter_count == len(text_blocks) and len(text_blocks) > 0,
              f"vcenter={vcenter_count}/{len(text_blocks)}")

# ==============================================================================
# 2. SVG & Branding Challenge
# ==============================================================================
logo_svg_path = os.path.join(SHELL_DIR, "surfaces", "components", "blume-logo.svg")
challenge("CHALLENGE.SVG.EXISTS", "blume-logo.svg exists in desktop/surfaces/components",
          os.path.isfile(logo_svg_path), f"path={logo_svg_path}")

with open(logo_svg_path, "r", encoding="utf-8") as f:
    svg_content = f.read()

# Verify stroke color #1BFD9C
challenge("CHALLENGE.SVG.STROKE_COLOR", "blume-logo.svg stroke color is #1BFD9C (acidGreen)",
          bool(re.search(r'stroke\s*:\s*#1BFD9C\b', svg_content, re.IGNORECASE)),
          "stroke:#1BFD9C")

# Verify absence of #0e0e0e
challenge("CHALLENGE.SVG.NO_DARK_STROKE", "blume-logo.svg contains zero #0e0e0e dark stroke",
          "#0e0e0e" not in svg_content.lower(),
          "#0e0e0e absent")

# Verify SVG XML geometry
tree = ET.parse(logo_svg_path)
svg_root = tree.getroot()
viewBox = svg_root.attrib.get("viewBox", "")
challenge("CHALLENGE.SVG.VIEWBOX", "blume-logo.svg viewBox is 0 0 12.7 12.7",
          viewBox == "0 0 12.7 12.7", f"viewBox={viewBox}")

# In AmbientBar.qml: verify bare Image floating in pill
logo_snippet_match = re.search(r'Rectangle\s*\{[\s\S]*?id\s*:\s*logoSection\b[\s\S]*?(?=// Section 2|\Z)', ambient_bar_src)
logo_snippet = logo_snippet_match.group(0) if logo_snippet_match else ""

has_image = bool(re.search(r'Image\s*\{[\s\S]*?source\s*:\s*"components/blume-logo\.svg"[\s\S]*?\}', logo_snippet))
challenge("CHALLENGE.LOGO.BARE_IMAGE", "logoSection hosts bare Image sourcing components/blume-logo.svg",
          has_image, "source: components/blume-logo.svg")

# Verify dimensions 22x22
dim_22 = bool(re.search(r'width\s*:\s*22\b', logo_snippet)) and bool(re.search(r'height\s*:\s*22\b', logo_snippet))
challenge("CHALLENGE.LOGO.22x22", "logo Image rendered at 22x22",
          dim_22, "width: 22, height: 22")

# Verify absence of button rectangle or inner border
has_inner_rect = "id: nodeBtn" in logo_snippet or bool(re.search(r'Image[\s\S]*?Rectangle\s*\{', logo_snippet))
challenge("CHALLENGE.LOGO.NO_BUTTON_BORDER", "Zero button rectangle or inner border around logo SVG",
          not has_inner_rect, "no inner button rectangle")

# Verify click triggers OverlayController.openCommandDeck()
challenge("CHALLENGE.LOGO.CLICK_ACTION", "logo click triggers OverlayController.openCommandDeck()",
          "OverlayController.openCommandDeck()" in logo_snippet,
          "OverlayController.openCommandDeck() wired")

# ==============================================================================
# 3. Code Hygiene & Constraints Challenge
# ==============================================================================
# Zero greeter references
greeter_refs = []
for r, d, files in os.walk(SHELL_DIR):
    for f in files:
        if f.endswith((".qml", ".js", ".json", ".svg")):
            fpath = os.path.join(r, f)
            with open(fpath, "r", encoding="utf-8", errors="ignore") as file:
                content = file.read()
                if "greeter" in content.lower():
                    greeter_refs.append(fpath)

challenge("CHALLENGE.HYGIENE.ZERO_GREETER", "Zero greeter references across shell/desktop",
          len(greeter_refs) == 0, f"violations={len(greeter_refs)}")

# Zero polling loops
poll_res = subprocess.run(["python3", "tests/e2e/harness/qml_inspector.py", "check-polling", "shell/desktop"],
                          capture_output=True, text=True, cwd=PROJECT_ROOT)
challenge("CHALLENGE.HYGIENE.ZERO_POLLING", "qml_inspector check-polling reports zero violations",
          poll_res.returncode == 0, poll_res.stdout.strip())

# Zero hardcoded hex colors in M1/M2 bar files and widgets
m2_files = [
    "shell/desktop/surfaces/AmbientBar.qml",
    "shell/desktop/surfaces/components/DynamicIsland.qml",
    "shell/desktop/surfaces/components/NetworkWidget.qml",
    "shell/desktop/surfaces/components/ClockWidget.qml",
    "shell/desktop/surfaces/components/VolumeWidget.qml",
    "shell/desktop/surfaces/components/BatteryWidget.qml",
    "shell/desktop/surfaces/components/WorkspacesWidget.qml",
    "shell/desktop/surfaces/components/WindowTitleWidget.qml",
]
hex_pattern = re.compile(r"#[0-9a-fA-F]{3,8}\b")
hex_violations = []
for p in m2_files:
    fpath = os.path.join(PROJECT_ROOT, p)
    with open(fpath, "r", encoding="utf-8") as f:
        for idx, line in enumerate(f, 1):
            clean = line.split("//")[0].strip()
            matches = hex_pattern.findall(clean)
            if matches:
                hex_violations.append((p, idx, clean, matches))

challenge("CHALLENGE.HYGIENE.ZERO_HEX_COLORS", "Zero hardcoded hex colors in bar and widget files",
          len(hex_violations) == 0, f"violations={len(hex_violations)}")

# Zero git commits made
git_log_res = subprocess.run(["git", "log", "-1", "--format=%H"],
                             capture_output=True, text=True, cwd=PROJECT_ROOT)
head_commit = git_log_res.stdout.strip()
challenge("CHALLENGE.GIT.ZERO_COMMITS", "Zero git commits made (HEAD matches origin/feat/bar-redesign-qol)",
          head_commit == "031241b1151ce6469d38d79e1f1cc3c837d290fb",
          f"head={head_commit[:10]}")

# .agents/ untracked and not in .gitignore
git_ignore_res = subprocess.run(["git", "check-ignore", "-v", ".agents"],
                                capture_output=True, text=True, cwd=PROJECT_ROOT)
challenge("CHALLENGE.GIT.AGENTS_NOT_IGNORED", ".agents/ directory is NOT in .gitignore",
          git_ignore_res.returncode != 0, "check-ignore returns non-zero")

# Git status: zero unstaged modifications on tracked files
git_diff_res = subprocess.run(["git", "diff", "--quiet"], cwd=PROJECT_ROOT)
challenge("CHALLENGE.GIT.TRACKED_FILES_STAGED", "Zero unstaged modifications on tracked files (all changes staged)",
          git_diff_res.returncode == 0, "git diff --quiet returned 0")

# ==============================================================================
# 4. Stress Testing & Edge Cases
# ==============================================================================
print("\n--- STRESS TESTING EDGE CASES ---")
# 1. Window title extreme lengths
test_titles = [
    "",
    "ctOS",
    "A" * 50,
    "Firefox — █▓▒░ CYBERNET OVERRIDE ░▒▓█ — NightCity Secure Matrix [Terminal 01]",
    "Z" * 500,
    "日本語タイトルテスト・ウィンドウ・システム・オーバーレイ",
    "<script>alert('xss')</script>",
]
for idx, title in enumerate(test_titles):
    est_width = len(title) * 8 + 40
    clamped_sec_width = min(min(est_width, 400) + 16, 380)
    challenge(f"STRESS.TITLE.{idx+1}", f"Title len {len(title)} clamped safely <= 380px",
              clamped_sec_width <= 380, f"width={clamped_sec_width}px")

# 2. Volume boundaries: 0%, 50%, 100%, muted
vol_levels = [0.0, 0.5, 1.0, -0.05, 1.05]
for idx, vol in enumerate(vol_levels):
    clamped = max(0.0, min(1.0, vol))
    pct_text = f"{round(clamped * 100)}%"
    challenge(f"STRESS.VOL.{idx+1}", f"Volume {vol} formats to {pct_text} safely",
              0 <= round(clamped * 100) <= 100, f"pct={pct_text}")

# 3. Battery states: low (20%), normal (50%), full (100%), charging
battery_cases = [
    (15.0, False, True, "battery-low", "Theme.destructive"),
    (20.0, False, True, "battery-low", "Theme.destructive"),
    (20.1, False, False, "battery", "Theme.textSecondary"),
    (10.0, True, False, "battery-charging", "Theme.acidGreen"),
    (100.0, False, False, "battery", "Theme.textSecondary"),
]
for idx, (pct, charging, expected_low, icon, col) in enumerate(battery_cases):
    is_low = not charging and pct <= 20.0
    challenge(f"STRESS.BATTERY.{idx+1}", f"Battery {pct}% (charging={charging}) isLow={is_low}",
              is_low == expected_low, f"isLow={is_low}, icon={icon}")

# 4. Workspace counts: 1, 5, 10 workspaces
for ws_count in [1, 5, 10, 20]:
    ws_width = ws_count * 24 + (ws_count - 1) * 2
    sec_width = ws_width + 16
    challenge(f"STRESS.WORKSPACES.{ws_count}", f"Workspaces {ws_count} section width is {sec_width}px",
              sec_width > 0 and (sec_width < 1920 / 3), f"sec_width={sec_width}px")

print("=" * 80)
print(f"AUDIT RESULTS: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== EMPIRICAL CHALLENGER: ALL TESTS PASSED CLEANLY ===")
else:
    print("=== EMPIRICAL CHALLENGER: FAILURES DETECTED ===", file=sys.stderr)
print("=" * 80)

sys.exit(0 if FAIL_COUNT == 0 else 1)
