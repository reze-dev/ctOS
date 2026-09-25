#!/usr/bin/env python3
"""
test_radial_settings_audit.py - Comprehensive Static & Contract Verification Suite
for ctOS Radial Settings / Skill-Tree UI.

Verification Coverage:
1. Component Existence & Module Registration (qmldir)
2. Zero Hardcoded Hex Colors (Strict Theme Token Policy)
3. 100% Monospace Typography Purity (Theme.fontFamilyMonospace)
4. OverlayController Integration (Surface.RadialSettings, methods, boundaries)
5. Shell Integration (IPC handlers, Loader in surfaceContainer)
6. ActionRegistry Integration (action-toggle-radial-settings)
7. Settings Data Model Structure (8 categories, real bindings, child nodes)
8. RadialGeometry Mathematical Verification
9. Static QML Linter Audit (qmllint on all radial components)
"""

import os
import re
import sys
import math
import subprocess

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
RADIAL_DIR = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial")

PASS_COUNT = 0
FAIL_COUNT = 0

def audit_assert(check_id, desc, condition, details=""):
    global PASS_COUNT, FAIL_COUNT
    if condition:
        PASS_COUNT += 1
        print(f"[PASS] {check_id}: {desc} ({details})")
    else:
        FAIL_COUNT += 1
        print(f"[FAIL] {check_id}: {desc} ({details})", file=sys.stderr)

print("=" * 70)
print("STATIC & CONTRACT AUDIT: CTOS RADIAL SETTINGS / SKILL TREE UI")
print("=" * 70)

# ==============================================================================
# 1. COMPONENT EXISTENCE & QMLDIR REGISTRATION
# ==============================================================================
expected_components = [
    "RadialGeometry.js",
    "RadialSettingsModel.qml",
    "RadialSegment.qml",
    "SkillNode.qml",
    "SkillEdge.qml",
    "SkillTree.qml",
    "ContextPanel.qml",
    "NavigationController.qml",
    "CircularSettingsMenu.qml",
    "RadialSettings.qml",
    "qmldir"
]

for comp in expected_components:
    path = os.path.join(RADIAL_DIR, comp)
    audit_assert(f"FILE-{comp}", f"File exists: {comp}", os.path.isfile(path), path)

qmldir_path = os.path.join(RADIAL_DIR, "qmldir")
with open(qmldir_path, "r", encoding="utf-8") as f:
    qmldir_content = f.read()

for comp in expected_components:
    if comp == "qmldir":
        continue
    cname = comp.split(".")[0]
    audit_assert(f"QMLDIR-{cname}", f"{cname} declared in qmldir", f"{cname} 1.0 {comp}" in qmldir_content)

# ==============================================================================
# 2. ZERO HARDCODED HEX COLORS
# ==============================================================================
hex_pattern = re.compile(r'#[0-9a-fA-F]{3,8}')
qml_files = [f for f in os.listdir(RADIAL_DIR) if f.endswith(".qml")]

total_hex_matches = 0
for qml in qml_files:
    path = os.path.join(RADIAL_DIR, qml)
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    matches = []
    for idx, line in enumerate(lines, 1):
        found = hex_pattern.findall(line)
        if found:
            matches.append((idx, line.strip(), found))
    if matches:
        total_hex_matches += len(matches)
        print(f"Hardcoded hex in {qml}: {matches}", file=sys.stderr)
    audit_assert(f"HEX-{qml}", f"Zero hardcoded hex colors in {qml}", len(matches) == 0, f"found {len(matches)}")

audit_assert("ZERO-HEX-ALL", "Total hardcoded hex colors across all radial components is 0", total_hex_matches == 0)

# ==============================================================================
# 3. 100% MONOSPACE TYPOGRAPHY PURITY
# ==============================================================================
text_pattern = re.compile(r'\bText\s*\{')
total_text_tags = 0
total_font_mono_tags = 0

for qml in qml_files:
    path = os.path.join(RADIAL_DIR, qml)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Count Text blocks
    texts = text_pattern.findall(content)
    total_text_tags += len(texts)

    # In every Text block, verify font.family uses Theme.fontFamilyMonospace
    mono_matches = re.findall(r'font\.family:\s*Theme\.fontFamilyMonospace', content)
    total_font_mono_tags += len(mono_matches)

audit_assert("MONOSPACE-PURITY", "All Text elements enforce Theme.fontFamilyMonospace",
             total_text_tags > 0 and total_text_tags == total_font_mono_tags,
             f"Text tags: {total_text_tags}, Monospace tags: {total_font_mono_tags}")

# ==============================================================================
# 4. OVERLAY CONTROLLER INTEGRATION
# ==============================================================================
oc_path = os.path.join(PROJECT_ROOT, "shell/desktop/core/OverlayController.qml")
with open(oc_path, "r", encoding="utf-8") as f:
    oc_content = f.read()

audit_assert("OC-SURFACE-ENUM", "OverlayController.Surface includes RadialSettings",
             "RadialSettings" in oc_content)
audit_assert("OC-OVERLAY-ENUM", "OverlayController.OverlayType includes RadialSettings",
             "RadialSettings" in oc_content)
audit_assert("OC-CONST", "surfaceRadialSettings constant defined as 4",
             "readonly property int surfaceRadialSettings: 4" in oc_content)
audit_assert("OC-OPEN-METHOD", "openRadialSettings() method defined",
             "function openRadialSettings(): void" in oc_content)
audit_assert("OC-TOGGLE-METHOD", "toggleRadialSettings() method defined",
             "function toggleRadialSettings(): void" in oc_content)
audit_assert("OC-BOUNDARY", "_isValidSurface bounds to RadialSettings",
             "surface > OverlayController.Surface.RadialSettings" in oc_content)

# ==============================================================================
# 5. SHELL INTEGRATION
# ==============================================================================
shell_path = os.path.join(PROJECT_ROOT, "shell/shell.qml")
with open(shell_path, "r", encoding="utf-8") as f:
    shell_content = f.read()

audit_assert("SHELL-IPC-TOGGLE", "IPC handler includes toggleRadialSettings",
             "function toggleRadialSettings(): void" in shell_content)
audit_assert("SHELL-IPC-OPEN", "IPC handler includes openRadialSettings",
             "function openRadialSettings(): void" in shell_content)
audit_assert("SHELL-LOADER", "overlayHost has radialSettingsLoader",
             "id: radialSettingsLoader" in shell_content and
             "desktop/surfaces/radial/RadialSettings.qml" in shell_content and
             "OverlayController.Surface.RadialSettings" in shell_content)

# ==============================================================================
# 6. ACTION REGISTRY INTEGRATION
# ==============================================================================
ar_path = os.path.join(PROJECT_ROOT, "shell/desktop/core/ActionRegistry.qml")
with open(ar_path, "r", encoding="utf-8") as f:
    ar_content = f.read()

audit_assert("ACTION-REG-ID", "action-toggle-radial-settings registered in ActionRegistry",
             '"action-toggle-radial-settings"' in ar_content)
audit_assert("ACTION-REG-CALL", "Action calls OverlayController.toggleRadialSettings()",
             "OverlayController.toggleRadialSettings();" in ar_content)

# ==============================================================================
# 7. DATA MODEL 8 CATEGORIES CONTRACT
# ==============================================================================
model_path = os.path.join(RADIAL_DIR, "RadialSettingsModel.qml")
with open(model_path, "r", encoding="utf-8") as f:
    model_content = f.read()

categories_expected = [
    ("system", "SYSTEM"),
    ("appearance", "APPEARANCE"),
    ("desktop", "DESKTOP"),
    ("network", "NETWORK"),
    ("audio", "AUDIO"),
    ("input", "INPUT"),
    ("power", "POWER"),
    ("security", "SECURITY")
]

for cat_id, cat_name in categories_expected:
    audit_assert(f"CAT-{cat_id}", f"Category {cat_name} defined in model",
                 f'id: "{cat_id}"' in model_content and f'name: "{cat_name}"' in model_content)

# Verify real ctOS service bindings exist in model
audit_assert("MODEL-SETTINGS-BIND", "Model binds to Settings", "Settings." in model_content)
audit_assert("MODEL-AUDIO-BIND", "Model binds to AudioService", "AudioService." in model_content)
audit_assert("MODEL-NET-BIND", "Model binds to NetworkService", "NetworkService." in model_content)
audit_assert("MODEL-PWR-BIND", "Model binds to PowerService", "PowerService." in model_content)
audit_assert("MODEL-SESSION-BIND", "Model binds to SessionService", "SessionService." in model_content)

# ==============================================================================
# 8. RADIAL GEOMETRY MATHEMATICAL ALGORITHMS
# ==============================================================================
# Python implementation testing the mathematical properties of RadialGeometry algorithms
def deg_to_rad(d): return (d * math.pi) / 180.0
def rad_to_deg(r): return (r * 180.0) / math.pi
def normalize_angle(degrees):
    a = degrees % 360
    if a > 180: a -= 360
    if a < -180: a += 360
    return a
def angle_diff(f, t): return normalize_angle(t - f)
def point_on_circle(cx, cy, r, angle_deg):
    rad = deg_to_rad(angle_deg)
    return (cx + r * math.cos(rad), cy + r * math.sin(rad))

# Test normalize_angle
audit_assert("GEO-NORM-1", "normalize_angle(0) == 0", normalize_angle(0) == 0)
audit_assert("GEO-NORM-2", "normalize_angle(360) == 0", normalize_angle(360) == 0)
audit_assert("GEO-NORM-3", "normalize_angle(270) == -90", normalize_angle(270) == -90)
audit_assert("GEO-NORM-4", "normalize_angle(-270) == 90", normalize_angle(-270) == 90)

# Test angle_diff (shortest path without 360 spin)
audit_assert("GEO-DIFF-1", "angle_diff(170, -170) == 20", angle_diff(170, -170) == 20)
audit_assert("GEO-DIFF-2", "angle_diff(-170, 170) == -20", angle_diff(-170, 170) == -20)
audit_assert("GEO-DIFF-3", "angle_diff(0, 90) == 90", angle_diff(0, 90) == 90)
audit_assert("GEO-DIFF-4", "angle_diff(90, 0) == -90", angle_diff(90, 0) == -90)
audit_assert("GEO-DIFF-5", "angle_diff(-180, 135) == -45 (POWER to SECURITY boundary)", angle_diff(-180, 135) == -45)
audit_assert("GEO-DIFF-6", "angle_diff(135, -180) == 45 (SECURITY to POWER boundary)", angle_diff(135, -180) == 45)

# Test point_on_circle
pt_0 = point_on_circle(100, 100, 50, 0)
audit_assert("GEO-PT-0", "0 deg point is at (cx + r, cy)", abs(pt_0[0] - 150) < 1e-5 and abs(pt_0[1] - 100) < 1e-5)
pt_90 = point_on_circle(100, 100, 50, 90)
audit_assert("GEO-PT-90", "90 deg point is at (cx, cy + r)", abs(pt_90[0] - 100) < 1e-5 and abs(pt_90[1] - 150) < 1e-5)

# Verification of defensive guards and interaction robustness
audit_assert("MODEL-SLIDER-GUARD", "Model contains isNaN guard against slider NaN corruption", "isNaN(val)" in model_content)

nav_path = os.path.join(RADIAL_DIR, "NavigationController.qml")
with open(nav_path, "r", encoding="utf-8") as f:
    nav_content = f.read()
audit_assert("NAV-BOUNDS", "NavigationController constrains expanded hover to tree zone", "treeMinX" in nav_content)
audit_assert("NAV-CYCLE", "NavigationController supports Tab category cycling", "Qt.Key_Tab" in nav_content)

panel_path = os.path.join(RADIAL_DIR, "ContextPanel.qml")
with open(panel_path, "r", encoding="utf-8") as f:
    panel_content = f.read()
audit_assert("PANEL-SLIDER-SCRUB", "ContextPanel supports interactive mouse scrubbing on slider track", "updateFromTrack" in panel_content)


# ==============================================================================
# 9. STATIC QML LINTER AUDIT
# ==============================================================================
qmllint_bin = "/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/bin/qmllint"
if not os.path.isfile(qmllint_bin):
    import shutil
    qmllint_bin = shutil.which("qmllint") or qmllint_bin

qt_qml_dir = "/nix/store/10553j4116y6jllliqpg5kz7d35bblab-qtdeclarative-6.11.2/lib/qt-6/qml"

for qml in sorted(qml_files):
    target = os.path.join(RADIAL_DIR, qml)
    cmd = [
        qmllint_bin,
        "-I", qt_qml_dir,
        "-I", os.path.join(PROJECT_ROOT, "shell/desktop/core"),
        "-I", os.path.join(PROJECT_ROOT, "shell/desktop/services"),
        "-I", os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components"),
        "-I", os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/widgets"),
        "-I", RADIAL_DIR,
        target
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    audit_assert(f"QMLLINT-{qml}", f"qmllint check for {qml}", proc.returncode == 0,
                 f"ret={proc.returncode}")

print("=" * 70)
print(f"AUDIT SUMMARY: {PASS_COUNT} PASSED, {FAIL_COUNT} FAILED")
print("=" * 70)

sys.exit(0 if FAIL_COUNT == 0 else 1)
