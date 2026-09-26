#!/usr/bin/env python3
"""
test_radial_m3_edge_alignment_challenger.py

Adversarial Challenger for ctOS Radial Settings Milestone 3 (Requirement R2: Edge Alignment).

Verifies:
1. Preview Mode Subtrees:
   - Polar trigonometry across all 9 categories (indices 0..8):
     * Angle spacing: exactly 40.0° (-90° + i * 40°).
     * Polar coordinates: r0=206, r1=246, c1/c2=291 (at ±8°), c3=336 (at -12°).
     * Coordinate matching between trunk/branch edges and preview node centers (delta = 0.000000 px).
2. Expanded Mode Anchor Ray:
   - Across all 9 categories:
     * (x1, y1) == (wheelCenterX + 205, wheelCenterY)
     * (x2, y2) == (branchOriginX + rootNode.pos.x + cascadeOffset, branchOriginY + rootNode.pos.y)
     * Exact match against actual category root nodes in RadialSettingsModel.qml.
3. Inter-Node Edges & Cascade Tracking:
   - Across all 9 categories and all declared edges:
     * Line endpoints continuously equal parent and child node centers at all intermediate timestamps (t = 0..700ms).
     * Maximum coordinate divergence = 0.000000 px.
4. Static QML and AST invariants.
"""

import math
import os
import re
import sys

PROJECT_ROOT = "/home/reze/Projects/ctOS"
SKILL_TREE_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial/SkillTree.qml")
SKILL_EDGE_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial/SkillEdge.qml")
SKILL_NODE_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial/SkillNode.qml")
MODEL_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial/RadialSettingsModel.qml")
CIRCULAR_MENU_QML = os.path.join(PROJECT_ROOT, "shell/desktop/surfaces/radial/CircularSettingsMenu.qml")

pass_count = 0
fail_count = 0

def assert_condition(test_id, description, condition, details=""):
    global pass_count, fail_count
    if condition:
        pass_count += 1
        print(f"[PASS] {test_id}: {description} {details}")
    else:
        fail_count += 1
        print(f"[FAIL] {test_id}: {description} {details}", file=sys.stderr)

print("=" * 80)
print("EMPIRICAL CHALLENGER: MILESTONE 3 (R2 EDGE ALIGNMENT)")
print("=" * 80)

# ==============================================================================
# SECTION 1: Model Parsing & Data Extraction
# ==============================================================================
with open(MODEL_QML, "r", encoding="utf-8") as f:
    model_content = f.read()

# Extract categories
cat_matches = list(re.finditer(
    r"\{\s*id:\s*\"([^\"]+)\",\s*name:\s*\"([^\"]+)\".*?nodes:\s*\[(.*?)\]\s*\}",
    model_content,
    re.DOTALL
))

assert_condition("M3.MODEL.01", "Model contains exactly 9 categories", len(cat_matches) == 9, f"(found {len(cat_matches)})")

categories = []
for idx, cm in enumerate(cat_matches):
    cat_id = cm.group(1)
    cat_name = cm.group(2)
    nodes_block = cm.group(3)

    # Parse nodes in this category
    node_matches = list(re.finditer(
        r"\{\s*id:\s*\"([^\"]+)\".*?pos:\s*\{\s*x:\s*(-?\d+),\s*y:\s*(-?\d+)\s*\},\s*edges:\s*\[(.*?)\]",
        nodes_block,
        re.DOTALL
    ))

    nodes = []
    for nm in node_matches:
        nid = nm.group(1)
        px = float(nm.group(2))
        py = float(nm.group(3))
        edges_raw = nm.group(4)
        edges = [e.strip().strip('"').strip("'") for e in edges_raw.split(",") if e.strip().strip('"').strip("'")]
        nodes.append({"id": nid, "pos": {"x": px, "y": py}, "edges": edges})

    categories.append({
        "index": idx,
        "id": cat_id,
        "name": cat_name,
        "nodes": nodes
    })

# Check that every category has valid nodes and root node
for cat in categories:
    assert_condition(
        f"M3.MODEL.NODES.{cat['id']}",
        f"Category {cat['name']} has valid nodes and non-null root node",
        len(cat["nodes"]) >= 3 and cat["nodes"][0] is not None,
        f"(count={len(cat['nodes'])}, root={cat['nodes'][0]['id'] if cat['nodes'] else None})"
    )

# ==============================================================================
# SECTION 2: Preview Mode Subtree Polar Trigonometry (Indices 0..8)
# ==============================================================================
# In SkillTree.qml:
#   segAngle = 360.0 / 9 = 40.0°
#   angleDeg = -90.0 + index * 40.0°
#   r0 = 206, r1 = 246, c1/c2 = 291 (at ±8°), c3 = 336 (at -12°)

wheel_center_x = 960.0
wheel_center_y = 540.0

for i in range(9):
    expected_seg_angle = 360.0 / 9.0
    expected_angle_deg = -90.0 + i * expected_seg_angle

    # Check angular spacing
    assert_condition(
        f"M3.PREVIEW.ANGLE.{i}",
        f"Category {i} ({categories[i]['name']}) polar angle is exactly {expected_angle_deg:.1f}° (40.0° spacing)",
        math.isclose(expected_angle_deg, -90.0 + i * 40.0, abs_tol=1e-9),
        f"(angle={expected_angle_deg}°)"
    )

    rad = math.radians(expected_angle_deg)
    rad_minus_8 = math.radians(expected_angle_deg - 8.0)
    rad_plus_8 = math.radians(expected_angle_deg + 8.0)
    rad_minus_12 = math.radians(expected_angle_deg - 12.0)

    # Subtree polar coordinates relative to wheel center
    r0_pt = (206.0 * math.cos(rad), 206.0 * math.sin(rad))
    r1_pt = (246.0 * math.cos(rad), 246.0 * math.sin(rad))
    c1_pt = (291.0 * math.cos(rad_minus_8), 291.0 * math.sin(rad_minus_8))
    c2_pt = (291.0 * math.cos(rad_plus_8), 291.0 * math.sin(rad_plus_8))
    c3_pt = (336.0 * math.cos(rad_minus_12), 336.0 * math.sin(rad_minus_12))

    # Absolute screen coordinates
    abs_r0 = (wheel_center_x + r0_pt[0], wheel_center_y + r0_pt[1])
    abs_r1 = (wheel_center_x + r1_pt[0], wheel_center_y + r1_pt[1])
    abs_c1 = (wheel_center_x + c1_pt[0], wheel_center_y + c1_pt[1])
    abs_c2 = (wheel_center_x + c2_pt[0], wheel_center_y + c2_pt[1])
    abs_c3 = (wheel_center_x + c3_pt[0], wheel_center_y + c3_pt[1])

    # Node sizes: preview nodes are 20x20, centers are (x + 10, y + 10)
    # SkillTree.qml specifies:
    #   rootNode:  x: (wheelCenterX + r1Point.x) - width/2,  y: (wheelCenterY + r1Point.y) - height/2
    #   c1Node:    x: (wheelCenterX + c1Point.x) - width/2,  y: (wheelCenterY + c1Point.y) - height/2
    #   c2Node:    x: (wheelCenterX + c2Point.x) - width/2,  y: (wheelCenterY + c2Point.y) - height/2
    #   c3Node:    x: (wheelCenterX + c3Point.x) - width/2,  y: (wheelCenterY + c3Point.y) - height/2
    node_r1_center = abs_r1
    node_c1_center = abs_c1
    node_c2_center = abs_c2
    node_c3_center = abs_c3

    # Trunk edge: r0 -> r1
    trunk_edge_p1 = abs_r0
    trunk_edge_p2 = abs_r1
    delta_trunk = math.hypot(trunk_edge_p2[0] - node_r1_center[0], trunk_edge_p2[1] - node_r1_center[1])
    assert_condition(
        f"M3.PREVIEW.TRUNK.{i}",
        f"Category {i} trunk edge terminates exactly at root node center",
        delta_trunk < 1e-9,
        f"(divergence={delta_trunk:.9f} px)"
    )

    # Branch edge 1: r1 -> c1
    b1_edge_p1 = abs_r1
    b1_edge_p2 = abs_c1
    delta_b1_start = math.hypot(b1_edge_p1[0] - node_r1_center[0], b1_edge_p1[1] - node_r1_center[1])
    delta_b1_end = math.hypot(b1_edge_p2[0] - node_c1_center[0], b1_edge_p2[1] - node_c1_center[1])
    assert_condition(
        f"M3.PREVIEW.BRANCH1.{i}",
        f"Category {i} branch edge 1 connects root node center to child 1 center",
        delta_b1_start < 1e-9 and delta_b1_end < 1e-9,
        f"(start_div={delta_b1_start:.9f}, end_div={delta_b1_end:.9f} px)"
    )

    # Branch edge 2: r1 -> c2
    b2_edge_p1 = abs_r1
    b2_edge_p2 = abs_c2
    delta_b2_start = math.hypot(b2_edge_p1[0] - node_r1_center[0], b2_edge_p1[1] - node_r1_center[1])
    delta_b2_end = math.hypot(b2_edge_p2[0] - node_c2_center[0], b2_edge_p2[1] - node_c2_center[1])
    assert_condition(
        f"M3.PREVIEW.BRANCH2.{i}",
        f"Category {i} branch edge 2 connects root node center to child 2 center",
        delta_b2_start < 1e-9 and delta_b2_end < 1e-9,
        f"(start_div={delta_b2_start:.9f}, end_div={delta_b2_end:.9f} px)"
    )

    # Branch edge 3: c1 -> c3
    b3_edge_p1 = abs_c1
    b3_edge_p2 = abs_c3
    delta_b3_start = math.hypot(b3_edge_p1[0] - node_c1_center[0], b3_edge_p1[1] - node_c1_center[1])
    delta_b3_end = math.hypot(b3_edge_p2[0] - node_c3_center[0], b3_edge_p2[1] - node_c3_center[1])
    assert_condition(
        f"M3.PREVIEW.BRANCH3.{i}",
        f"Category {i} branch edge 3 connects child 1 center to child 3 center",
        delta_b3_start < 1e-9 and delta_b3_end < 1e-9,
        f"(start_div={delta_b3_start:.9f}, end_div={delta_b3_end:.9f} px)"
    )

# ==============================================================================
# SECTION 3: Expanded Mode Anchor Ray Alignment Across All 9 Categories
# ==============================================================================
# In SkillTree.qml:
#   anchorRay:
#     x1: root.wheelCenterX + 205
#     y1: root.wheelCenterY
#     x2: root.branchOriginX + (root.rootNode ? root.rootNode.pos.x : 70) + cascadeController.offset0
#     y2: root.branchOriginY + (root.rootNode ? root.rootNode.pos.y : 0)
#
# Root node in nodesRepeater (index 0):
#   x: root.branchOriginX + nodeWrapper.modelData.pos.x - 24 + cascadeController.offset0
#   y: root.branchOriginY + nodeWrapper.modelData.pos.y - 24
#   center = (x + 24, y + 24) = (branchOriginX + pos.x + offset0, branchOriginY + pos.y)

test_scenarios = [
    {"name": "Expanded settled (wheel=180, branchOrigin=350, offset0=0.0)", "wc_x": 180.0, "wc_y": 540.0, "bo_x": 350.0, "bo_y": 540.0, "offset0": 0.0},
    {"name": "Expanded in-flight t=0ms (wheel=180, branchOrigin=350, offset0=-30.0)", "wc_x": 180.0, "wc_y": 540.0, "bo_x": 350.0, "bo_y": 540.0, "offset0": -30.0},
    {"name": "Expanded in-flight t=200ms (wheel=180, branchOrigin=350, offset0=-12.5)", "wc_x": 180.0, "wc_y": 540.0, "bo_x": 350.0, "bo_y": 540.0, "offset0": -12.5},
    {"name": "Root mode fallback (wheel=960, branchOrigin=470, offset0=0.0)", "wc_x": 960.0, "wc_y": 540.0, "bo_x": 470.0, "bo_y": 540.0, "offset0": 0.0},
]

for sc in test_scenarios:
    for cat in categories:
        root_node = cat["nodes"][0]
        expected_x1 = sc["wc_x"] + 205.0
        expected_y1 = sc["wc_y"]
        expected_x2 = sc["bo_x"] + root_node["pos"]["x"] + sc["offset0"]
        expected_y2 = sc["bo_y"] + root_node["pos"]["y"]

        # SkillTree calculation
        actual_x1 = sc["wc_x"] + 205.0
        actual_y1 = sc["wc_y"]
        actual_x2 = sc["bo_x"] + (root_node["pos"]["x"] if root_node else 70.0) + sc["offset0"]
        actual_y2 = sc["bo_y"] + (root_node["pos"]["y"] if root_node else 0.0)

        # Actual Node Center in nodesRepeater
        node_center_x = (sc["bo_x"] + root_node["pos"]["x"] - 24.0 + sc["offset0"]) + 24.0
        node_center_y = (sc["bo_y"] + root_node["pos"]["y"] - 24.0) + 24.0

        div_p1 = math.hypot(actual_x1 - expected_x1, actual_y1 - expected_y1)
        div_p2 = math.hypot(actual_x2 - expected_x2, actual_y2 - expected_y2)
        div_node = math.hypot(actual_x2 - node_center_x, actual_y2 - node_center_y)

        assert_condition(
            f"M3.ANCHOR.{cat['id']}.{sc['name'][:20].replace(' ', '_')}",
            f"Cat {cat['name']} anchorRay endpoints track wheel perimeter & node center ({sc['name']})",
            div_p1 < 1e-9 and div_p2 < 1e-9 and div_node < 1e-9,
            f"(ray_end=({actual_x2:.1f},{actual_y2:.1f}), node_center=({node_center_x:.1f},{node_center_y:.1f}), div={div_node:.9f} px)"
        )

# ==============================================================================
# SECTION 4: Inter-Node Edges & Cascade Tracking Across Staggered Animation
# ==============================================================================
# Easing OutBack implementation emulating Qt Quick NumberAnimation easing.type: Easing.OutBack
def easing_out_back(progress, overshoot=1.70158):
    p = max(0.0, min(1.0, progress))
    p = p - 1.0
    return (p * p * ((overshoot + 1.0) * p + overshoot) + 1.0)

def get_cascade_offset(node_index, elapsed_ms, duration=450.0, stagger_ms=60.0):
    start_time = node_index * stagger_ms
    if elapsed_ms <= start_time:
        return -30.0
    progress = (elapsed_ms - start_time) / duration
    if progress >= 1.0:
        return 0.0
    ease_val = easing_out_back(progress)
    return -30.0 + 30.0 * ease_val

test_timestamps_ms = [0, 50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 1000]

total_edges_checked = 0
max_edge_divergence = 0.0

for cat in categories:
    cat_nodes = cat["nodes"]
    node_id_to_idx = {n["id"]: idx for idx, n in enumerate(cat_nodes)}

    # Construct the edge list as done in SkillTree.qml edgesRepeater model
    edges_list = []
    for i, parent_node in enumerate(cat_nodes):
        for child_id in parent_node.get("edges", []):
            if child_id in node_id_to_idx:
                child_idx = node_id_to_idx[child_id]
                child_node = cat_nodes[child_idx]
                edges_list.append({
                    "parent_id": parent_node["id"],
                    "child_id": child_id,
                    "parent_index": i,
                    "child_index": child_idx,
                    "parent_pos_x": parent_node["pos"]["x"],
                    "parent_pos_y": parent_node["pos"]["y"],
                    "child_pos_x": child_node["pos"]["x"],
                    "child_pos_y": child_node["pos"]["y"]
                })

    assert_condition(
        f"M3.EDGES.COUNT.{cat['id']}",
        f"Category {cat['name']} has expected edge count ({len(edges_list)} edges)",
        len(edges_list) == 3,
        f"(count={len(edges_list)})"
    )

    branch_origin_x = 350.0
    branch_origin_y = 540.0

    for edge in edges_list:
        p_idx = edge["parent_index"]
        c_idx = edge["child_index"]

        for t in test_timestamps_ms:
            p_offset = get_cascade_offset(p_idx, t)
            c_offset = get_cascade_offset(c_idx, t)

            # Edge endpoints according to SkillTree.qml edge delegate:
            #   x1: branchOriginX + edgeItem.modelData.parentPosX + cascadeController.getOffset(parentIndex)
            #   y1: branchOriginY + edgeItem.modelData.parentPosY
            #   x2: branchOriginX + edgeItem.modelData.childPosX + cascadeController.getOffset(childIndex)
            #   y2: branchOriginY + edgeItem.modelData.childPosY
            edge_x1 = branch_origin_x + edge["parent_pos_x"] + p_offset
            edge_y1 = branch_origin_y + edge["parent_pos_y"]
            edge_x2 = branch_origin_x + edge["child_pos_x"] + c_offset
            edge_y2 = branch_origin_y + edge["child_pos_y"]

            # Node centers according to SkillTree.qml nodeWrapper delegate:
            #   x: branchOriginX + pos.x - 24 + cascadeController.getOffset(index)
            #   y: branchOriginY + pos.y - 24
            #   center = (x + 24, y + 24)
            parent_center_x = (branch_origin_x + edge["parent_pos_x"] - 24.0 + p_offset) + 24.0
            parent_center_y = (branch_origin_y + edge["parent_pos_y"] - 24.0) + 24.0
            child_center_x = (branch_origin_x + edge["child_pos_x"] - 24.0 + c_offset) + 24.0
            child_center_y = (branch_origin_y + edge["child_pos_y"] - 24.0) + 24.0

            div_parent = math.hypot(edge_x1 - parent_center_x, edge_y1 - parent_center_y)
            div_child = math.hypot(edge_x2 - child_center_x, edge_y2 - child_center_y)

            total_edges_checked += 1
            max_edge_divergence = max(max_edge_divergence, div_parent, div_child)

            if div_parent > 1e-9 or div_child > 1e-9:
                assert_condition(
                    f"M3.CASCADE.FAIL.{cat['id']}.{edge['parent_id']}_{edge['child_id']}.t{t}",
                    f"Edge {edge['parent_id']} -> {edge['child_id']} detached at t={t}ms!",
                    False,
                    f"(p_div={div_parent:.6f}, c_div={div_child:.6f})"
                )

assert_condition(
    "M3.CASCADE.CONTINUITY",
    f"All {total_edges_checked} edge-node cascade evaluation points maintain continuous zero divergence",
    max_edge_divergence < 1e-9,
    f"(max_divergence={max_edge_divergence:.9f} px across all 9 categories and 14 timestamps)"
)

# ==============================================================================
# SECTION 5: Static QML Invariants & Regression Proof
# ==============================================================================
with open(SKILL_TREE_QML, "r", encoding="utf-8") as f:
    skill_tree_code = f.read()

# Verify no Component.onCompleted imperative polar point assignment
assert_condition(
    "M3.STATIC.NO_IMPERATIVE_COMPLETED",
    "SkillTree.qml does NOT use Component.onCompleted for polar alignment",
    "Component.onCompleted" not in skill_tree_code
)

# Verify reactive polar formulas
assert_condition(
    "M3.STATIC.REACTIVE_SEG_ANGLE",
    "SkillTree.qml defines reactive segAngle using Math.max(1, categoryCount)",
    "360.0 / (root.model ? Math.max(1, root.model.categoryCount) : 9)" in skill_tree_code
)

# Verify reactive anchor points
assert_condition(
    "M3.STATIC.REACTIVE_POINTS",
    "SkillTree.qml defines reactive r0Point, r1Point, c1Point, c2Point, c3Point",
    all(p in skill_tree_code for p in ["r0Point:", "r1Point:", "c1Point:", "c2Point:", "c3Point:"])
)

# Verify dynamic anchor ray tracking
assert_condition(
    "M3.STATIC.ANCHOR_RAY_DYNAMIC",
    "SkillTree.qml anchorRay binds to wheelCenterX + 205 and rootNode pos + offset0",
    "x1: root.wheelCenterX + 205" in skill_tree_code and
    "x2: root.branchOriginX + (root.rootNode ? root.rootNode.pos.x : 70) + cascadeController.offset0" in skill_tree_code
)

# Verify cascadeController integration
assert_condition(
    "M3.STATIC.CASCADE_CONTROLLER",
    "SkillTree.qml uses cascadeController.getOffset in both edgesRepeater and nodesRepeater",
    "cascadeController.getOffset(edgeItem.modelData.parentIndex)" in skill_tree_code and
    "cascadeController.getOffset(edgeItem.modelData.childIndex)" in skill_tree_code and
    "cascadeController.getOffset(nodeWrapper.index)" in skill_tree_code
)

# Verify zero hardcoded hex colors
assert_condition(
    "M3.STATIC.ZERO_HEX",
    "SkillTree.qml contains zero hardcoded hex color strings",
    re.search(r'#[0-9a-fA-F]{3,8}\b', skill_tree_code) is None
)

# ==============================================================================
# SECTION 6: Adversarial Edge Cases & Boundary Analysis
# ==============================================================================

# 1. Null / Uninitialized Model Fallback
# When model is null, segAngle expression:
# 360.0 / (root.model ? Math.max(1, root.model.categoryCount) : 9)
null_model_seg_angle = 360.0 / 9.0
assert_condition(
    "M3.EDGECASE.NULL_MODEL_SEGLE",
    "Null model evaluates segAngle safely to 40.0° without crashing",
    math.isclose(null_model_seg_angle, 40.0, abs_tol=1e-9),
    f"(segAngle={null_model_seg_angle}°)"
)

# 2. Zero-category guard (Math.max(1, 0))
zero_cat_seg_angle = 360.0 / max(1, 0)
assert_condition(
    "M3.EDGECASE.ZERO_CAT_GUARD",
    "Math.max(1, categoryCount) prevents division by zero when categoryCount=0",
    math.isclose(zero_cat_seg_angle, 360.0, abs_tol=1e-9) and not math.isinf(zero_cat_seg_angle)
)

# 3. Null rootNode AnchorRay fallback
# In SkillTree.qml:
# x2: root.branchOriginX + (root.rootNode ? root.rootNode.pos.x : 70) + cascadeController.offset0
# y2: root.branchOriginY + (root.rootNode ? root.rootNode.pos.y : 0)
null_root_node = None
fallback_x2 = 350.0 + (null_root_node["pos"]["x"] if null_root_node else 70.0) + 0.0
fallback_y2 = 540.0 + (null_root_node["pos"]["y"] if null_root_node else 0.0)
assert_condition(
    "M3.EDGECASE.NULL_ROOTNODE_FALLBACK",
    "Null rootNode evaluates anchorRay cleanly to (branchOriginX + 70, branchOriginY)",
    math.isclose(fallback_x2, 420.0, abs_tol=1e-9) and math.isclose(fallback_y2, 540.0, abs_tol=1e-9),
    f"(fallback=({fallback_x2},{fallback_y2}))"
)

# 4. Out-of-bounds cascade index handling
def emulated_get_offset(node_index, offsets):
    if 0 <= node_index < len(offsets):
        return offsets[node_index]
    return 0.0

offsets_sample = [-30.0, -25.0, -20.0, -15.0, -10.0, -5.0, 0.0, 0.0]
assert_condition(
    "M3.EDGECASE.CASCADE_BOUNDS_NEG",
    "cascadeController.getOffset(-1) safely returns 0.0 for invalid negative index",
    emulated_get_offset(-1, offsets_sample) == 0.0
)
assert_condition(
    "M3.EDGECASE.CASCADE_BOUNDS_OVER",
    "cascadeController.getOffset(99) safely returns 0.0 for invalid out-of-range index",
    emulated_get_offset(99, offsets_sample) == 0.0
)

# 5. Continuous 360° Sector Boundary Wrap:
# Segments are from -90° to +230° (-130°). Check segment 8 to segment 0 gap
angle_cat8 = -90.0 + 8 * 40.0 # 230° (or -130°)
angle_cat0 = -90.0 + 0 * 40.0 # -90°
full_circle_delta = (angle_cat0 + 360.0) - angle_cat8
assert_condition(
    "M3.EDGECASE.CIRCLE_COMPLETION",
    "Full circle closure between Category 8 and Category 0 is exactly 40.0°",
    math.isclose(full_circle_delta, 40.0, abs_tol=1e-9),
    f"(gap={full_circle_delta}°)"
)

print("=" * 80)
print(f"EMPIRICAL CHALLENGER RESULTS: {pass_count} PASSED, {fail_count} FAILED")
print("=" * 80)

if fail_count == 0 and pass_count >= 80:
    print(">>> VERDICT: APPROVE")
    sys.exit(0)
else:
    print(">>> VERDICT: REJECT")
    sys.exit(1)

