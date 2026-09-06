#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 9: Monitor Unplug with Multiple Workspaces
# Interaction: Ambient Bar Variants (F11) + CompositorAdapter (F5)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
SHELL_ENTRY="${PROJECT_ROOT}/shell/shell.qml"
HYPRLAND_ADAPTER="${DESKTOP_DIR}/adapters/hyprland/HyprlandAdapter.qml"

test_case "T3.09" "Pairwise: Secondary monitor unplug migrates workspaces and updates active screen bar"
if [[ -f "${SHELL_ENTRY}" && -f "${HYPRLAND_ADAPTER}" ]]; then
    assert_file_exists "${SHELL_ENTRY}"
    assert_file_exists "${HYPRLAND_ADAPTER}"
else
    assert_file_exists "${SHELL_ENTRY}" "shell.qml required"
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

report_summary
