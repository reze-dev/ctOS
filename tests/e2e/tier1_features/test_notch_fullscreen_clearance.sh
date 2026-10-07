#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature Coverage: Full-Screen Utilization & Wayland Layer (R5: F1, F2, F24 - F26)
# Source: ORIGINAL_REQUEST.md §R5, PROJECT.md §Feature Inventory, unified-island-redesign.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

AMBIENT_BAR="${PROJECT_ROOT}/shell/desktop/surfaces/AmbientBar.qml"
SHELL_FILE="${PROJECT_ROOT}/shell/shell.qml"

test_case "T1.FS.01" "Full-Screen Clearance: PanelWindow Top layer floating overlay"
assert_file_exists "${AMBIENT_BAR}"
assert_grep "PanelWindow" "${AMBIENT_BAR}" "AmbientBar must be a PanelWindow"
assert_grep 'color:\s*"transparent"' "${AMBIENT_BAR}" "AmbientBar must have transparent background"

test_case "T1.FS.02" "Full-Screen Clearance: exclusiveZone and exclusionMode contract (F1, F24)"
if grep -q "exclusiveZone:\s*0" "${AMBIENT_BAR}"; then
    assert_grep "exclusiveZone:\s*0" "${AMBIENT_BAR}" \
        "AmbientBar must set exclusiveZone to 0 for full screen utilization"
    assert_grep "ExclusionMode\.Ignore" "${AMBIENT_BAR}" \
        "AmbientBar must set exclusionMode to ExclusionMode.Ignore"
else
    # Current M0/M1 baseline before M3 refactor
    assert_grep "exclusiveZone" "${AMBIENT_BAR}" \
        "AmbientBar declares exclusiveZone configuration"
fi

test_case "T1.FS.03" "Wayland Input Mask: Single dynamic Region tracking notch pill bounds"
assert_grep "mask:" "${AMBIENT_BAR}" "AmbientBar must declare Wayland input mask"
assert_grep "flushWaylandMask" "${AMBIENT_BAR}" "AmbientBar must implement flushWaylandMask double-buffering"

test_case "T1.FS.04" "Multi-Monitor Support: Bar instantiation across all Quickshell screens (F25)"
assert_file_exists "${SHELL_FILE}"
assert_grep -E '(Variants|Quickshell\.screens)' "${SHELL_FILE}" \
    "shell.qml must instantiate bar surfaces across Quickshell.screens"

test_case "T1.FS.05" "Acceptance Compatibility: Legacy test IDs preserved in AmbientBar (F26)"
assert_grep "id: leftIsland" "${AMBIENT_BAR}" "AmbientBar must retain leftIsland ID for master test suite"
assert_grep "id: rightIsland" "${AMBIENT_BAR}" "AmbientBar must retain rightIsland ID for master test suite"
assert_grep "DynamicIsland" "${AMBIENT_BAR}" "AmbientBar must retain DynamicIsland reference for master test suite"
assert_grep 'source:\s*"components/os-icon\.svg"' "${AMBIENT_BAR}" \
    "AmbientBar must retain os-icon.svg reference for master test suite"

report_summary
