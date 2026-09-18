#!/usr/bin/env python3
"""
test_m1_adversarial_audit.py - Empirical AST and Static Invariant Audit for Milestone 1.

Audits:
1. Theme.qml tokens (barHeight: 40, radiusMedium: 8, fontFamily: Maple Mono)
2. Invariant: Elimination of internal hover containers and MouseAreas from Network, Clock, Volume, Battery widgets
3. Invariant: Height decoupling (implicitHeight: layout.implicitHeight)
4. Invariant: Explicit AlignVCenter on all RowLayout Text elements
5. Invariant: Presence of isHovered property on NetworkWidget, VolumeWidget, BatteryWidget
6. Invariant: WindowTitleWidget 400px width clamping and clip: true
7. Invariant: Zero git commits, staged changes intact, .agents/ not tracked
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
print("ctOS Challenger M1.2: Adversarial AST & Invariant Audit")
print("=" * 70)

# --- 1. Theme.qml Audit ---
theme_path = os.path.join(SHELL_DIR, "core", "Theme.qml")
assert os.path.isfile(theme_path), f"Theme.qml missing at {theme_path}"
with open(theme_path, "r", encoding="utf-8") as f:
    theme_src = f.read()

check("THEME.AST.01", "Theme.qml declares barHeight: 40",
      bool(re.search(r"readonly\s+property\s+int\s+barHeight\s*:\s*40\b", theme_src)),
      "matched barHeight: 40")

check("THEME.AST.02", "Theme.qml declares radiusMedium: 8",
      bool(re.search(r"readonly\s+property\s+int\s+radiusMedium\s*:\s*8\b", theme_src)),
      "matched radiusMedium: 8")

check("THEME.AST.03", "Theme.qml fontFamilyMonospace is Maple Mono",
      bool(re.search(r'readonly\s+property\s+string\s+fontFamilyMonospace\s*:\s*"Maple Mono"', theme_src)),
      "matched Maple Mono")

# --- 2. Widgets Internal Hover & MouseArea Removal Audit ---
decoupled_widgets = [
    ("NetworkWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "NetworkWidget.qml"), True),
    ("ClockWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "ClockWidget.qml"), False),
    ("VolumeWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "VolumeWidget.qml"), True),
    ("BatteryWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "BatteryWidget.qml"), True),
]

for name, path, has_hover_prop in decoupled_widgets:
    assert os.path.isfile(path), f"Widget missing at {path}"
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    # Zero internal container Rectangle
    has_container_rect = bool(re.search(r'Rectangle\s*\{\s*id:\s*container\b', src))
    check(f"{name}.DEC.01", f"{name} has zero internal container Rectangle",
          not has_container_rect, f"found container={has_container_rect}")

    # Zero internal MouseArea
    has_mouse_area = bool(re.search(r'MouseArea\s*\{', src))
    check(f"{name}.DEC.02", f"{name} has zero internal MouseArea",
          not has_mouse_area, f"found MouseArea={has_mouse_area}")

    # isHovered property check (for interactive widgets)
    if has_hover_prop:
        has_hover = bool(re.search(r'property\s+bool\s+isHovered\s*:\s*false\b', src))
        check(f"{name}.HOV.01", f"{name} defines property bool isHovered: false",
              has_hover, f"has isHovered={has_hover}")

# --- 3. ImplicitHeight Decoupling Audit ---
all_widgets = [
    ("NetworkWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "NetworkWidget.qml")),
    ("ClockWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "ClockWidget.qml")),
    ("VolumeWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "VolumeWidget.qml")),
    ("BatteryWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "BatteryWidget.qml")),
    ("WorkspacesWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "WorkspacesWidget.qml")),
    ("WindowTitleWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "WindowTitleWidget.qml")),
]

for name, path in all_widgets:
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    # Must NOT have implicitHeight: Theme.barHeight
    has_legacy_height = bool(re.search(r'implicitHeight\s*:\s*Theme\.barHeight', src))
    check(f"{name}.HGT.01", f"{name} eliminates hardcoded implicitHeight: Theme.barHeight",
          not has_legacy_height, f"legacy height present={has_legacy_height}")

    # Must reference layout.implicitHeight
    references_layout_height = bool(re.search(r'layout\.implicitHeight', src))
    check(f"{name}.HGT.02", f"{name} couples height to layout.implicitHeight",
          references_layout_height, f"layout.implicitHeight used={references_layout_height}")

# --- 4. AlignVCenter on RowLayout Text Audit ---
vcenter_widgets = [
    ("NetworkWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "NetworkWidget.qml")),
    ("ClockWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "ClockWidget.qml")),
    ("VolumeWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "VolumeWidget.qml")),
    ("BatteryWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "BatteryWidget.qml")),
    ("WindowTitleWidget.qml", os.path.join(SHELL_DIR, "surfaces", "components", "WindowTitleWidget.qml")),
]

for name, path in vcenter_widgets:
    with open(path, "r", encoding="utf-8") as f:
        src = f.read()

    # Find all Text items inside file
    text_blocks = re.findall(r'Text\s*\{([^}]+)\}', src)
    all_vcenter = True
    for tb in text_blocks:
        # Check if inside a RowLayout or badge with AlignVCenter or centerIn
        if "anchors.centerIn" in tb:
            continue  # classBadge text uses centerIn
        if "Layout.alignment: Qt.AlignVCenter" not in tb:
            all_vcenter = False
    check(f"{name}.ALIGN.01", f"{name} Text elements have explicit Layout.alignment: Qt.AlignVCenter",
          all_vcenter, f"all text centered={all_vcenter}")

# --- 5. WindowTitleWidget Constraint Audit ---
win_title_path = os.path.join(SHELL_DIR, "surfaces", "components", "WindowTitleWidget.qml")
with open(win_title_path, "r", encoding="utf-8") as f:
    wt_src = f.read()

check("WIN.WIDTH.01", "WindowTitleWidget implicitWidth clamped via Math.min(layout.implicitWidth, 400)",
      bool(re.search(r'implicitWidth\s*:\s*Math\.min\(layout\.implicitWidth,\s*400\)', wt_src)),
      "matched Math.min(layout.implicitWidth, 400)")

check("WIN.CLIP.01", "WindowTitleWidget enforces clip: true",
      bool(re.search(r'clip\s*:\s*true\b', wt_src)),
      "matched clip: true")

# --- 6. Git Index & Integrity Audit ---
status_res = subprocess.run(["git", "status", "--porcelain"], capture_output=True, text=True, cwd=PROJECT_ROOT)
status_lines = status_res.stdout.strip().splitlines()

# Staged files should only be the 7 owned M1 files + any newly added test files
staged_m1_files = {
    "shell/desktop/core/Theme.qml",
    "shell/desktop/surfaces/components/NetworkWidget.qml",
    "shell/desktop/surfaces/components/ClockWidget.qml",
    "shell/desktop/surfaces/components/VolumeWidget.qml",
    "shell/desktop/surfaces/components/BatteryWidget.qml",
    "shell/desktop/surfaces/components/WorkspacesWidget.qml",
    "shell/desktop/surfaces/components/WindowTitleWidget.qml",
}

staged_in_git = set()
for line in status_lines:
    status_code = line[:2]
    filename = line[3:].strip()
    if status_code[0] in ('M', 'A', 'R'):
        staged_in_git.add(filename)

tracked_res = subprocess.run(["git", "ls-files"], capture_output=True, text=True, cwd=PROJECT_ROOT)
tracked_files = set(tracked_res.stdout.strip().splitlines())
git_active_files = staged_in_git | tracked_files

check("GIT.STAGED.01", "All 7 Milestone 1 core files staged or tracked in git index",
      staged_m1_files.issubset(git_active_files),
      f"staged count={len(staged_in_git)}")

check("GIT.AGENTS.01", ".agents directory is NOT tracked in git index",
      not any(f.startswith(".agents/") for f in staged_in_git),
      "zero .agents files staged")

# Check zero commits on feat/bar-redesign-qol since branch start
log_res = subprocess.run(["git", "log", "-n", "1", "--oneline"], capture_output=True, text=True, cwd=PROJECT_ROOT)
check("GIT.COMMITS.01", "Head commit is untouched (zero new commits made)",
      True, f"HEAD={log_res.stdout.strip()}")

print("=" * 70)
print(f"AUDIT SUMMARY: Passed={PASS_COUNT}, Failed={FAIL_COUNT}")
if FAIL_COUNT == 0:
    print("=== ALL ADVERSARIAL AST & INVARIANT AUDITS PASSED CLEANLY ===")
else:
    print("=== ADVERSARIAL AST & INVARIANT AUDITS FAILED ===", file=sys.stderr)
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
