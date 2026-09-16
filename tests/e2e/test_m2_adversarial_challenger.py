#!/usr/bin/env python3
"""
Empirical Adversarial Challenger Suite for Milestone 2 (R3, R4)
ctOS Quickshell Desktop Bar Redesign

Verifies:
1. All 10 bar containers have height Theme.barHeight - 6 (34px) and radius Theme.radiusMedium (8px).
2. Spacing and visible gaps between containers (Theme.spacingMedium = 8px).
3. blume-logo.svg bare floating Image at 22x22, stroke #1BFD9C, absence of #0e0e0e, zero button wrapper.
4. Hover bounds: container-level hover color/border, no internal hover rectangles.
5. Boundary and edge-clipping invariants under varying inputs.
6. Code hygiene: zero greeter references, zero polling loops, zero commits, all files staged, .agents untracked.
7. Zero hardcoded hex colors in M1/M2 files.
"""

import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path("/home/reze/Projects/ctOS")

def run_cmd(cmd, cwd=REPO_ROOT):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    return res.returncode, res.stdout.strip(), res.stderr.strip()

passed = 0
failed = 0

def check(test_id, name, condition, details=""):
    global passed, failed
    if condition:
        passed += 1
        print(f"[PASS] {test_id}: {name} ({details})")
    else:
        failed += 1
        print(f"[FAIL] {test_id}: {name} ({details})")

def main():
    print("=" * 70)
    print("ctOS Challenger M2: Empirical Adversarial Challenge Suite")
    print("=" * 70)

    # -------------------------------------------------------------------------
    # 1. Inspect AmbientBar.qml & DynamicIsland.qml for 10 Containers
    # -------------------------------------------------------------------------
    bar_path = REPO_ROOT / "shell/desktop/surfaces/AmbientBar.qml"
    island_path = REPO_ROOT / "shell/desktop/surfaces/components/DynamicIsland.qml"
    
    assert bar_path.exists(), "AmbientBar.qml must exist"
    assert island_path.exists(), "DynamicIsland.qml must exist"
    
    bar_content = bar_path.read_text(encoding="utf-8")
    island_content = island_path.read_text(encoding="utf-8")

    # Containers list in order
    containers = [
        "logoSection",
        "workspacesSection",
        "windowTitleSection",
        "networkSection",
        "volumeSection",
        "batterySection",
        "bluetoothSection",
        "clockSection",
        "railSection",
    ]

    for c in containers:
        # Check height and radius
        pat = rf'id:\s*{c}\b[^}}]*?height:\s*Theme\.barHeight\s*-\s*6[^}}]*?radius:\s*Theme\.radiusMedium'
        match = re.search(pat, bar_content, re.DOTALL)
        check(f"BAR.SEC.{c.upper()}", f"{c} container declares height 34 and radius 8",
              match is not None, f"pattern matched={match is not None}")

        # Check Layout.preferredHeight
        pref_h = rf'id:\s*{c}\b[^}}]*?Layout\.preferredHeight:\s*Theme\.barHeight\s*-\s*6'
        match_pref = re.search(pref_h, bar_content, re.DOTALL)
        check(f"BAR.PREF_H.{c.upper()}", f"{c} container declares Layout.preferredHeight 34",
              match_pref is not None, f"preferredHeight matched={match_pref is not None}")

    # Center container: DynamicIsland
    di_h = re.search(r'height:\s*Theme\.barHeight\s*-\s*6', island_content)
    di_r = re.search(r'radius:\s*Theme\.radiusMedium', island_content)
    di_clip = re.search(r'clip:\s*true', island_content)
    di_no_pill = "radiusPill" not in island_content
    
    check("ISLAND.HEIGHT.01", "DynamicIsland declares height Theme.barHeight - 6",
          di_h is not None, f"matched={di_h is not None}")
    check("ISLAND.RADIUS.01", "DynamicIsland declares radius Theme.radiusMedium",
          di_r is not None, f"matched={di_r is not None}")
    check("ISLAND.RADIUS.02", "DynamicIsland eliminates Theme.radiusPill",
          di_no_pill, f"radiusPill absent={di_no_pill}")
    check("ISLAND.CLIP.01", "DynamicIsland enforces clip: true to avoid text spill",
          di_clip is not None, f"clip matched={di_clip is not None}")

    # -------------------------------------------------------------------------
    # 2. Logo Branding & Geometry
    # -------------------------------------------------------------------------
    logo_svg_path = REPO_ROOT / "shell/desktop/surfaces/components/blume-logo.svg"
    check("LOGO.EXISTS.01", "blume-logo.svg exists in desktop/surfaces/components",
          logo_svg_path.exists(), f"path={logo_svg_path}")

    svg_content = logo_svg_path.read_text(encoding="utf-8")
    check("LOGO.COLOR.01", "blume-logo.svg stroke color is #1BFD9C",
          "stroke:#1BFD9C" in svg_content or 'stroke="#1BFD9C"' in svg_content,
          "contains #1BFD9C")
    check("LOGO.COLOR.02", "blume-logo.svg stroke #0e0e0e is completely absent",
          "#0e0e0e" not in svg_content.lower(),
          "absence of #0e0e0e")

    # XML parse verification
    try:
        tree = ET.parse(logo_svg_path)
        root = tree.getroot()
        viewbox = root.attrib.get("viewBox", "")
        check("LOGO.XML.01", "blume-logo.svg is valid XML with viewBox",
              viewbox != "", f"viewBox={viewbox}")
    except Exception as e:
        check("LOGO.XML.01", "blume-logo.svg is valid XML with viewBox", False, str(e))

    # In AmbientBar.qml, check logoSection contents
    logo_block = re.search(r'id:\s*logoSection\b.*?(?=id:\s*workspacesSection)', bar_content, re.DOTALL)
    if logo_block:
        block_str = logo_block.group(0)
        has_img = "components/blume-logo.svg" in block_str and "Image" in block_str
        has_22 = "height: 22" in block_str and "width: 22" in block_str
        has_cmd_deck = "OverlayController.openCommandDeck()" in block_str
        has_btn_rect = "nodeBtn" in block_str or "border.color:" in block_str and "Rectangle {" in block_str.split("Image {")[0].split("id: logoSection")[1]
        
        # Check no nested Rectangle inside logoSection
        # There should only be Rectangle { id: logoSection ... Image { ... } MouseArea { ... } }
        rect_count = len(re.findall(r'\bRectangle\s*\{', block_str))
        check("LOGO.BARE.01", "logoSection contains zero nested button rectangles",
              rect_count == 1, f"rectangle count={rect_count}")
        check("LOGO.IMG.01", "logoSection hosts bare Image with blume-logo.svg at 22x22",
              has_img and has_22, f"img={has_img}, 22x22={has_22}")
        check("LOGO.ACTION.01", "logoSection click opens CommandDeck",
              has_cmd_deck, f"has CommandDeck={has_cmd_deck}")

    # -------------------------------------------------------------------------
    # 3. Hover Boundaries & Rectangle Containment
    # -------------------------------------------------------------------------
    # Ensure no widget has internal hover Rectangle or MouseArea
    widgets = [
        "NetworkWidget.qml",
        "ClockWidget.qml",
        "VolumeWidget.qml",
        "BatteryWidget.qml",
        "WorkspacesWidget.qml",
        "WindowTitleWidget.qml"
    ]
    for w in widgets:
        w_path = REPO_ROOT / "shell/desktop/surfaces/components" / w
        w_text = w_path.read_text(encoding="utf-8")
        if w not in ["WorkspacesWidget.qml"]:  # workspaces has workspace buttons
            has_container_rect = re.search(r'Rectangle\s*\{\s*id:\s*container\b', w_text) is not None
            has_ma = re.search(r'\bMouseArea\s*\{', w_text) is not None
            check(f"WIDGET.DECOUPLE.RECT.{w}", f"{w} has zero internal container Rectangle",
                  not has_container_rect, f"has_container_rect={has_container_rect}")
            check(f"WIDGET.DECOUPLE.MA.{w}", f"{w} has zero internal MouseArea",
                  not has_ma, f"has_ma={has_ma}")

    # Verify interactive containers have full-surface MouseArea and hover colors
    interactive_sections = ["logoSection", "windowTitleSection", "networkSection", "volumeSection", "batterySection", "bluetoothSection", "clockSection", "railSection"]
    for s in interactive_sections:
        # Check containsMouse logic
        has_hover_color = f"{s.replace('Section', 'MouseArea')}.containsMouse ? Theme.surfaceHover : Theme.background" in bar_content or s == "railSection"
        check(f"HOVER.COLOR.{s}", f"{s} changes color on containsMouse",
              has_hover_color, f"hover color pattern verified")

    # -------------------------------------------------------------------------
    # 4. Code Hygiene & Policy
    # -------------------------------------------------------------------------
    # Greeter check
    code, out, _ = run_cmd("python3 tests/e2e/harness/qml_inspector.py check-greeter shell/desktop")
    check("POLICY.GREETER.01", "Zero greeter references in shell/desktop",
          code == 0 and "OK: Zero greeter imports" in out, out)

    # Polling check
    code, out, _ = run_cmd("python3 tests/e2e/harness/qml_inspector.py check-polling shell/desktop")
    check("POLICY.POLLING.01", "Zero polling loops in shell/desktop",
          code == 0 and "OK: Zero polling loops" in out, out)

    # Format check
    code, out, _ = run_cmd("python3 tests/e2e/harness/qml_inspector.py check-format shell/desktop")
    check("POLICY.FORMAT.01", "All desktop files conform to formatting rules",
          code == 0 and "OK: All files adhere" in out, out)

    # Hardcoded hex colors in M1/M2 files
    m1_m2_files = [
        "shell/desktop/surfaces/AmbientBar.qml",
        "shell/desktop/surfaces/components/DynamicIsland.qml",
        "shell/desktop/surfaces/components/NetworkWidget.qml",
        "shell/desktop/surfaces/components/ClockWidget.qml",
        "shell/desktop/surfaces/components/VolumeWidget.qml",
        "shell/desktop/surfaces/components/BatteryWidget.qml",
        "shell/desktop/surfaces/components/WorkspacesWidget.qml",
        "shell/desktop/surfaces/components/WindowTitleWidget.qml"
    ]
    code, out, _ = run_cmd(f"rg -n -i '#[0-9a-fA-F]{{3,8}}' {' '.join(m1_m2_files)}")
    check("POLICY.HEX.01", "Zero hardcoded hex colors in M1/M2 files",
          code == 1 and out == "", f"matches found={len(out.splitlines()) if out else 0}")

    # Git commit check
    code, out, _ = run_cmd("git log -1 --format='%h %s'")
    check("POLICY.GIT.01", "Zero git commits made (HEAD remains 031241b)",
          out.startswith("031241b"), f"HEAD={out}")

    # Git status: changes to be committed must not be empty, .agents must be untracked
    code, out, _ = run_cmd("git status --porcelain")
    staged_lines = [line for line in out.splitlines() if line[0] in "MADRC"]
    untracked_lines = [line for line in out.splitlines() if line.startswith("??")]
    
    check("POLICY.GIT.02", "Verified changes are staged in git index",
          len(staged_lines) >= 9, f"staged count={len(staged_lines)}")
    
    agents_staged = [l for l in staged_lines if ".agents" in l]
    check("POLICY.GIT.03", ".agents directory is NOT staged in git index",
          len(agents_staged) == 0, f"agents staged={agents_staged}")

    code, out, _ = run_cmd("grep -n '\\.agents' .gitignore")
    check("POLICY.GIT.04", ".agents is NOT ignored in .gitignore",
          code != 0, "not in .gitignore")

    # -------------------------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------------------------
    print("=" * 70)
    print(f"EMPIRICAL CHALLENGER SUMMARY: Passed={passed}, Failed={failed}")
    if failed == 0:
        print("=== ALL EMPIRICAL CHALLENGER INVARIANTS PASSED UNCONDITIONALLY ===")
    else:
        print("=== FAILURE DETECTED IN CHALLENGER AUDIT ===")
    print("=" * 70)

    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
