# Radial Skill Tree UI - Hardcoded Offsets Analysis

This document provides a comprehensive analysis of the hardcoded screen offsets and sizing within the Radial Skill Tree UI and their potential impact on functionality and layout across different screen resolutions.

## Findings

### 1. Hardcoded Radial Wheel Hitboxes & Dimensions
- **File:** [`CircularSettingsMenu.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/CircularSettingsMenu.qml#L17-L19)
  - `baseDiameter: 420` and `outerRadius: 210` are defined as absolute values. 
- **File:** [`RadialSettings.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/RadialSettings.qml#L397-L400)
  - The surface-wide `MouseArea` relies on strict absolute radius limits: `distFromCenter < 170` triggers expansion and `distFromCenter > 280` triggers dismissal.
- **Impact:** Since the radial menu diameter and the click interaction radii are fixed in absolute pixels, they do not scale on smaller displays (e.g., 1280x800) or high-DPI screens. 

### 2. Expanded Branch Origin and Node Overlap
- **File:** [`CircularSettingsMenu.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/CircularSettingsMenu.qml#L20) and [`RadialSettings.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/RadialSettings.qml#L276)
  - `wheelMenu.leftAnchorX` is dynamically calculated as `Math.max(100, width * 0.06)`, establishing a minimum 100px anchor.
  - The tree branch origin is explicitly offset by `branchOriginX: wheelMenu.leftAnchorX + 350`.
- **File:** [`ContextPanel.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/ContextPanel.qml#L30-L36)
  - The right-side context panel scales its width: `Math.min(440, Math.max(340, parent.width * 0.3))`.
- **File:** [`SkillTree.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/SkillTree.qml#L325-L328)
  - Edges and nodes are laid out using fixed model coordinates added directly to `branchOriginX`.
- **Impact:** At smaller resolutions, the fixed `branchOriginX` (minimum 450px) and the responsive `ContextPanel` (e.g., 384px wide at 1280px screen width) leave very limited horizontal space (e.g., ~430px) for the actual skill tree nodes. Any deep tree branches will inevitably overlap the `ContextPanel` or render off-screen since node layouts don't scale or wrap.

### 3. Navigation Controller Interaction Boundaries
- **File:** [`NavigationController.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/shell/desktop/surfaces/radial/NavigationController.qml#L52-L55)
  - The hover zone logic for the skill tree uses: `treeMaxX = Math.max(treeMinX + 100.0, root.surfaceWidth - 480.0)`.
- **Impact:** While `Math.max` prevents `treeMaxX` from crossing `treeMinX`, on narrow screens where `surfaceWidth - 480.0` is small, the hover interaction area could compress to a mere 100px wide strip. Nodes rendering outside this strip will not respond to mouse hover or clicks, breaking spatial interaction.

### 4. Correction on Test Validations
- A prior investigation hypothesized that `test_m2_multimonitor_deep_stress.qml` might validate layout overlaps for the radial skill tree components. 
- **Correction:** Inspection of [`test_m2_multimonitor_deep_stress.qml`](file:///home/reze/.gemini/antigravity/worktrees/ctOS/radial_skill_tree_ui/tests/e2e/harness/test_m2_multimonitor_deep_stress.qml) reveals that it exclusively measures and tests the `AmbientBar` and `DynamicIsland` top bar components to ensure they don't overlap across 2560x1440, 1920x1080, 1366x768, and 1280x800 resolutions. It contains absolutely no stress testing or overlap validation for the Radial Settings or Skill Tree components.

## Remaining Questions & Gaps
- **Model Node Coordinates:** We have verified that `SkillTree.qml` maps node coordinates as `root.branchOriginX + node.pos.x`. However, the actual distribution of `pos.x` values in `RadialSettingsModel.qml` hasn't been mapped to verify the maximum expected horizontal span of the tree.
- **Dynamic Scaling Solution:** What is the best strategy to introduce relative scaling? Implementing a viewBox or scaling transform on the `SkillTree.qml` could fix the overlap, but may require coordination with the hover logic in `NavigationController.qml` to map scaled coordinates back to raw screen coordinates.
- **C++ Component Overrides:** It remains unverified if the underlying C++ `OverlayController` bounds or resizes the surface beyond the QtQuick constraints.
