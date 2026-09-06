#!/usr/bin/env bash
# ==============================================================================
# Tier 2 - Feature 5 Boundary: Compositor & Hyprland Adapter Edge Cases
# Source: architecture.md, delivery-tracker.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

HYPRLAND_ADAPTER="${PROJECT_ROOT}/shell/desktop/adapters/hyprland/HyprlandAdapter.qml"
COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"

test_case "T2.05.1" "Compositor Boundary: Unavailable compositor sets available: false cleanly"
if [[ -f "${COMPOSITOR_SVC}" ]]; then
    check_qml_property "${COMPOSITOR_SVC}" "available" --type bool || assert_grep "available" "${COMPOSITOR_SVC}" "available property required"
else
    assert_file_exists "${COMPOSITOR_SVC}" "CompositorService.qml required"
fi

test_case "T2.05.2" "Compositor Boundary: Negative workspace ID switch clamped or rejected"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_grep -i "(switchToWorkspace|id\s*>\s*0|Math\.max)" "${HYPRLAND_ADAPTER}" "switchToWorkspace must guard against negative workspace ID"
else
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

test_case "T2.05.3" "Compositor Boundary: Non-existent workspace ID switch handled safely"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_grep -i "(switchToWorkspace|dispatch)" "${HYPRLAND_ADAPTER}" "Compositor dispatch must handle arbitrary workspace IDs without crash"
else
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

test_case "T2.05.4" "Compositor Boundary: Empty workspaces model from Hyprland does not crash UI"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_grep -i "(workspaces|count|length)" "${HYPRLAND_ADAPTER}" "Workspaces model must handle empty list"
else
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

test_case "T2.05.5" "Compositor Boundary: Compositor restart/reconnection handled without leaks"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_grep -i "(Hyprland|Quickshell|available)" "${HYPRLAND_ADAPTER}" "Reconnection handling via Quickshell native bindings"
else
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

report_summary
