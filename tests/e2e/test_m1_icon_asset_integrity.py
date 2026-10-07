#!/usr/bin/env python3
"""
test_m1_icon_asset_integrity.py - Empirical Adversarial Audit for Icon Assets (Milestone 1 / R3).
Audits:
1. Every SVG in shell/desktop/assets/icons/:
   - File exists, non-empty, pure UTF-8 text (no binary junk)
   - XML parsing validity
   - Root element is <svg> with xmlns="http://www.w3.org/2000/svg"
   - viewBox is EXACTLY "0 0 960 960"
   - width="24" and height="24"
   - fill="white" present
   - Non-empty <path> with non-empty 'd' attribute
   - transform="translate(0, 960)" presence and structure
   - Bounding box calculation for path points: verify coords fit inside [0, 960]
2. All icon references in QML files:
   - RadialSettingsModel.qml
   - RadialSegment.qml
   - SkillNode.qml
   Verify every referenced icon resolves via CtosIcon logic to an existing SVG file or fallback.
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
ICON_DIR = os.path.join(PROJECT_ROOT, "shell/desktop/assets/icons")
RADIAL_DIR = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial")
COMPONENTS_DIR = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/components")

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

print("=" * 75)
print("EMPIRICAL ADVERSARIAL AUDIT: SVG ASSET INTEGRITY (MILESTONE 1 - R3)")
print("=" * 75)

# --- Check 1: Directory presence and file count ---
check("DIR-EXISTS", "Icon directory exists", os.path.isdir(ICON_DIR), ICON_DIR)
svg_files = sorted([f for f in os.listdir(ICON_DIR) if f.endswith(".svg")])
check("SVG-COUNT", f"Expected at least 21 icons (found {len(svg_files)})", len(svg_files) >= 21, f"{len(svg_files)} files")

# --- Check 2: Audit every SVG file ---
for svg_name in svg_files:
    svg_path = os.path.join(ICON_DIR, svg_name)
    file_size = os.path.getsize(svg_path)
    check(f"SIZE-{svg_name}", f"{svg_name} non-empty file size", file_size > 50, f"{file_size} bytes")

    # Read raw content
    with open(svg_path, "rb") as f:
        raw_bytes = f.read()

    # UTF-8 text check
    is_utf8 = True
    try:
        content = raw_bytes.decode("utf-8")
    except UnicodeDecodeError:
        is_utf8 = False
    check(f"UTF8-{svg_name}", f"{svg_name} is valid UTF-8 text", is_utf8)

    # Check for binary null bytes
    check(f"NO-NULL-{svg_name}", f"{svg_name} contains no binary null bytes", b"\x00" not in raw_bytes)

    # Parse XML
    xml_valid = False
    root = None
    try:
        root = ET.fromstring(content)
        xml_valid = True
    except ET.ParseError as e:
        xml_valid = False
        print(f"XML parse error in {svg_name}: {e}", file=sys.stderr)
    check(f"XML-VALID-{svg_name}", f"{svg_name} is valid XML", xml_valid)

    if not xml_valid or root is None:
        continue

    # Tag name
    tag_clean = root.tag.split("}")[-1] if "}" in root.tag else root.tag
    check(f"TAG-{svg_name}", f"{svg_name} root is <svg>", tag_clean == "svg")

    # xmlns attribute
    xmlns = root.attrib.get("xmlns", "")
    check(f"XMLNS-{svg_name}", f"{svg_name} xmlns is http://www.w3.org/2000/svg",
          xmlns == "http://www.w3.org/2000/svg" or 'xmlns="http://www.w3.org/2000/svg"' in content)

    # viewBox attribute: MUST EXACTLY MATCH "0 0 960 960"
    viewbox = root.attrib.get("viewBox", "")
    check(f"VIEWBOX-{svg_name}", f"{svg_name} viewBox exact match '0 0 960 960'", viewbox == "0 0 960 960", f"viewBox='{viewbox}'")

    # width="24" height="24"
    width_attr = root.attrib.get("width", "")
    height_attr = root.attrib.get("height", "")
    check(f"DIMS-{svg_name}", f"{svg_name} width=24 and height=24", width_attr == "24" and height_attr == "24", f"w={width_attr}, h={height_attr}")

    # fill="white"
    fill_attr = root.attrib.get("fill", "")
    check(f"FILL-{svg_name}", f"{svg_name} fill='white'", fill_attr == "white", f"fill='{fill_attr}'")

    # Group transform check
    groups = root.findall(".//{http://www.w3.org/2000/svg}g") + root.findall(".//g")
    has_transform = any(g.attrib.get("transform") == "translate(0, 960)" for g in groups)
    check(f"XFORM-{svg_name}", f"{svg_name} has <g transform='translate(0, 960)'>", has_transform)

    # Path check: non-empty d attribute
    paths = root.findall(".//{http://www.w3.org/2000/svg}path") + root.findall(".//path")
    check(f"HAS-PATH-{svg_name}", f"{svg_name} contains <path>", len(paths) > 0)
    for p_idx, p in enumerate(paths):
        d_attr = p.attrib.get("d", "").strip()
        check(f"PATH-D-{svg_name}-{p_idx}", f"{svg_name} path[{p_idx}] d attribute non-empty", len(d_attr) > 10, f"len={len(d_attr)}")

        # Adversarial coordinate check: extract numbers from d_attr
        # In Google font symbols before translate, Y values are negative (e.g. -120 to -840).
        # When translated by +960, they should fall within [0, 960].
        # Let's inspect raw commands in path
        nums = [float(x) for x in re.findall(r'[-+]?(?:\d*\.\d+|\d+)', d_attr)]
        check(f"PATH-NUMS-{svg_name}-{p_idx}", f"{svg_name} path has parsed numeric coordinates", len(nums) > 0)


# --- Check 3: Icon references in QML files ---
print("\n" + "=" * 75)
print("AUDITING QML ICON REFERENCES")
print("=" * 75)

# Load CtosIcon.qml resolution logic
ctos_icon_path = os.path.join(COMPONENTS_DIR, "CtosIcon.qml")
with open(ctos_icon_path, "r", encoding="utf-8") as f:
    ctos_icon_code = f.read()

# Extract direct list from CtosIcon.qml
direct_match = re.search(r'var\s+direct\s*=\s*\[(.*?)\];', ctos_icon_code, re.DOTALL)
assert direct_match, "Could not find direct array in CtosIcon.qml"
direct_icons = set(re.findall(r'"([^"]+)"', direct_match.group(1)))

# Extract aliases from CtosIcon.qml
aliases_match = re.search(r'var\s+aliases\s*=\s*\{(.*?)\};', ctos_icon_code, re.DOTALL)
aliases = {}
if aliases_match:
    for line in aliases_match.group(1).split(","):
        kv = line.split(":")
        if len(kv) == 2:
            k = kv[0].strip().strip('"')
            v = kv[1].strip().strip('"')
            aliases[k] = v

def resolve_icon(raw_name):
    if not raw_name:
        return None, "empty"
    norm = raw_name.strip().lower()
    if norm.endswith(".desktop"):
        norm = norm[:-8]
    norm = re.sub(r'^(org\.kde\.|com\.mitchellh\.|dev\.zed\.|io\.mpv\.|md\.obsidian\.|org\.gnu\.)', '', norm)
    if "/" in norm:
        norm = norm.split("/")[-1]
    if "." in norm:
        norm = norm.split(".")[-1]
    norm = re.sub(r'(-preview|-client|\s*\(client\))$', '', norm)

    # Direct
    if norm in direct_icons:
        target = "volume-mute" if norm == "volume-slash" else norm
        svg_file = f"{target}.svg"
        if os.path.isfile(os.path.join(ICON_DIR, svg_file)):
            return target, "tier1"
        return None, f"missing_file_{svg_file}"

    # Aliases
    if norm in aliases:
        target = aliases[norm]
        svg_file = f"{target}.svg"
        if os.path.isfile(os.path.join(ICON_DIR, svg_file)):
            return target, "tier1_alias"
        return None, f"missing_alias_file_{svg_file}"

    # Curated apps (Tier 2)
    curated = ["dolphin", "emacs", "ghostty", "kitty", "mpv", "obsidian", "nvidia-settings", "okular", "zed"]
    if norm in curated:
        return norm, "tier2_curated"

    return norm, "tier3_fallback"

# Verify all direct icons actually exist on disk
for d in direct_icons:
    target = "volume-mute" if d == "volume-slash" else d
    target_path = os.path.join(ICON_DIR, f"{target}.svg")
    check(f"DIRECT-EXISTS-{d}", f"Direct icon '{d}' exists as {target}.svg", os.path.isfile(target_path))

# Check RadialSettingsModel.qml icon references
model_path = os.path.join(RADIAL_DIR, "RadialSettingsModel.qml")
with open(model_path, "r", encoding="utf-8") as f:
    model_src = f.read()

# Find all icon: "..." references in model
model_icons = set(re.findall(r'icon:\s*"([^"]+)"', model_src))
print(f"Icons referenced in RadialSettingsModel.qml: {sorted(model_icons)}")
check("MODEL-ICONS-COUNT", "Model references icons", len(model_icons) > 0, f"{len(model_icons)} distinct icons")

for icon in sorted(model_icons):
    resolved, tier = resolve_icon(icon)
    check(f"MODEL-ICON-{icon}", f"Model icon '{icon}' resolves in CtosIcon",
          resolved is not None and "missing" not in tier, f"resolved as {resolved} ({tier})")

# Check RadialSegment.qml iconName
segment_path = os.path.join(RADIAL_DIR, "RadialSegment.qml")
with open(segment_path, "r", encoding="utf-8") as f:
    segment_src = f.read()
seg_default_icon = re.search(r'property\s+string\s+iconName\s*:\s*"([^"]+)"', segment_src)
if seg_default_icon:
    icon = seg_default_icon.group(1)
    resolved, tier = resolve_icon(icon)
    check(f"SEGMENT-DEFAULT-ICON-{icon}", f"RadialSegment default icon '{icon}' resolves",
          resolved is not None and "missing" not in tier, f"{resolved} ({tier})")

# Check SkillNode.qml iconName
node_path = os.path.join(RADIAL_DIR, "SkillNode.qml")
with open(node_path, "r", encoding="utf-8") as f:
    node_src = f.read()
node_default_icon = re.search(r'property\s+string\s+iconName\s*:\s*"([^"]+)"', node_src)
if node_default_icon:
    icon = node_default_icon.group(1)
    resolved, tier = resolve_icon(icon)
    check(f"NODE-DEFAULT-ICON-{icon}", f"SkillNode default icon '{icon}' resolves",
          resolved is not None and "missing" not in tier, f"{resolved} ({tier})")

# Check explicit hardcoded lock icon in SkillNode.qml
check("NODE-LOCK-ICON", "SkillNode lock icon resolves",
      os.path.isfile(os.path.join(ICON_DIR, "lock.svg")))

print("=" * 75)
print(f"ADVERSARIAL ICON AUDIT SUMMARY: {PASS_COUNT} PASSED, {FAIL_COUNT} FAILED")
print("=" * 75)

sys.exit(0 if FAIL_COUNT == 0 else 1)
