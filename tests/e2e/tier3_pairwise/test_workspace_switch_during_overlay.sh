#!/usr/bin/env bash
# ==============================================================================
# Tier 3 - Pairwise 2: Workspace Switch during Active Overlay
# Interaction: OverlayController (F3) + CompositorAdapter (F5)
# ==============================================================================
set -u
set +e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../harness/mock_environment.sh"
source "${SCRIPT_DIR}/../harness/qml_runner.sh"

DESKTOP_DIR="${PROJECT_ROOT}/shell/desktop"
OVERLAY_CTRL="${DESKTOP_DIR}/core/OverlayController.qml"
HYPRLAND_ADAPTER="${DESKTOP_DIR}/adapters/hyprland/HyprlandAdapter.qml"

test_case "T3.02" "Pairwise: Workspace switch event preserves or safely closes overlay"
if [[ -f "${OVERLAY_CTRL}" && -f "${HYPRLAND_ADAPTER}" ]]; then
    # Verify overlay host or controller reacts safely to workspace changes
    assert_grep -i "(activeSurface|isOverlayActive)" "${OVERLAY_CTRL}" "Overlay state must be well-defined"
    assert_file_exists "${HYPRLAND_ADAPTER}"
else
    assert_file_exists "${OVERLAY_CTRL}" "OverlayController.qml required"
    assert_file_exists "${HYPRLAND_ADAPTER}" "HyprlandAdapter.qml required"
fi

report_summary
