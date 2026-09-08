#!/usr/bin/env bash
# ==============================================================================
# Tier 1 - Feature 5: Compositor / Hyprland Adapter
# Source: ORIGINAL_REQUEST §R2, architecture.md, PROJECT.md
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

COMPOSITOR_SVC="${PROJECT_ROOT}/shell/desktop/services/CompositorService.qml"
HYPRLAND_ADAPTER="${PROJECT_ROOT}/shell/desktop/adapters/hyprland/HyprlandAdapter.qml"

test_case "T1.05.1" "Compositor Adapter: CompositorService.qml interface exists"
assert_file_exists "${COMPOSITOR_SVC}" "CompositorService.qml must exist in desktop/services/"

test_case "T1.05.2" "Compositor Adapter: HyprlandAdapter.qml exists in desktop/adapters/hyprland/"
assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml must exist in desktop/adapters/hyprland/"

test_case "T1.05.3" "Compositor Adapter: Exposes workspaces model and focusedWorkspaceId"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    check_qml_property "${HYPRLAND_ADAPTER}" "workspaces" || \
    assert_grep "workspaces" "${HYPRLAND_ADAPTER}" "workspaces property must be declared"
    check_qml_property "${HYPRLAND_ADAPTER}" "focusedWorkspaceId" || \
    assert_grep "focusedWorkspaceId" "${HYPRLAND_ADAPTER}" "focusedWorkspaceId property must be declared"
else
    assert_file_exists "${HYPRLAND_ADAPTER}"
fi

test_case "T1.05.4" "Compositor Adapter: Exposes switchToWorkspace(int id) operation"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    check_qml_method "${HYPRLAND_ADAPTER}" "switchToWorkspace" || \
    assert_grep "switchToWorkspace" "${HYPRLAND_ADAPTER}" "switchToWorkspace method must be declared"
else
    assert_file_exists "${HYPRLAND_ADAPTER}"
fi

test_case "T1.05.5" "Compositor Adapter: Uses Quickshell.Hyprland integration natively"
if [[ -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_grep "(Quickshell\.Hyprland|HyprlandFocus|HyprlandWorkspaces)" "${HYPRLAND_ADAPTER}" "HyprlandAdapter must use Quickshell.Hyprland native integration"
else
    assert_file_exists "${HYPRLAND_ADAPTER}"
fi

report_summary
